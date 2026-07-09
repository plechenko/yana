# source "${BASH_SOURCE%/*}/yana_tests.sh"

YANAtest:YANA_testing___run_test@without_test_function() {
  local -i exit_code=0
  test_res=$(NO_COLOR=1 YANA_testing___run_test 2>&1) || exit_code=$?
  expect='Error: No test function provided'
  ([[ "$test_res" == *"$expect"* ]] && pass "Returns '$expect'" ) || fail "Expected: '$expect', got: '$test_res'"
  expect_code=1
  ([ "$exit_code" -eq "$expect_code" ] && pass "Exit code is $expect_code" ) || fail "Expected exit code: $expect_code, got: $exit_code"
  test_res=$(NO_COLOR=1 YANA_testing___run_test 2>/dev/null)
  ([ -z "$test_res" ] && pass "No output when stderr redirected" ) || fail "Expected no output, got: '$test_res'"

}

YANAtest:YANA_testing___run_test@with_test_function() {
  expect='Running test function'
  test_func() {
    #shellcheck disable=SC2317
    echo "$expect"
  }
  test_res=$(NO_COLOR=1 YANA_testing___run_test test_func 2>&1 1>/dev/null )
  ([[ "$test_res" == "Running test: test_func"* ]] && pass 'Test function triggered successfully' ) || fail "Expected 'Running test: test_func', got: '$test_res'"
  test_res=$(NO_COLOR=1 YANA_testing___run_test test_func 2>/dev/null)
  ([[ "$test_res" == "$expect" ]] && pass "Test function outputs expected string '$expect'" ) || fail "Expected '$expect', got: '$test_res'"
}
