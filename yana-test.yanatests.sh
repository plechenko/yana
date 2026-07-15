# This script contains tests for YANA Testing Framework.
# Use the tests below as examples of how to write your own tests for YANA.

# The tested script shall be sourced.
. "${BASH_SOURCE[0]%/*}/yana-test.sh"

function YANAtest:get_yana_test_function@discover_specific_test {
	function YANAtest:SpecificTestOnly { :; }
	test_result=$(get_yana_test_function 'SpecificTestOnly')
	grep -q 'YANAtest:SpecificTestOnly' <<<"$test_result" && pass 'SpecificTestOnly discovered' || fail 'SpecificTestOnly not discovered'
}

function YANAtest:get_yana_test_function@no_matching_tests {
	test_result=$(get_yana_test_function 'NonExistentFunction*')
	[[ -z $test_result ]] && pass 'No functions returned for non-existent pattern' || fail "Expected empty result, got: $test_result"
}

function YANAtest:get_yana_test_function@discover_with_wildcard {
	local test_name_pattern="${1:-YANAtest:*}"
	function YANAtest:Sample1 { :; }
	function YANAtest:Sample2@ { :; }
	function YANAtest:Sample3@test { :; }
	function YANAtest:Other@Test { :; }

	test_result=$(get_yana_test_function 'Sample*')
	[[ -n $test_result ]] && pass "Test functions discovered successfully" || fail "No test functions discovered"
	grep -q 'YANAtest:Sample1' <<<"$test_result" && pass "Sample1 discovered" || fail "Sample1 not discovered"
	grep -q 'YANAtest:Sample2@' <<<"$test_result" && pass "Sample2@ discovered" || fail "Sample2@ not discovered"
	grep -q 'YANAtest:Sample3@test' <<<"$test_result" && pass "Sample3@test discovered" || fail "Sample3@test not discovered"
	grep -q 'YANAtest:Other@Test' <<<"$test_result" && fail "Other@Test incorrectly discovered" || pass "Other@Test correctly not discovered"
}

function YANAtest:get_yana_test_file@discover_test_files {
	tempDir=$(mktemp -d)
	touch "$tempDir/test1.sh" "$tempDir/test2.sh"
	mkdir -p "$tempDir/sub"
	touch "$tempDir/sub/test3.sh"
	files=$(get_yana_test_file "$tempDir" '*.sh' 2>/dev/null)
	[[ -n $files ]] && pass 'Found test files' || fail 'No test files found'
	grep -q "$tempDir/test1.sh" <<<"$files" && pass 'test1.sh found' || fail 'test1.sh not found'
	grep -q "$tempDir/test2.sh" <<<"$files" && pass 'test2.sh found' || fail 'test2.sh not found'
	grep -q "$tempDir/sub/test3.sh" <<<"$files" && pass 'sub/test3.sh found recursively' || fail 'sub/test3.sh not found'
	rm -rf "$tempDir"
}

function YANAtest:get_yana_test_file@no_matching_files {
	tempDir=$(mktemp -d)
	files=$(get_yana_test_file "$tempDir" 'nonexistent_pattern*.sh' 2>/dev/null)
	[[ -z $files ]] && pass 'No files returned for non-matching pattern' || fail "Expected empty result, got: $files"
	rm -rf "$tempDir"
}

function YANAtest:invoke_yana_test_function@no_args {
	local -a mock_buffer=()
	local _orig_out_colored_stderr
	_orig_out_colored_stderr=$(declare -f out_colored_stderr)
	function out_colored_stderr {
		mock_buffer+=("$*")
	}
	local _rc=0
	invoke_yana_test_function >/dev/null || _rc=$?
	test_result=$(invoke_yana_test_function)

	eval "$_orig_out_colored_stderr"

	if [[ $_rc -eq 1 ]]; then pass 'Returns 1 as expected'; else fail "Expected exit code 1 for passing test, got: $_rc"; fi

	parsed_result=$(parse_YanaTestResult "$test_result") || {
		fail "Failed to parse YanaTestResult"
		return
	}
	read -r passed failed <<<"$parsed_result"
	if [[ $passed -eq 0 ]]; then pass "Parsed passed count: $passed"; else fail "Expected passed count = 0, got: $passed"; fi
	if [[ $failed -eq 0 ]]; then pass "Parsed failed count: $failed"; else fail "Expected failed count = 0, got: $failed"; fi
	if [[ ${#mock_buffer[@]} -gt 0 ]]; then pass 'Output is generated'; else fail 'Expected output to be generated'; fi
	if [[ ${mock_buffer[0]} == 'red Error: Test function name shall not be empty' ]]; then
		pass 'Error message for empty test function name is correct'
	else
		fail "Expected error message for empty test function name, got: ${mock_buffer[0]}"
	fi
}

function YANAtest:invoke_yana_test_function@missing_test_function {
	# Demonstrates how to use mock functions to capture output

	# Mock buffer to capture output from out_colored_stderr
	local -a mock_buffer=()
	# Save the original out_colored_stderr function so we can restore it later
	local _orig_out_colored_stderr
	_orig_out_colored_stderr=$(declare -f out_colored_stderr)
	# Override out_colored_stderr to capture its output into mock_buffer
	function out_colored_stderr {
		mock_buffer+=("$*")
	}
	# Call the test function and capture its exit code
	local _rc=0
	invoke_yana_test_function 'YANAtest:NonExistentTestFunction' >/dev/null || _rc=$?
	result=$(invoke_yana_test_function 'YANAtest:NonExistentTestFunction')

	# Restore the original out_colored_stderr function
	eval "$_orig_out_colored_stderr"

	# Perform assertions on the captured output and exit code
	if [[ $_rc -ne 0 ]]; then pass 'Test fails as expected'; else fail "Expected non-zero exit for missing test function, got: $_rc"; fi
	if [[ ${#mock_buffer[@]} -eq 1 ]]; then pass 'Error is displayed'; else fail "Expected 1 error output, got: ${#mock_buffer[@]}"; fi
	if [[ ${mock_buffer[0]} == "red "* ]]; then pass 'Error color is red'; else fail "Expected red color, got: ${mock_buffer[0]}"; fi
	if grep -q 'NonExistentTestFunction' <<<"${mock_buffer[0]}"; then pass 'Error message contains function name'; else fail "Error message missing function name: ${mock_buffer[0]}"; fi
}

function YANAtest:invoke_yana_test_function@with_test_function {
	# Demonstrates how to invoke a test function and check its output and exit code.

	local test_fn='YANAtest:_with_test_function_subtest'
	function YANAtest:_with_test_function_subtest { pass 'This test should pass'; }

	# Mock buffer to capture output from out_colored_stderr
	local -a mock_buffer=()
	# Save the original out_colored_stderr function so we can restore it later
	local _orig_out_colored_stderr
	_orig_out_colored_stderr=$(declare -f out_colored_stderr)
	# Override out_colored_stderr to capture its output into mock_buffer
	function out_colored_stderr {
		mock_buffer+=("$*")
	}
	# Call the test function and capture its exit code
	local _rc=0
	invoke_yana_test_function "$test_fn" || _rc=$?

	# Restore the original out_colored_stderr function
	eval "$_orig_out_colored_stderr"

	# Perform assertions on the captured output and exit code
	if [[ $_rc -eq 0 ]]; then pass 'Test passes as expected'; else fail "Expected zero exit for passing test, got: $_rc"; fi
	if [[ ${#mock_buffer[@]} -gt 0 ]]; then pass 'Output is generated'; else fail 'Expected output to be generated'; fi
	if [[ ${mock_buffer[0]} == "cyan "* ]]; then pass 'Output color is cyan'; else fail "Expected cyan color, got: ${mock_buffer[0]}"; fi
	if grep -q 'Running test function' <<<"${mock_buffer[0]}"; then pass 'Output contains running message'; else fail "Expected 'Running test function' in output, got: ${mock_buffer[0]}"; fi
	if grep -q "$test_fn" <<<"${mock_buffer[0]}"; then pass 'Output contains test function name'; else fail "Expected function name in output: ${mock_buffer[0]}"; fi
}

function YANAtest:invoke_yana_test_function@fail {
	pass "$(_YANA_NOCOLOR=true fail 2>&1)"
	pass "$(_YANA_NOCOLOR=true fail 'Test function failed as expected' 2>&1)"
}

function YANAtest:invoke_yana_test_function@nonexistent_function {
	local _rc=0
	test_result=$(_YANA_NOCOLOR=true _YANA_QUIET=true invoke_yana_test_function 'YANAtest:NonExistentFunction' 2>/dev/null) || _rc=$?
	[[ $_rc -ne 0 ]] && pass 'Nonexistent function returns non-zero exit' || fail 'Expected non-zero exit for nonexistent function'
}

function YANAtest:invoke_yana_test_function@invalid_prefix {
	local _rc=0
	test_result=$(_YANA_NOCOLOR=true _YANA_QUIET=true invoke_yana_test_function 'not_a_test_function' 2>/dev/null) || _rc=$?
	[[ $_rc -ne 0 ]] && pass 'Invalid prefix returns non-zero exit' || fail 'Expected non-zero exit for invalid prefix'
}

function YANAtest:invoke_yana_test_function@exception_in_test {
	function YANAtest:_exception_subtest { return 1; }
	local _rc=0
	test_result=$(_YANA_NOCOLOR=true _YANA_QUIET=true invoke_yana_test_function 'YANAtest:_exception_subtest') || _rc=$?
	[[ $_rc -eq 1 ]] && pass 'Failing test function returns exit code 1' || fail "Expected exit code 1 for failing test, but got: $_rc"
}

function YANAtest:invoke_yana_test_file@no_args {

	local -a mock_buffer=()
	local _orig_out_colored_stderr
	_orig_out_colored_stderr=$(declare -f out_colored_stderr)
	function out_colored_stderr {
		mock_buffer+=("$*")
	}
	local _rc=0
	invoke_yana_test_file >/dev/null || _rc=$?
	test_result=$(invoke_yana_test_file)

	eval "$_orig_out_colored_stderr"

	if [[ $_rc -eq 1 ]]; then pass 'Returns 1 as expected'; else fail "Expected exit code 1 for passing test, got: $_rc"; fi

	parsed_result=$(parse_YanaTestResult "$test_result") || {
		fail "Failed to parse YanaTestResult"
		return
	}
	read -r passed failed <<<"$parsed_result"
	if [[ $passed -eq 0 ]]; then pass "Parsed passed count: $passed"; else fail "Expected passed count = 0, got: $passed"; fi
	if [[ $failed -eq 0 ]]; then pass "Parsed failed count: $failed"; else fail "Expected failed count = 0, got: $failed"; fi
	if [[ ${#mock_buffer[@]} -gt 0 ]]; then pass 'Output is generated'; else fail 'Expected output to be generated'; fi
	if [[ ${mock_buffer[0]} == 'red Error: Test file name shall not be empty' ]]; then
		pass 'Error message for empty test file name is correct'
	else
		fail "Expected error message for empty test file name, got: ${mock_buffer[0]}"
	fi
}

function YANAtest:invoke_yana_test_file@nonexistent_file {
	local -a mock_buffer=()
	local _orig_out_colored_stderr
	_orig_out_colored_stderr=$(declare -f out_colored_stderr)
	function out_colored_stderr {
		mock_buffer+=("$*")
	}
	local _rc=0
	invoke_yana_test_file '/nonexistent/path/test.sh' >/dev/null || _rc=$?
	test_result=$(invoke_yana_test_file '/nonexistent/path/test.sh')

	eval "$_orig_out_colored_stderr"

	if [[ $_rc -eq 1 ]]; then pass 'Returns 1 as expected'; else fail "Expected exit code 1 for passing test, got: $_rc"; fi

	parsed_result=$(parse_YanaTestResult "$test_result") || {
		fail "Failed to parse YanaTestResult"
		return
	}
	read -r passed failed <<<"$parsed_result"
	if [[ $passed -eq 0 ]]; then pass "Parsed passed count: $passed"; else fail "Expected passed count = 0, got: $passed"; fi
	if [[ $failed -eq 0 ]]; then pass "Parsed failed count: $failed"; else fail "Expected failed count = 0, got: $failed"; fi
	if [[ ${#mock_buffer[@]} -gt 0 ]]; then pass 'Output is generated'; else fail 'Expected output to be generated'; fi
	if [[ ${mock_buffer[0]} == 'red Error: Test file not found'* ]]; then
		pass 'Error message for test file not found is correct'
	else
		fail "Expected error message for test file not found, got: ${mock_buffer[0]}"
	fi

}

function YANAtest:invoke_yana_test_file@with_valid_content {
	# Demonstrates how to:
	# - create a temporary test file
	# - use mock functions
	# - override the behavior of tested function using variable overrides

	local tempFile
	tempFile=$(mktemp --suffix='.sh')
	cat >"$tempFile" <<'EOF'
function YANAtest:TestFunction1@pass {
	pass 'Test passed'
}
function YANAtest:TestFunction2@fail {
	fail 'Test failed'
}
EOF

	test_result=$(
		# Mock the get_yana_test_function to return predefined test results
		function get_yana_test_function {
			echo 'YANAtest:TestFunction1@pass'
			echo 'YANAtest:TestFunction2@fail'
		}
		# Override variables to suppress output and logging
		_YANA_QUIET=true _YANA_LOGFILE='' _YANA_TESTNAME='*' invoke_yana_test_file "$tempFile" 2>/dev/null
	)
	rm -f "$tempFile"

	echo "Result: $test_result" >&2

	parsed_result=$(parse_YanaTestResult "$test_result") || {
		fail "Failed to parse YanaTestResult"
		return
	}
	read -r passed failed <<<"$parsed_result"
	if [[ $passed -eq 1 ]]; then pass 'Passing test in file counted correctly'; else fail "Expected 1 passed, got: $passed"; fi
	if [[ $failed -eq 1 ]]; then pass 'Failing test in file counted correctly'; else fail "Expected 1 failed, got: $failed"; fi
}
