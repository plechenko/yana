# Getting Started

> Note: YANA is under active development. This document reflects the current state of the project.

## Prerequisites

YANA has minimal dependencies by design.

=== "PowerShell (Windows)"

    - Windows PowerShell 5.1
    - Windows 10 or later / Windows Server 2016 or later

=== "Bash (Linux/macOS)"

    - `bash` version 4.0 or later
    - `curl`
    - `tar`
    - `gunzip`
    - `base64`
    - `openssl`
    - `jq`

## Installation

YANA does not include installer. There are just two scripts for YANA Engine and YANA Toolkit*, which you can download and run directly.

> * YANA Toolkit is intended for future use and may not be available in the current release.

=== "PowerShell (Windows)"

    YANA Engine:
    ```powershell
    Invoke-WebRequest -Uri 'https://github.com/oops-42/yana/releases/latest/download/yana.ps1' -OutFile yana.ps1
    ```
    YANA Testing Framework:
    ```powershell
    Invoke-WebRequest -Uri 'https://github.com/oops-42/yana/releases/latest/download/yana-test.ps1' -OutFile yana-test.ps1
    ```
    YANA Toolkit:
    ```powershell
    Invoke-WebRequest -Uri 'https://github.com/oops-42/yana/releases/latest/download/yana-tool.ps1' -OutFile yana-tool.ps1
    ```

=== "Bash (Linux/macOS)"

    YANA Engine:
    ```bash
    curl -L -o yana.sh 'https://github.com/oops-42/yana/releases/latest/download/yana.sh'
    chmod +x yana.sh
    ```
    YANA Testing Framework:
    ```bash
    curl -L -o yana-test.sh 'https://github.com/oops-42/yana/releases/latest/download/yana-test.sh'
    chmod +x yana-test.sh
    ```
    YANA Toolkit (In Future):
    ```bash
    curl -L -o yana-tool.sh 'https://github.com/oops-42/yana/releases/latest/download/yana-tool.sh'
    chmod +x yana-tool.sh
    ```

## Running YANA

### Usage instructions for YANA Engine

=== "PowerShell (Windows)"

    ```powershell
    ./yana.ps1 -help
    ```

=== "Bash (Linux/macOS)"

    ```bash
    ./yana.sh -help
    ```

### Check the version of YANA Engine

=== "PowerShell (Windows)"

    ```powershell
    ./yana.ps1 version
    ```
=== "Bash (Linux/macOS)"

    ```bash
    ./yana.sh version
    ```

### Apply a blueprint to the node

=== "PowerShell (Windows)"

    ```powershell
    ./yana.ps1 apply -source <path/to/.yana.json>
    ```

=== "Bash (Linux/macOS)"

    ```bash
    ./yana.sh apply -source <path/to/.yana.json>
    ```

### Verify the node against a blueprint

=== "PowerShell (Windows)"

    ```powershell
    ./yana.ps1 verify -source <path/to/.yana.json>
    ```
=== "Bash (Linux/macOS)"

    ```bash
    ./yana.sh verify -source <path/to/.yana.json>
    ```

### Override the default parameter values

You can override the default parameter values by setting the corresponding environment variables prefixed with `YANA_PARAM_` before running the `apply` or `verify` commands:

=== "PowerShell (Windows)"

    ```powershell
    $Env:YANA_PARAM_param1 = 'new_value' # set parameter value for 'param1' using environment variable
    ./yana.ps1 apply -source <path/to/.yana.json> # apply blueprint with overridden parameter values. Will use the value 'new_value' for 'param1'.

    # OR

    $Env:YANA_PARAM_param1 = 'new_value'; ./yana.ps1 apply -source <path/to/.yana.json> # apply blueprint with overridden parameter values. Will use the value 'new_value' for 'param1'.
    ```

=== "Bash (Linux/macOS)"


    ```bash
    export YANA_PARAM_param1='new_value' # set parameter value for 'param1' using environment variable
    ./yana.sh apply -source <path/to/.yana.json> # apply blueprint with overridden parameter values. Will use the value 'new_value' for 'param1'.

    # OR

    YANA_PARAM_param1='new_value' ./yana.sh apply -source <path/to/.yana.json> # apply blueprint with overridden parameter values. Will use the value 'new_value' for 'param1'.
    ```

## Running the Testing Framework

YANA includes a testing framework for unit-testing your actions, verifiers, helpers and other functions. It is part of the YANA Toolkit.

### Run all tests in current directory

=== "PowerShell (Windows)"

    ```powershell
    ./yana-test.ps1
    ```

=== "Bash (Linux/macOS)"

    ```bash
    ./yana-test.sh
    ```

### Run all tests in specified directory

=== "PowerShell (Windows)"

    ```powershell
    ./yana-test.ps1 -testdir <path/to/test/directory> # supports wildcards
    ```

=== "Bash (Linux/macOS)"

    ```bash
    ./yana-test.sh -testdir <path/to/test/directory> # supports wildcards
    ```

### Run specified test file

=== "PowerShell (Windows)"

    ```powershell
    ./yana-test.ps1 -testfile <path/to/test/file.yanatests.ps1> # supports wildcards
    ```

=== "Bash (Linux/macOS)"

    ```bash
    ./yana-test.sh -testfile <path/to/test/file.yanatests.sh> # supports wildcards
    ```

### Run specified tests

=== "PowerShell (Windows)"

    ```powershell
    ./yana-test.ps1 -testname <test_name> # supports wildcards
    ```

=== "Bash (Linux/macOS)"

    ```bash
    ./yana-test.sh -testname <test_name> # supports wildcards
    ```

Read the [Testing Framework](testing.md) documentation for full usage.
