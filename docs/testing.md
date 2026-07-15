---
title: Testing Framework
nav_order: 7
---

# YANA Testing Framework

YANA includes a lightweight built-in testing framework for PowerShell and Bash.
Tests live in `.ps1` or `.sh` files. They can be defined in the same script file with tested code (prefer this way) or in separate `yanatests` files.

## Overview

YANA Testing Framework is assertion-based. Each test function calls `pass` or `fail` to record results.
The runner sources script files and discovers all test functions using the naming convention described below, executes them and outputs a summary.
Tests are standard PowerShell/Bash functions which safely call the tested functions and inspect their results and outputs.

You fully control what and how to test - no magic, no complex testing frameworks, no DSLs.

## Test File Conventions

- Prefer to co-locate tests with the code they test in the same script file.
- If you prefer or need to separate tests from code, put them into files named as `<script>.yanatests.ps1` or `<script>.yanatests.sh`.
- Dot-source the script under test at the top of the file: `. "$PSScriptRoot/myscript.ps1"` (PowerShell) or `. "${BASH_SOURCE[0]%/*}/myscript.sh"` (Bash).

## Test Function Naming

Test functions follow a strict naming convention `YANAtest:<function>[@<scenario>]`, where:

- `<function>` - the name of the function or feature being tested.
- `@<scenario>` - (optional) a short description of the specific case being tested.

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
Prefer to provide a descriptive explanation of why the test failed, including expected and actual values.

Each call to `fail` increments the sub-test failed count. Execution of the test function continues after `fail` - it does not throw.

A test function is considered failed overall if it has at least one `fail` call. It is considered passed if it has zero `fail` calls (even if it has zero `pass` calls).

## Exceptions in Tests

If a test function throws an unhandled exception, it is caught by the runner and recorded as a failure. You can also test that exceptions are thrown by wrapping code in `try/catch`.

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

Execute the `yana-test.ps1` or `yana-test.sh` script (referenced below as `yana-test`).

PowerShell and Bash versions support the same command-line arguments.

Every command-line argument has a corresponding environment variable. If both are specified, the command-line argument takes precedence.

The process exits with code `1` if any tests fail, or `0` if all tests pass.

### Run all tests in the current directory tree

```bash
yana-test
```

### Run all tests in a specific directory

Use `-testdir` or `YANA_TESTDIR`:

```bash
yana-test -testdir './tests'
```

### Run a specific test file

Use `-testfile` or `YANA_TESTFILE`. Wildcards are supported.

```bash
yana-test -testfile './mymodule.yanatests.ps1'
yana-test -testfile './mymodule*'
```

### Run a specific test by name

Use `-testname` or `YANA_TESTNAME`. Wildcards are supported.

```bash
yana-test -testname 'MyCommand'
yana-test -testname 'MyCommand@*'
```

### Output test results to a log file

Use `-logfile` or `YANA_LOGFILE`. If the file already exists, output is appended.

```bash
yana-test -logfile './test_results.log'
```

### Suppress console output

Use `-quiet` or `YANA_QUIET`. Only the final summary is printed. If `-logfile` is also specified, full output is written to the log file.

```bash
yana-test -quiet
```

### Suppress ANSI color codes

Use `-nocolor` or `YANA_NOCOLOR`:

```bash
yana-test -nocolor
```
