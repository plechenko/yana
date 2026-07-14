# YANA Testing Framework

YANA includes a lightweight built-in testing framework for PowerShell and Bash.
Tests live in `.ps1` or `.sh` files. They can be defined in the same script file with tested code (prefer this way) or in separate `yanatests` files.

## Overview

YANA Testing Framework is assertion-based. Each test function calls `pass` or `fail` to record results.
The runner sources script files and discovers all test functions using the naming convention described below, executes them and outputs a summary.
Tests are standard PowerShell/Bash functions which safely call the tested functions and inspect their results and outputs.

You fully control what and how to test - no magic and complex testing frameworks or DSLs.

## Test File Conventions

- Prefer to co-locate tests with the code they test in the same script file.
- If you prefer or need to separate tests from code, put them into files named as `<script>.yanatests.ps1` or `<script>.yanatests.sh`.
- Dot-source the script under test at the top of the file: `. "$PSScriptRoot/myscript.ps1"` (PowerShell) or `. "${BASH_SOURCE[0]%/*}/myscript.sh"` (Bash).

## Test Function Naming

Test functions follow a strict naming convention `YANAtest:<function>[@<scenario>]`, where:

- `<function>` - the name of the function or feature being tested.
- `@<scenario>` - (optional)a short description of the specific case being tested.

PowerShell example:

```powershell
function YANAtest:MyCommand { ... }
function YANAtest:MyCommand@handles_empty_input { ... }
```

Bash example:

```bash
YANAtest:my_command() { ... }
YANAtest:my_command@handles_empty_input() { ... }
```

## Writing Tests

Inside a test function, use `pass` and `fail` to record assertions.

PowerShell example:

```powershell
function YANAtest:MyCommand@returns_expected_value {
    $result = MyCommand -Arg 'hello'
    if ($result -eq 'expected') {
        pass 'Returns expected value'
    } else {
        fail "Got unexpected value: $result"
    }
}
```

Bash example:

```bash
YANAtest:my_command@returns_expected_value() {
    result=$(my_command hello)
    if [[ "$result" == "expected" ]]; then
        pass 'Returns expected value'
    else
        fail "Got unexpected value: $result"
    fi
}
```

### `pass`

```powershell
pass [<message>]
```

Records a successful assertion. If no message is provided, a default message is generated from the calling function name.
Prefer to provide a descriptive explanation of what is expected to have passed.

Each call to `pass` increments the sub-test passed count.

### `fail`

```powershell
fail [<message>]
```

Records a failed assertion. If no message is provided, a default message is generated from the calling function name.
Prefer to provide a descriptive explanation of why the test failed, expected and actual values.

Each call to `fail` increments the sub-test failed count. Execution of the test function continues after `fail` - it does not throw.

A test function is considered failed overall if it has at least one `fail` call. It is considered passed if it has zero `fail` calls (even if it has zero `pass` calls).

## Exceptions in Tests

If a test function throws an unhandled exception, it is caught by the runner and recorded as a failure. The test is marked as failed and the exception message is reported. You can also test that exceptions are thrown by wrapping code in `try/catch`.

PowerShell example:

```powershell
function YANAtest:MyCommand@throws_on_bad_input {
    try {
        MyCommand -Arg $null
        fail 'Expected exception but none was thrown'
    }
    catch {
        pass "Caught expected exception: $($_.Exception.Message)"
    }
}
```

Bash example:

```bash
YANAtest:my_command@throws_on_bad_input() {
    if my_command "" 2>/dev/null; then
        fail 'Expected exception but none was thrown'
    else
        pass 'Caught expected exception'
    fi
}
```

## Running Tests

To run tests, execute the `yana-test.ps1` or `yana-test.sh` script. In the following examples it will be referenced as `yana-test`.

> PowerShell and Bash versions support the same command-line arguments.

Every command line argument has a corresponding environment variable. If both are specified, the command-line argument takes precedence.

The process will exit with code `1` if any of the tests fail, or `0` if all tests pass.

### Run all tests in the current directory tree

```bash
yana-test
```

### Run all tests in a specific directory

Use `-testdir` argument or `YANA_TESTDIR` environment variable to specify a directory to search for test files.

```bash
yana-test -testdir './tests'
```

### Run a specific test file

Use the `-testfile` argument or `YANA_TESTFILE` environment variable to specify a test file(s) to run.
You can use wildcards to match multiple files.

```bash
yana-test -testfile './mymodule.yanatests.ps1'
yana-test -testfile './mymodule*'
```

### Run a specific test by name

By using the `-testname` argument or `YANA_TESTNAME` environment variable, you can run specific test(s) by name.
You can use wildcards to match multiple tests.

```bash
yana-test -testname 'MyCommand'
yana-test -testname 'MyCommand@*'
```

### Output test results to a log file

Use the `-logfile` argument or `YANA_LOGFILE` environment variable to specify a log file to which all output messages will be written.
If the file already exists, it will be appended.

```bash
yana-test -logfile './test_results.log'
```

### Suppress output

Use the `-quiet` argument or `YANA_QUIET` environment variable to suppress output messages.
If `-quiet` is specified, only the summary of test results will be printed.
If `-logfile` is also specified, all output messages will be written to the log file.

```bash
yana-test -quiet
```

### Suppress ANSI color codes

Use the `-nocolor` argument or `YANA_NOCOLOR` environment variable to suppress ANSI color codes.

```bash
yana-test -nocolor
```
