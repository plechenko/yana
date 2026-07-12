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
([ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]:-1}" -lt 4 ]) && {
	echo 'Error: Bash 4.0 or higher is required.' >&2
	exit 1
}

[[ -z ${YANATEST_PREFIX:-} ]] && builtin readonly YANATEST_PREFIX='YANAtest:'

out_colored() {
	local Color="${1:-${Color:-}}"
	local Message="${2:-${Message:-}}"
	local MessageDetail="${3:-${MessageDetail:-}}"

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

	[[ $_YANA_QUIET == true ]] && return
	if [[ $_YANA_NOCOLOR == true ]]; then
		Message="${Message}${MessageDetail}"
	else
		local ColorCode
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
	echo "$Message"
}

out_colored_stdout() {
	output="$(out_colored "$@")"
	[[ -n $output ]] && echo -e "$output" >&1
}
out_colored_stderr() {
	output="$(out_colored "$@")"
	[[ -n $output ]] && echo -e "$output" >&2
}

get_yana_test_files() {
	builtin local test_dir="${1:-$_YANA_TESTDIR}"
	[[ -z $test_dir ]] && test_dir="$PWD"
	builtin local test_file_pattern="${2:-$_YANA_TESTFILE}"
	[[ -z $test_file_pattern ]] && test_file_pattern='*'
	[[ $test_file_pattern != *'.sh' ]] && test_file_pattern="$test_file_pattern.sh"
	out_colored_stderr cyan "Discovering test files in directory: $test_dir with pattern: $test_file_pattern"
	find "$test_dir" -type f -name "$test_file_pattern" # 2>/dev/null
}

get_yana_test_function() {
	builtin local test_name_pattern="${1:-$_YANA_TESTNAME}"
	[[ $test_name_pattern != "$YANATEST_PREFIX"* ]] && test_name_pattern="${YANATEST_PREFIX}$test_name_pattern"

	builtin declare -F |
		awk '{print $3}' |
		grep "^$YANATEST_PREFIX" |
		while IFS= builtin read -r test_fn; do
			#shellcheck disable=SC2053
			[[ $test_fn == $test_name_pattern ]] && echo "$test_fn"
		done
}

# Invokes a specific test function and captures results.
# Params:
#  $1 <test_function> - A test function name to invoke.
# Outputs: [YanaTestResult] with Passed and Failed tests.
invoke_yana_test_function() {
	builtin local test_function="${1:-$test_function}"
	[[ -z $test_function ]] && {
		out_colored_stderr red 'Error: Missing test function argument'
		return 1
	}
	[[ $test_function != $YANATEST_PREFIX* ]] && {
		out_colored_stderr red "Error: Invalid test function name: $test_function"
		return 1
	}
	declare -F "$test_function" >/dev/null 2>&1 || {
		out_colored_stderr red "Error: Test function not found: $test_function"
		return 1
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
		out_colored_stderr green "\t[√] ${Message}" "$(_caller_info)"
		((YANA_test_result_passed += 1))
	}

	# Marks the current test as failed.
	# Prints a message indicating that the current test has failed.
	# Increments the failed test count.
	#shellcheck disable=SC2317
	fail() {
		builtin local Message="${1:-"$test_function failed"}"
		out_colored_stderr red "\t[x] ${Message}" "$(_caller_info)"
		((YANA_test_result_failed += 1))
	}

	builtin local -i YANA_test_result_passed=0
	builtin local -i YANA_test_result_failed=0
	out_colored_stderr cyan "Running test function: $test_function"
	"$test_function" || {
		fail "Error: Test function execution failed: $test_function"
		return 1
	}
	out_colored_stderr yellow "\t\tSub-tests: Passed: $YANA_test_result_passed\tFailed: $YANA_test_result_failed" "$test_function"
	if [[ $YANA_test_result_failed -gt 0 ]]; then return 1; else return 0; fi
}

YANAtest:invoke_yana_test_function@pass() {

	pass "Test function invoked successfully"
	pass
	# fail
}

# invoke_yana_test_function 'YANAtest:invoke_yana_test_function@pass'

# Invokes tests from a specified test file.
# Sources the specified test file and invokes the tests defined in it.
# Params:
#   $1 <test_file>  Path to the test file to invoke.
# Outputs: counters of Passed and Failed tests
invoke_yana_test_file() {
	builtin local test_file="${1:-$test_file}"
	[[ -z $test_file ]] && {
		out_colored_stderr red 'Error: Test file argument is required'
		return 1
	}
	[[ ! -f $test_file ]] && {
		out_colored_stderr red "Error: Test file not found: $test_file"
		return 1
	}

	for fn in $(get_yana_test_function '*'); do
		builtin unset -f "$fn" 2>/dev/null
	done
	out_colored_stderr magenta 'Importing tests from file' "$test_file"
	builtin source "$test_file" || {
		out_colored_stderr red "Error: Failed to source test file: $test_file"
		return 1
	}
	builtin local YANA_test_results
	YANA_test_results=$(
		get_yana_test_function "$_YANA_TESTNAME" |
			while IFS= builtin read -r test_fn; do
				invoke_yana_test_function "$test_fn"
				builtin echo $?
			done
	)
	builtin local -i YANA_test_result_passed=0
	builtin local -i YANA_test_result_failed=0
	for r in $YANA_test_results; do
		if [[ $r == 0 ]]; then
			((YANA_test_result_passed += 1))
		else
			((YANA_test_result_failed += 1))
		fi
	done

	out_colored_stderr yellow "\tTests: Passed: $YANA_test_result_passed\tFailed: $YANA_test_result_failed" "$test_file"

	builtin echo "${YANA_test_result_passed}_${YANA_test_result_failed}"
	[[ $YANA_test_result_failed -gt 0 ]] && return 1
}

# Main entry point. Discovers and invokes test file(s), collects results,
# and exits with code 1 if any tests failed.
#
# Params:
#   _YANA_TESTDIR  <dir>            Base directory. Defaults to $_YANA_TESTDIR.
#   _YANA_TESTFILE <pattern>        File name pattern. Defaults to '*'.
#   _YANA_TESTNAME <pattern>        Test function pattern. Defaults to '*'.
invoke_yana_testing() {
	parse_args "$@"
	[[ -z $_YANA_TESTDIR ]] && _YANA_TESTDIR="$PWD"
	[[ -z $_YANA_TESTFILE ]] && _YANA_TESTFILE='*'
	[[ -z $_YANA_TESTNAME ]] && _YANA_TESTNAME='*'

	builtin local YANA_total_tests
	YANA_total_tests=$(get_yana_test_files "$_YANA_TESTDIR" "$_YANA_TESTFILE" |
		while IFS= builtin read -r test_file; do
			invoke_yana_test_file "$test_file"
		done
	)
	builtin local -i YANA_total_passed=0
	builtin local -i YANA_total_failed=0
	for r in $YANA_total_tests; do
		builtin local -i passed=${r%_*}
		builtin local -i failed=${r#*_}
		((YANA_total_passed += passed))
		((YANA_total_failed += failed))
	done
	builtin echo >&2
	builtin echo -e "PASSED: $YANA_total_passed\tFAILED: $YANA_total_failed"
	[[ $YANA_total_failed -gt 0 ]]
}

# Parse command-line arguments and set global variables accordingly.
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-testdir)
			[[ -z $2 ]] && {
				out_colored_stderr red 'Error: Missing value for -testdir'
				exit 1
			}
			_YANA_TESTDIR="$2"
			builtin shift 2
			;;
		-testfile)
			[[ -z $2 ]] && {
				out_colored_stderr red 'Error: Missing value for -testfile'
				exit 1
			}
			_YANA_TESTFILE="$2"
			builtin shift 2
			;;
		-testname)
			[[ -z $2 ]] && {
				out_colored_stderr red 'Error: Missing value for -testname'
				exit 1
			}
			_YANA_TESTNAME="$2"
			builtin shift 2
			;;
		-logfile)
			[[ -z $2 ]] && {
				out_colored_stderr red 'Error: Missing value for -logfile'
				exit 1
			}
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
		*)
			out_colored_stderr red "Error: Unknown argument: $1"
			exit 1
			;;
		esac
	done
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
	# If the script is executed directly, run the tests
	# ---------------------------------------------------------------------------
	# Default parameters (overridden by argument parsing at the bottom)
	# ---------------------------------------------------------------------------
	_YANA_TESTDIR="${YANA_TESTDIR:-$PWD}"
	_YANA_TESTFILE="${YANA_TESTFILE:-*}"
	_YANA_TESTNAME="${YANA_TESTNAME:-*}"
	_YANA_LOGFILE="${YANA_LOGFILE:-}"
	_YANA_QUIET="${YANA_QUIET:-false}"
	_YANA_NOCOLOR="${YANA_NOCOLOR:-false}"
	invoke_yana_testing "$@"
fi
