#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# YANA Simple Testing Framework
# ---------------------------------------------------------------------------
# It contains functions and variables that can be used in other scripts to facilitate testing of YANA code and modules.
# This framework supports running YANA tests.
# ---------------------------------------------------------------------------
# USAGE:
# 1. Create a new test script suffixing it with ".tests.sh" and source the tested script.
# 2. Define your test functions named as "YANAtest:<function>@<scenario>".
# 3. Use the `pass` and `fail` functions to indicate test results.
# 4. Execute this script directly to run all tests.
#   - You can also specify a specific test file and/or test function to run.
# ---------------------------------------------------------------------------

# Double-check that we are running in bash
([ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]:-1}" -lt 4 ]) && {
  echo "Error: This script must be run in bash 4 or higher." >&2
  return 1
}

print_color() {
  builtin local color_code="${1:-}"
  builtin local message_bold="${2:-}"
  builtin local message_normal="${3:-}"
  case "$color_code" in
  "red") color_code=31 ;;
  "green") color_code=32 ;;
  "yellow") color_code=33 ;;
  "blue") color_code=34 ;;
  "magenta") color_code=35 ;;
  "cyan") color_code=36 ;;
  *) color_code=0 ;; # Default to no color
  esac
  if [ -n "${NO_COLOR:-}" ]; then
    builtin echo -e "${message_bold}${message_normal}" >&2
  else
    builtin echo -e "\033[1;${color_code}m${message_bold}\033[0;${color_code}m${message_normal}\033[0m" >&2
  fi
}

YANA_testing___run_test() {
  builtin local test_func="${1:-}"
  if [[ -z $test_func ]]; then
    print_color red "Error: No test function provided"
    builtin return 1
  fi
  if ! declare -F "$test_func" >/dev/null; then
    print_color red "Error: Test function '$test_func' does not exist"
    builtin return 1
  fi
  print_color cyan "Running test: " "$test_func"
  #shellcheck disable=SC2317
  (
    builtin local -i _YANA_subtests_passed=0
    builtin local -i _YANA_subtests_failed=0

    pass() {
      builtin local message="${1:-"${FUNCNAME[1]} passed"}"
      print_color green "\t[✓] $message: " "$(builtin caller 0 | awk '{print $3":"$1}')"
      ((_YANA_subtests_passed += 1))
    }

    fail() {
      builtin local message="${1:-"${FUNCNAME[1]} failed"}"
      print_color red "\t[✗] $message: " "$(builtin caller 0 | awk '{print $3":"$1}')"
      ((_YANA_subtests_failed += 1))
      builtin return 1
    }

    builtin set -Eeuo pipefail
    "$test_func"
    print_color yellow "\t\tSub-tests: [✓]Passed: $_YANA_subtests_passed\t[✗]Failed: $_YANA_subtests_failed"
  ) || builtin return $?
}

YANA_testing___run_tests() {
  builtin local test_name="${1:-}"
  builtin readonly _YANA_test_prefix='YANAtest:'
  builtin local -i _YANA_tests_passed=0 _YANA_tests_failed=0
  builtin local test_functions
  test_functions=$(builtin declare -F | awk '{print $3}' | grep "^$_YANA_test_prefix" || builtin true)

  for test_func in $test_functions; do
    #shellcheck disable=SC2053
    if [[ -n $test_name && $test_func != $test_name && $test_func != ${_YANA_test_prefix}$test_name ]]; then
      continue
    fi
    if YANA_testing___run_test "$test_func"; then ((_YANA_tests_passed += 1)); else ((_YANA_tests_failed += 1)); fi
  done
  builtin echo >&2
  builtin echo -e "YANA TESTS PASSED: $_YANA_tests_passed\tFAILED: $_YANA_tests_failed"
  if [[ $_YANA_tests_failed -gt 0 ]]; then builtin return 1; fi
}

YANA_testing___load_test_file() {
  builtin local test_file="${1:-}"
  if [[ -n $test_file && -f $test_file ]]; then
    print_color magenta "Sourcing test file: " "$test_file"
    #shellcheck disable=SC1090
    builtin source "$test_file"
  else
    print_color red "Error: Test file '$test_file' does not exist"
    builtin return 1
  fi
}

YANA_testing___run_test_file() {
  builtin local test_file="${1:-}"
  if [[ -n $test_file && -f $test_file ]]; then
    print_color magenta "Running tests in file: " "$test_file"
    YANA_testing___load_test_file "$test_file"
    YANA_testing___run_all_tests
  else
    print_color red "Error: Test file '$test_file' does not exist"
    builtin return 1
  fi
}

YANA_testing___main() {
  [[ ${BASH_SOURCE[0]} == "${0}" ]] || return 0 # Prevent running when sourced
  set -eEuo pipefail

  trace_failure() {
    builtin local -i exit_code="${?:=0}"
    builtin echo "Exit Code: $exit_code" >&2
    builtin local frame=0
    while :; do
      trace=$(builtin caller $frame | awk '{print $3 ":" $1 " (" $2 ") "}') || break
      builtin echo "$trace" >&2
      ((frame += 1))
    done
    #shellcheck disable=SC2086
    builtin exit $exit_code
  }

  [[ -z ${_Dbg_running:-} ]] && builtin trap 'trace_failure' ERR

  builtin local test_file="${1:-}"
  builtin local test_name="${2:-}"

  if [[ -n $test_file ]]; then
    YANA_testing___load_test_file "$test_file"
  else
    for test_file in $(
      builtin shopt -s globstar
      ls -1 "$PWD"/**/*.tests.sh 2>/dev/null || builtin true
    ); do
      YANA_testing___load_test_file "$test_file"
    done
  fi
  YANA_testing___run_tests "$test_name"
}

YANA_testing___main "$@"
