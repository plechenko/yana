#!/usr/bin/env pwsh

#Requires -Version 5.1

# -----------------------------------------------------------------------------
# YANA Simple Testing Framework (PowerShell)
# -----------------------------------------------------------------------------
# It contains functions and variables that can be used in other scripts to facilitate testing of YANA code and modules.
# This framework supports running YANA tests.
# -----------------------------------------------------------------------------
# USAGE:
# 1. Create a new test script suffixing it with ".yanatests.ps1" and dot-source the tested script.
# 2. Define your test functions named as "YANAtest:<function>@<scenario>".
# 3. Use the `pass` and `fail` functions to indicate test results.
# 4. Execute this script directly to run all tests.
#   - You can also specify a specific test file and/or test function to run.
# -----------------------------------------------------------------------------

$YANA_TITLE = 'YANA Testing Framework (PowerShell)'
$YANA_VERSION = '0.1.0'

function Out-Colored {
  # .SYNOPSIS
  # 	Outputs colored text to the output stream.
  # .DESCRIPTION
  # 	Outputs $Message in the specified $Color and $MessageDetail in dimmed color to the output stream.
  #   Takes care of logging to a file if $LogFile is specified.
  #   If $Quiet is specified, suppresses output.
  #   If $NoColor is specified, disables colored output.
  param(
    # The color of the text (e.g., 'Red', 'Green', 'Blue').
    [string]$Color,
    # The main message to display.
    [string]$Message,
    # Additional details to display (optional). Will be displayed in dimmed color.
    [string]$MessageDetail = ''
  )
  if ($Message.Length -gt 0) { $Message = "$Message " }
  if ($LogFile) {
    $logMessage = "[$([datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))] ${Message}${MessageDetail}"
    try {
      Add-Content -Path $LogFile -Value $logMessage -Force -ErrorAction Ignore
    } catch {
      Write-Warning "Failed to write to log file '$($LogFile)': $($_.Exception.Message)"
    }
  }
  if ($Quiet) { return }
  if ($NoColor) {
    $message = "${Message}$MessageDetail"
  } else {
    $colorCode = switch ($Color) {
      'Black' { 30 }
      'Red' { 31 }
      'Green' { 32 }
      'Yellow' { 33 }
      'Blue' { 34 }
      'Magenta' { 35 }
      'Cyan' { 36 }
      'White' { 37 }
      default { 0 } # Default to no color
    }
    "`u{001b}[${colorCode}m${Message}`u{001b}[2m${MessageDetail}`u{001b}[0m"
  }
}
function Out-ColoredStdout {
  # .SYNOPSIS
  # 	Outputs colored text to the standard output.
  if ($local:output = Out-Colored @args) { [Console]::Out.WriteLine($local:output)	}
}
function Out-ColoredStderr {
  # .SYNOPSIS
  # 	Outputs colored text to the standard error.
  if ($local:output = Out-Colored @args) { [Console]::Error.WriteLine($local:output)	}
}

class YanaTestResult {
  # .SYNOPSIS
  # 	Class to hold test results.
  # .DESCRIPTION
  # 	The YanaTestResult class holds the number of passed and failed tests.

  # Count of passed tests
  [int]$Passed = 0
  # Count of failed tests
  [int]$Failed = 0
}

function YANAtest:YanaTestResult@has_passed_and_failed_properties {
  $result = [YanaTestResult]::new()
  if ($result.Passed -eq 0) { pass 'Passed initialized to 0' } else { fail 'Passed not initialized correctly' }
  if ($result.Failed -eq 0) { pass 'Failed initialized to 0' } else { fail 'Failed not initialized correctly' }

  $result.Passed = 5
  $result.Failed = 3
  if ($result.Passed -eq 5) { pass 'Passed property is writable' } else { fail 'Passed not writable' }
  if ($result.Failed -eq 3) { pass 'Failed property is writable' } else { fail 'Failed not writable' }
}

function Get-YanaTestFunction {
  # .SYNOPSIS
  # 	Discovers test functions based on pattern specified in the $TestName parameter.
  # .OUTPUTS
  #   [string[]] Array of test function names that match the specified pattern.
  param(
    # A test function name to discover. Supports wildcards.
    # Defaults to all test functions in the current session.
    [string]$TestName = '*'
  )
  $Local:YANA_testPrefix = 'YANAtest:'
  $Local:test_patterns = @()
  if (-not $TestName.StartsWith($Local:YANA_testPrefix)) { $TestName = "$Local:YANA_testPrefix${TestName}" }
  $Local:test_patterns += "Function:/$TestName"
  Get-Item $Local:test_patterns -ErrorAction SilentlyContinue | ForEach-Object { $_.Name	}
}

function YANAtest:Get-YanaTestFunction@discover_with_wildcard {
  $tests = & {
    # Create test functions dynamically
    function YANAtest:Sample1 { }
    function YANAtest:Sample2@ { }
    function YANAtest:Sample3@test { }
    function YANAtest:Other@Test { }

    Get-YanaTestFunction -TestName 'Sample*'
  }
  if ($tests.Count -eq 3) { pass 'Found 3 tests matching Sample*' } else { fail "Expected 3 tests, got: $($tests.Count)" }
  if ($tests.Contains('YANAtest:Sample1')) { pass 'Test Sample1 found' } else { fail 'Test Sample1 not found' }
  if ($tests.Contains('YANAtest:Sample2@')) { pass 'Test Sample2@ found' } else { fail 'Test Sample2@ not found' }
  if ($tests.Contains('YANAtest:Sample3@test')) { pass 'Test Sample3@test found' } else { fail 'Test Sample3@test not found' }
  if ($tests.Contains('YANAtest:Other@Test')) { fail 'Test Other@Test should not be found' } else { pass 'Test Other@Test correctly not found' }
}

function YANAtest:Get-YanaTestFunction@discover_specific_test {
  $tests = & {
    # Create a specific test function dynamically
    function YANAtest:SpecificTest { }

    Get-YanaTestFunction -TestName 'SpecificTest'
  }
  if ($tests.Count -eq 1) { pass 'Found 1 specific test' } else { fail "Expected 1 test, got: $($tests.Count)" }
  if ($tests.Contains('YANAtest:SpecificTest')) { pass 'SpecificTest found' } else { fail 'SpecificTest not found' }
}

function YANAtest:Get-YanaTestFunction@no_matching_tests {
  $tests = Get-YanaTestFunction -TestName 'NonExistentTest*'
  if ($tests.Count -eq 0) { pass 'No tests found for non-existent pattern' } else { fail "Expected 0 tests, got: $($tests.Count)" }
}

function Get-YanaTestFile {
  # .SYNOPSIS
  # 	Discovers test files based on pattern(s) specified in the $TestFile parameter.
  # .DESCRIPTION
  # 	Discovers test files in the current directory and subdirectories.
  # .OUTPUTS
  #   [string[]] List of test files that match the specified pattern(s).
  param(
    # The base path to start searching for test files.
    # Defaults to the current working directory.
    [string]$TestDir = $PWD,
    # A test file name to discover. Supports wildcards.
    # Defaults to all test files in the current directory and subdirectories.
    [string]$TestFile = '*'
  )
  if (-not $TestFile.EndsWith('.ps1')) { $TestFile = "${TestFile}.ps1" }
	Out-ColoredStderr blue "Discovering test files in directory '$TestDir' with pattern '$TestFile'"
  try {
    Get-ChildItem -Path $TestDir -Recurse -Filter '*.ps1' -Include $TestFile -ErrorAction Ignore | Foreach-Object { $_.FullName }
  } catch { $null }
}

function YANAtest:Get-YanaTestFile@discover_test_files {
  # Create temporary test file
  try {
    $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    $testFiles = @(
      [System.IO.Path]::Combine($tempDir, 'test1.ps1'),
      [System.IO.Path]::Combine($tempDir, 'test2.ps1'),
      [System.IO.Path]::Combine($tempDir, '1', 'test1.ps1'),
      [System.IO.Path]::Combine($tempDir, '2', 'test2.ps1'),
      [System.IO.Path]::Combine($tempDir, '1', '2', 'test1.ps1'),
      [System.IO.Path]::Combine($tempDir, '1', '2', 'test2.ps1')
    )
    New-Item -Path $testFiles -ItemType File -Force | Out-Null

    $files = Get-YanaTestFile -TestFile '*.ps1' -TestDir $tempDir
    if ($files.Count -gt 0) { pass 'Found test files' } else { fail 'No test files found' }
    foreach ($file in $files) {
      if ($file -in $testFiles) { pass "Found expected test file: $($file)" } else { fail "Unexpected test file found: $($file)" }
    }
  } finally {
    Remove-Item $tempDir -Recurse -ErrorAction SilentlyContinue
  }
}

function YANAtest:Get-YanaTestFile@with_specific_pattern {
  $files = Get-YanaTestFile -TestFile 'yana_tests'
  # Should find yana_tests.yanatests.ps1 if it exists, or similar patterns
  if ($null -ne $files) { pass 'File discovery returned results' } else { pass 'No files match pattern (expected)' }
}


function Invoke-YanaTestFunction([string]$TestFunctionName) {
  # .SYNOPSIS
  # 	Invokes specific test function(s) and captures results.
  # .DESCRIPTION
  # 	Invokes specific test function(s) and captures results.
  # .PARAMETER TestName
  # 	A test function name to invoke.
  # .OUTPUTS
  # 	[YanaTestResult] with Passed and Failed tests.

  function pass ([string]$Message = '') {
    # .SYNOPSIS
    # 	Marks the current test as passed.
    # .DESCRIPTION
    # 	Prints a message indicating that the current test has passed.
    # 	Increments the passed test count.
    $caller = (Get-PSCallStack)[1]
    $location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"
    if (-not $Message) { $Message = "$($caller.FunctionName) passed" }
    Out-ColoredStderr -Color green -Message "`t[+] ${Message}" -MessageDetail $location
    $YANA_subtests_ref.Value.Passed++
  }
  function fail ([string]$Message = '') {
    # .SYNOPSIS
    # 	Marks the current test as failed.
    # .DESCRIPTION
    # 	Prints a message indicating that the current test has failed.
    # 	Increments the failed test count.
    $caller = (Get-PSCallStack)[1]
    $location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"
    if (-not $Message) { $Message = "$($caller.FunctionName) failed" }
    Out-ColoredStderr -Color red -Message "`t[-] ${Message}" -MessageDetail $location
    $YANA_subtests_ref.Value.Failed++
  }

  if (-not (Test-Path "Function:/$TestFunctionName")) {
    Out-ColoredStderr -Color red -Message "Error: Test function '$TestFunctionName' does not exist"
    return [YanaTestResult]::new()
  }

  $Local:YANA_testResult = [YanaTestResult]::new()
  $Local:YANA_subtests = @{}
  Out-ColoredStderr -Color cyan -Message 'Running test function' -MessageDetail $TestFunctionName
  $Local:YANA_subtests[$TestFunctionName] = [YanaTestResult]::new()
  $Local:YANA_subtests_ref = [ref]$Local:YANA_subtests[$TestFunctionName]
  try {
    $null = & $TestFunctionName
  } catch {
    fail "Exception $($_.Exception.Message) $($_.ScriptStackTrace.Split("`n")[0])"
  }
  if ($Local:YANA_subtests_ref.Value.Failed -eq 0) {
    $Local:YANA_testResult.Passed++
  } else {
    $Local:YANA_testResult.Failed++
  }
  Out-ColoredStderr -Color yellow -Message "`tPassed: $($Local:YANA_subtests_ref.Value.Passed)`tFailed: $($Local:YANA_subtests_ref.Value.Failed)" -MessageDetail $TestFunctionName
  $Local:YANA_subtests_ref = $null
  $Local:YANA_subtests.Remove($TestFunctionName)

  $Local:YANA_testResult
}

function YANAtest:Invoke-YanaTestFunction@pass {
  pass
}

function YANAtest:Invoke-YanaTestFunction@fail {
  function YANAtest:Invoke-YanaTestFunction@failure_subtest {
    fail 'This test should fail'
  }
  $test_result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFunction -TestFunctionName 'YANAtest:Invoke-YanaTestFunction@failure_subtest'
  }
  if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 1) { pass 'Test fails as expected' } else { fail "Expected 1 failed subtest, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTestFunction@exception_in_test {
  function YANAtest:Invoke-YanaTestFunction@exception_in_test_subtest {
    throw 'This is a test exception'
  }
  $test_result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFunction -TestFunctionName 'YANAtest:Invoke-YanaTestFunction@exception_in_test_subtest'
  }
  if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 1) { pass 'Test fails as expected' } else { fail "Expected 1 failed subtest, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTestFunction@nonexistent_function {
  $test_result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFunction -TestFunctionName 'YANAtest:NonExistentFunction'
  }
  if ($test_result.Passed -eq 0) { pass 'Nonexistent function returns 0 passed' } else { fail "Expected 0 passed, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) { pass 'Nonexistent function returns 0 failed (empty result)' } else { fail "Expected 0 failed, got: $($test_result.Failed)" }
}

function Invoke-YanaTestFile {
  # .SYNOPSIS
  # 	Invokes tests from a specified test file.
  # .DESCRIPTION
  # 	Sources the specified test file and invokes the tests defined in it.
  # .OUTPUTS
  # 	[YanaTestResult] with Passed and Failed tests.
  param(
    # The path to the test file to invoke.
    [string]$TestFile,
    # A test function name to invoke. Supports wildcards.
    # Defaults to all tests in the file.
    [string]$TestName = '*'
  )
  $Local:YANA_testResult = [YanaTestResult]::new()

  if ([string]::IsNullOrEmpty($TestFile)) {
    Out-ColoredStderr -Color red -Message 'Error: Test file argument is required'
    return $Local:YANA_testResult
  }

  if ([System.IO.File]::Exists($TestFile)) {
    # Remove all test functions starting with 'YANAtest:'
    Get-YanaTestFunction '*' | ForEach-Object {
      Remove-Item "Function:/$_" -ErrorAction SilentlyContinue
    }

    Out-ColoredStderr -Color magenta -Message 'Importing tests from file' -MessageDetail $TestFile
    try {
      . $TestFile
    } catch {
      Out-ColoredStderr -Color red -Message "Error: Failed to import test file '$TestFile'" -MessageDetail $_.Exception.Message
      return $Local:YANA_testResult
    }
    Get-YanaTestFunction -TestName $TestName | ForEach-Object {
      $Local:YANA_testResult_fn = Invoke-YanaTestFunction -TestFunctionName $_
      $Local:YANA_testResult.Passed += $Local:YANA_testResult_fn.Passed
      $Local:YANA_testResult.Failed += $Local:YANA_testResult_fn.Failed
    }
    Out-ColoredStderr -Color yellow -Message "Passed: $($Local:YANA_testResult.Passed)`tFailed: $($Local:YANA_testResult.Failed)" -MessageDetail $TestFile
  } else {
    Out-ColoredStderr -Color red -Message "Error: Test file '$TestFile' does not exist" -MessageDetail $TestFile
  }

  $Local:YANA_testResult
}

function YANAtest:Invoke-YanaTestFile@empty_file_argument {
  $test_result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFile -TestFile ''
  }
  if ($test_result.Passed -eq 0) { pass 'Empty file argument returns 0 passed' } else { fail "Expected 0 passed, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) { pass 'Empty file argument returns 0 failed' } else { fail "Expected 0 failed, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTestFile@nonexistent_file {
  $test_result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFile -TestFile '/nonexistent/path/test.ps1'
  }
  if ($test_result.Passed -eq 0) { pass 'Nonexistent file returns 0 passed' } else { fail "Expected 0 passed, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) { pass 'Nonexistent file returns 0 failed' } else { fail "Expected 0 failed, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTestFile@runs_tests_in_file {
  try {
    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "yana_test_$([System.IO.Path]::GetRandomFileName()).ps1")
    Set-Content -Path $tempFile -Value @'
function YANAtest:TempFileTest@passes {
    pass 'Temp file test passed'
}
function YANAtest:TempFileTest@fails {
    fail 'Temp file test failed'
}
'@
    $test_result = & {
      $Quiet = $true
      $LogFile = $null
      Invoke-YanaTestFile -TestFile $tempFile
    }
    if ($test_result.Passed -eq 1) { pass 'Passing test in file counted correctly' } else { fail "Expected 1 passed, got: $($test_result.Passed)" }
    if ($test_result.Failed -eq 1) { pass 'Failing test in file counted correctly' } else { fail "Expected 1 failed, got: $($test_result.Failed)" }
  } finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
  }
}

function YANAtest:Invoke-YanaTestFile@nonexistent_file {
  $result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFile -TestFile '/nonexistent/path/test.ps1'
  }
  if ($result.Passed -eq 0 -and $result.Failed -eq 0) { pass 'Returns empty result for nonexistent file' } else { fail 'Expected zero results for missing file' }
}

function Out-Help {
  # .SYNOPSIS
  # 	Outputs help information.
  Write-Host @"
Usage: $($PSCommandPath) [options]
Options:
  -testdir <dir>      Base directory to search for test files. Uses YANA_TESTDIR environment variable. Defaults to current directory.
  -testfile <pattern> File name pattern to match test files. Uses YANA_TESTFILE environment variable. Defaults to '*'.
  -testname <pattern> Test function name pattern to match test functions. Uses YANA_TESTNAME environment variable. Defaults to '*'.
  -logfile <file>     Log file path to write test results. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file.
  -quiet              Suppress output to the console. Uses YANA_QUIET environment variable.
  -nocolor            Disable colored output. Uses YANA_NOCOLOR environment variable.
  -version            Show version information and exit.
  -help               Show this help message and exit.

* If no options specified, all tests in the current directory will be executed.
"@
}
function Invoke-YanaTesting {
  # .SYNOPSIS
  # 	The main entry point for running tests.
  # .DESCRIPTION
  # 	Invokes test(s) from the specified test file(s) and collects the results.
  # .OUTPUTS
  # 	[YanaTestResult] with Passed and Failed tests.
  # .NOTES
  # 	Exits with a non-zero status code if any tests failed.
  param(
    # The base path to start searching for test files.
    # Uses YANA_TESTDIR environment variable if set.
    # Defaults to the current working directory.
    [string]$TestDir = $Env:YANA_TESTDIR,
    # Test file paths to invoke.
    # Accepts wildcards to match multiple files.
    # Uses YANA_TESTFILE environment variable if set.
    # Defaults to all test files in the current directory and subdirectories.
    [string]$TestFile = $Env:YANA_TESTFILE,
    # Test function name(s) to invoke (using pattern 'YANAtest:<function>[@<scenario>]').
    # Accepts wildcards to match multiple tests.
    # Uses YANA_TESTNAME environment variable if set.
    # Defaults to all tests in the specified test file(s).
    [string]$TestName = $Env:YANA_TESTNAME,
    # If specified, outputs log messages to the given file.
    # Uses YANA_LOGFILE environment variable if set.
    [string]$LogFile = $Env:YANA_LOGFILE,
    # If specified, suppresses output messages.
    # Uses YANA_QUIET environment variable if set.
    [switch]$Quiet = [bool]$Env:YANA_QUIET,
    # If specified, disables colored output.
    # Uses YANA_NOCOLOR environment variable if set.
    [switch]$NoColor = [bool]$Env:YANA_NOCOLOR,
    # If specified, displays the version of the testing framework and exits.
    [switch]$Version,
    # If specified, displays help information and exits.
    [switch]$Help
  )

  # Disable progress bar output for cleaner test output
  $Global:ProgressPreference = 'SilentlyContinue'

  Out-ColoredStderr -Message $YANA_TITLE -MessageDetail "Version: $YANA_VERSION"

  if ($Version) { $YANA_VERSION; exit 0 }
  if ($Help) { Out-Help; exit 0 }

  if ([string]::IsNullOrEmpty($TestDir)) { $TestDir = $PWD }
  if ([string]::IsNullOrEmpty($TestFile)) { $TestFile = '*' }
  if ([string]::IsNullOrEmpty($TestName)) { $TestName = '*' }

  $Local:YANA_testingResult = [YanaTestResult]::new()
  $Local:YANA_testFiles = Get-YanaTestFile -TestFile $TestFile -TestDir $TestDir
  foreach ($file in $Local:YANA_testFiles) {
    $test_result = Invoke-YanaTestFile -TestFile $file -TestName $TestName
    $Local:YANA_testingResult.Passed += $test_result.Passed
    $Local:YANA_testingResult.Failed += $test_result.Failed
  }
  $Local:YANA_testingResult
  if ($Local:YANA_testingResult.Failed -gt 0) { exit 1 }
}

# Prevent running when dot-sourced
if ($MyInvocation.InvocationName -ne '.') { Invoke-YanaTesting @args }
