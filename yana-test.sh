#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# YANA Simple Testing Framework (Bash)
# ---------------------------------------------------------------------------
# It contains functions and variables that can be used in other scripts to
# facilitate testing of YANA code and modules.
# This framework supports running YANA tests.
# ---------------------------------------------------------------------------
# USAGE:
# 1. Create a new test script suffixing it with ".yanatests.sh" and
#    dot-source the tested script.
# 2. Define test functions named as "YANAtest:<function>[@<scenario>]".
# 3. Use the `pass` and `fail` functions to indicate test results.
# 4. Execute this script directly to run all tests.
#    You can also specify a specific test file and/or test function to run.
# ---------------------------------------------------------------------------

# Bash 4+ version check
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]:-1}" -lt 4 ]; then
	echo 'Error: Bash 4.0 or higher is required.' >&2
	exit 1
fi

[[ -z ${YANA_TITLE:-} ]] && builtin readonly YANA_TITLE='YANA Testing Framework (Bash)'
[[ -z ${YANA_VERSION:-} ]] && builtin readonly YANA_VERSION='YANAVERSIONPLACEHOLDER'

YANAtest:example() {
	pass 'Example test passed'
}

# Prepares colored text for output to the console.
# Takes care of logging to a file if $_YANA_LOGFILE is specified.
# If $_YANA_QUIET is specified, suppresses output.
# If $_YANA_NOCOLOR is specified, disables colored output.
out_colored() {
	builtin local Color="${1:-${Color:-}}"
	builtin local Message="${2:-${Message:-}}"
	builtin local MessageDetail="${3:-${MessageDetail:-}}"

	[[ -n $Message ]] && Message="$Message "
	if [[ -n $_YANA_LOGFILE ]]; then
		builtin local logMessage
		logMessage="[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] ${Message}${MessageDetail}"
		echo -e "${logMessage}" >>"$_YANA_LOGFILE" || {
			builtin local _logfile="$_YANA_LOGFILE"
			_YANA_LOGFILE=""
			out_colored red 'Error: Failed to write to log file' "$_logfile" >&2
		}
	fi

	[[ $_YANA_QUIET == true ]] && builtin return
	if [[ $_YANA_NOCOLOR == true ]]; then
		Message="${Message}${MessageDetail}"
	else
		builtin local ColorCode
		case "$Color" in
		black) ColorCode=30 ;;
		red) ColorCode=31 ;;
		green) ColorCode=32 ;;
		yellow) ColorCode=33 ;;
		blue) ColorCode=34 ;;
		magenta) ColorCode=35 ;;
		cyan) ColorCode=36 ;;
		white) ColorCode=37 ;;
		*) ColorCode=0 ;;
		esac
		Message="\e[${ColorCode}m${Message}\e[2m${MessageDetail}\e[0m"
	fi
	builtin echo "$Message"
}
# Outputs colored text to the standard output.
out_colored_stdout() {
	output="$(out_colored "$@")"
	[[ -n $output ]] && builtin echo -e "$output" >&1
}
# Outputs colored text to the standard error.
out_colored_stderr() {
	output="$(out_colored "$@")"
	[[ -n $output ]] && builtin echo -e "$output" >&2
}
throw() {
	builtin local Message="${1:-${Message:-}}"
	builtin local MessageDetail="${2:-${MessageDetail:-}}"
	out_colored_stderr red "Error: $Message" "$MessageDetail"
	builtin exit 1
}
YanaTestResult() {
	builtin local Passed="${1:-${Passed:-0}}"
	builtin local Failed="${2:-${Failed:-0}}"
	builtin echo "YanaTestResult:${Passed}_${Failed}"
}
parse_YanaTestResult() {
	builtin local ResultString="${1:-}"
	[[ $ResultString == 'YanaTestResult:'* ]] || builtin return 1
	builtin local Result="${ResultString#'YanaTestResult:'}"
	builtin local Passed="${Result%_*}"
	builtin local Failed="${Result#*_}"
	builtin echo "$Passed" "$Failed"
}

get_yana_test_file() {
	# builtin local test_dir="${1:-$_YANA_TESTDIR}"
	builtin local test_dir="${1:-}"
	[[ -z $test_dir ]] && test_dir="$PWD"
	builtin local test_file_pattern="${2:-$_YANA_TESTFILE}"
	[[ -z $test_file_pattern ]] && test_file_pattern='*'
	[[ $test_file_pattern != *'.sh' ]] && test_file_pattern="$test_file_pattern.sh"
	out_colored_stderr blue "Discovering test files in directory '$test_dir' with pattern '$test_file_pattern'"
	find "$test_dir" -type f -name "$test_file_pattern" 2>/dev/null
}

# Discovers test functions based on pattern specified in the $_YANA_TESTNAME parameter.
# Outputs: List of test function names that match the specified pattern.
get_yana_test_function() {
	# builtin local test_name_pattern="${1:-$_YANA_TESTNAME}"
	builtin local test_name_pattern="${1:-}"
	[[ $test_name_pattern != YANAtest:* ]] && test_name_pattern="YANAtest:$test_name_pattern"

	builtin declare -F |
		awk '{print $3}' |
		grep "^YANAtest:" |
		while IFS= builtin read -r test_fn; do
			#shellcheck disable=SC2053
			[[ $test_fn == $test_name_pattern ]] && builtin echo "$test_fn"
		done
}

# Invokes a specific test function and captures results.
# Params:
#  $1 <test_function> - A test function name to invoke.
# Outputs: [YanaTestResult] with Passed and Failed tests.
invoke_yana_test_function() {
	builtin local test_function="${1:-}"
	[[ -z $test_function ]] && {
		out_colored_stderr red 'Error: Test function name shall not be empty'
		YanaTestResult
		builtin return 1
	}
	[[ $test_function != YANAtest:* ]] && {
		out_colored_stderr red "Error: Test function name must start with 'YANAtest:', got: '$test_function'"
		YanaTestResult
		builtin return 1
	}
	builtin declare -F "$test_function" >/dev/null 2>&1 || {
		out_colored_stderr red "Error: Test function '$test_function' does not exist"
		YanaTestResult
		builtin return 1
	}

	# Used by pass() and fail() to output the caller function name and line number.
	#shellcheck disable=SC2317
	_caller_info() {
		builtin caller 1 | awk '{print $3 ":" $1}'
	}

	# Marks the current test as passed.
	# Prints a message indicating that the current test has passed.
	# Increments the passed test count.
	#shellcheck disable=SC2317
	pass() {
		builtin local Message="${1:-"$test_function passed"}"
		out_colored_stderr green "\t[+] ${Message}" "$(_caller_info)"
		((YANA_test_result_passed += 1))
	}

	# Marks the current test as failed.
	# Prints a message indicating that the current test has failed.
	# Increments the failed test count.
	#shellcheck disable=SC2317
	fail() {
		builtin local Message="${1:-"$test_function failed"}"
		out_colored_stderr red "\t[-] ${Message}" "$(_caller_info)"
		((YANA_test_result_failed += 1))
	}

	builtin local -i YANA_test_result_passed=0
	builtin local -i YANA_test_result_failed=0
	out_colored_stderr cyan 'Running test function' "$test_function"
	"$test_function" || fail 'Error: Test function execution failed' "$test_function"
	out_colored_stderr yellow "\tPassed: $YANA_test_result_passed\tFailed: $YANA_test_result_failed" "$test_function"
	YanaTestResult "$YANA_test_result_passed" "$YANA_test_result_failed"
	if [[ $YANA_test_result_failed -gt 0 ]]; then builtin return 1; fi
}

# Invokes tests from a specified test file.
# Sources the specified test file and invokes the tests defined in it.
# Params:
#   $1 <test_file>  Path to the test file to invoke.
# Outputs: counters of Passed and Failed tests
invoke_yana_test_file() {
	builtin local test_file="${1:-}"
	if [[ -z $test_file ]]; then
		out_colored_stderr red 'Error: Test file name shall not be empty'
		YanaTestResult
		builtin return 1
	fi
	if [[ ! -f $test_file ]]; then
		out_colored_stderr red 'Error: Test file not found' "$test_file"
		YanaTestResult
		builtin return 1
	fi

	for fn in $(get_yana_test_function '*'); do
		builtin unset -f "$fn" 2>/dev/null
	done
	out_colored_stderr magenta 'Importing tests from file' "$test_file"
	builtin source "$test_file" || {
		out_colored_stderr red 'Error: Failed to import test file' "$test_file"
		YanaTestResult
		builtin return 1
	}
	builtin local YANA_test_results
	YANA_test_results=$(
		get_yana_test_function "$_YANA_TESTNAME" |
			while IFS= builtin read -r test_fn; do
				invoke_yana_test_function "$test_fn"
			done
	)
	builtin local -i YANA_test_result_passed=0
	builtin local -i YANA_test_result_failed=0
	for r in $YANA_test_results; do
		parsed_result=$(parse_YanaTestResult "$r") || builtin continue
		builtin read -r passed failed <<<"$parsed_result"
		if [[ $failed -gt 0 ]]; then
			((YANA_test_result_failed += 1))
		else
			((YANA_test_result_passed += 1))
		fi
	done
	out_colored_stderr yellow "Passed: $YANA_test_result_passed\tFailed: $YANA_test_result_failed" "$test_file"
	YanaTestResult "$YANA_test_result_passed" "$YANA_test_result_failed"
	if [[ $YANA_test_result_failed -gt 0 ]]; then builtin return 1; fi
}

# Main entry point. Discovers and invokes test file(s), collects results,
# and exits with code 1 if any tests failed.
#
# Params:
#   _YANA_TESTDIR  <dir>            Base directory. Defaults to $_YANA_TESTDIR.
#   _YANA_TESTFILE <pattern>        File name pattern. Defaults to '*'.
#   _YANA_TESTNAME <pattern>        Test function pattern. Defaults to '*'.
invoke_yana_testing() {
	out_colored_stderr '' "$YANA_TITLE" "Version: $YANA_VERSION"
	parse_args "$@"
	[[ -z $_YANA_TESTDIR ]] && _YANA_TESTDIR="$PWD"
	[[ -z $_YANA_TESTFILE ]] && _YANA_TESTFILE='*'
	[[ -z $_YANA_TESTNAME ]] && _YANA_TESTNAME='*'

	builtin local YANA_total_tests
	YANA_total_tests=$(
		get_yana_test_file "$_YANA_TESTDIR" "$_YANA_TESTFILE" |
			while IFS= builtin read -r test_file; do
				invoke_yana_test_file "$test_file"
			done
	)
	builtin local -i YANA_total_passed=0
	builtin local -i YANA_total_failed=0
	for r in $YANA_total_tests; do
		parsed_result=$(parse_YanaTestResult "$r") || builtin continue
		builtin read -r passed failed <<<"$parsed_result"
		((YANA_total_passed += passed))
		((YANA_total_failed += failed))
	done
	builtin echo >&2
	builtin echo -e "PASSED: $YANA_total_passed\tFAILED: $YANA_total_failed"
	if [[ $YANA_total_failed -gt 0 ]]; then builtin exit 1; fi
}

out_help() {
	builtin echo "Usage: $0 [options]"
	builtin echo "Options:"
	builtin echo "  -testdir <dir>      Base directory to search for test files. Uses YANA_TESTDIR environment variable. Defaults to current directory."
	builtin echo "  -testfile <pattern> File name pattern to match test files. Uses YANA_TESTFILE environment variable. Defaults to '*'."
	builtin echo "  -testname <pattern> Test function name pattern to match test functions. Uses YANA_TESTNAME environment variable. Defaults to '*'."
	builtin echo "  -logfile <file>     Log file path to write test results. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file."
	builtin echo "  -quiet              Suppress output to the console. Uses YANA_QUIET environment variable."
	builtin echo "  -nocolor            Disable colored output. Uses YANA_NOCOLOR environment variable."
	builtin echo "  -version            Show version information and exit."
	builtin echo "  -help               Show this help message and exit."
	builtin echo
	builtin echo '* If no options specified, all tests in the current directory will be executed.'
}

# Parse command-line arguments and set global variables accordingly.
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-testdir)
			[[ -n $2 ]] || throw 'Missing value for -testdir'
			_YANA_TESTDIR="$2"
			builtin shift 2
			;;
		-testfile)
			[[ -n $2 ]] || throw 'Missing value for -testfile'
			_YANA_TESTFILE="$2"
			builtin shift 2
			;;
		-testname)
			[[ -n $2 ]] || throw 'Missing value for -testname'
			_YANA_TESTNAME="$2"
			builtin shift 2
			;;
		-logfile)
			[[ -n $2 ]] || throw 'Missing value for -logfile'
			_YANA_LOGFILE="$2"
			builtin shift 2
			;;
		-quiet)
			_YANA_QUIET=true
			builtin shift
			;;
		-nocolor)
			_YANA_NOCOLOR=true
			builtin shift
			;;
		-version)
			builtin echo "$YANA_VERSION"
			builtin exit 0
			;;
		-help)
			out_help
			builtin exit 0
			;;
		*)
			out_help
			throw "Unknown argument: $1"
			;;
		esac
	done
}

if [[ -z ${BASH_SOURCE[1]:-} ]] || [[ ${BASH_SOURCE[1]:-bashdb} == *bashdb ]]; then
	# Proceed with the script execution only if it is executed directly or under bashdb.
	_YANA_TESTDIR="${YANA_TESTDIR:-$PWD}"
	_YANA_TESTFILE="${YANA_TESTFILE:-*}"
	_YANA_TESTNAME="${YANA_TESTNAME:-*}"
	_YANA_LOGFILE="${YANA_LOGFILE:-}"
	_YANA_QUIET="${YANA_QUIET:-false}"
	_YANA_NOCOLOR="${YANA_NOCOLOR:-false}"
	invoke_yana_testing "$@"
fi
