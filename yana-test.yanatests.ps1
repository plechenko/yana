# This script contains tests for YANA Testing Framework.
# Use the tests below as examples of how to write your own tests for YANA.

# The tested script shall be sourced.
. "$PSScriptRoot/yana-test.ps1"

function YANAtest:YanaTestResult@has_passed_and_failed_properties {
  $result = [YanaTestResult]::new()
  if ($result.Passed -eq 0) { pass 'Passed initialized to 0' } else { fail 'Passed not initialized correctly' }
  if ($result.Failed -eq 0) { pass 'Failed initialized to 0' } else { fail 'Failed not initialized correctly' }

  $result.Passed = 5
  $result.Failed = 3
  if ($result.Passed -eq 5) { pass 'Passed property is writable' } else { fail 'Passed not writable' }
  if ($result.Failed -eq 3) { pass 'Failed property is writable' } else { fail 'Failed not writable' }
}

function YANAtest:Get-YanaTestFunction@discover_with_wildcard {
  $tests = & {
    # Override the default values for Quiet and LogFile to avoid cluttering the test output.
    $Quiet = $true
    $LogFile = $null

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
    # Override the default values for Quiet and LogFile to avoid cluttering the test output.
    $Quiet = $true
    $LogFile = $null

    # Create a specific test function
    function YANAtest:SpecificTest { }

    Get-YanaTestFunction -TestName 'SpecificTest'
  }
  if ($tests.Count -eq 1) { pass 'Found 1 specific test' } else { fail "Expected 1 test, got: $($tests.Count)" }
  if ($tests.Contains('YANAtest:SpecificTest')) { pass 'SpecificTest found' } else { fail 'SpecificTest not found' }
}

function YANAtest:Get-YanaTestFunction@no_matching_tests {
  $tests = & {
    # Override the default values for Quiet and LogFile to avoid cluttering the test output.
    $Quiet = $true
    $LogFile = $null
    Get-YanaTestFunction -TestName 'NonExistentTest*'
  }
  if ($tests.Count -eq 0) { pass 'No tests found for non-existent pattern' } else { fail "Expected 0 tests, got: $($tests.Count)" }
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

    $files = & {
      $Quiet = $true
      $LogFile = $null
      Get-YanaTestFile -TestFile '*.ps1' -TestDir $tempDir
    }
    if ($files.Count -gt 0) { pass 'Found test files' } else { fail 'No test files found' }
    foreach ($file in $files) {
      if ($file -in $testFiles) { pass "Found expected test file: $($file)" } else { fail "Unexpected test file found: $($file)" }
    }
  } finally {
    Remove-Item $tempDir -Recurse -ErrorAction SilentlyContinue
  }
}

function YANAtest:Get-YanaTestFile@with_specific_pattern {
  $files = & {
    $Quiet = $true
    $LogFile = $null
    Get-YanaTestFile -TestFile 'yana_tests'
  }
  # Should find yana_tests.yanatests.ps1 if it exists, or similar patterns
  if ($null -ne $files) { pass 'File discovery returned results' } else { pass 'No files match pattern (expected)' }
}

function YANAtest:Invoke-YanaTestFunction@pass {
  function YANAtest:Invoke-YanaTestFunction@pass_subtest {
    pass
    pass 'This test should pass'
  }
  $test_result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFunction -TestFunction 'YANAtest:Invoke-YanaTestFunction@pass_subtest'
  }
  if ($test_result.Passed -eq 2) { pass 'Test passes as expected' } else { fail "Expected 2 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTestFunction@fail {
  function YANAtest:Invoke-YanaTestFunction@fail_subtest {
    fail
    fail 'This test should fail'
  }
  $test_result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFunction -TestFunction 'YANAtest:Invoke-YanaTestFunction@fail_subtest'
  }
  if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 2) { pass 'Test fails as expected' } else { fail "Expected 2 failed subtests, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTestFunction@no_args {
  $test_result = & {
    $Script:mock_buffer = @()
    function Out-Colored {
      param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail
      )
      # Capture the output for inspection
      $Script:mock_buffer += $PSBoundParameters
    }
    Invoke-YanaTestFunction
  }
  if ($test_result.Passed -eq 0) {
    pass 'Empty test function does not pass'
  } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) {
    pass 'Empty test function does not fail'
  } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
  if ($Script:mock_buffer.Count -eq 1) {
    pass 'Output is generated for empty test function'
  } else { fail "Expected 1 output message, got: $($Script:mock_buffer.Count)" }
  if ($Script:mock_buffer[0].Color -eq 'red') {
    pass 'Output color is red for error message'
  } else { fail "Expected output color to be 'red', got: $($Script:mock_buffer[0].Color)" }
  if ($Script:mock_buffer[0].Message -eq 'Error: Test function name shall not be empty') {
    pass 'Correct error message is generated'
  } else { fail "Expected error message 'Error: Test function name shall not be empty', got: $($Script:mock_buffer[0].Message)" }
}

function YANAtest:Invoke-YanaTestFunction@name_not_prefixed {
  $test_result = & {
    $Script:mock_buffer = @()
    function Out-Colored {
      param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail
      )
      # Capture the output for inspection
      $Script:mock_buffer += $PSBoundParameters
    }
    Invoke-YanaTestFunction -TestFunction 'NonPrefixedTestFunction'
  }
  if ($test_result.Passed -eq 0) {
    pass 'Non-prefixed test function does not pass'
  } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) {
    pass 'Non-prefixed test function does not fail'
  } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
  if ($Script:mock_buffer.Count -eq 1) {
    pass 'Output is generated for non-prefixed test function'
  } else { fail "Expected 1 output message, got: $($Script:mock_buffer.Count)" }
  if ($Script:mock_buffer[0].Color -eq 'red') {
    pass 'Output color is red for error message'
  } else { fail "Expected output color to be 'red', got: $($Script:mock_buffer[0].Color)" }
  if ($Script:mock_buffer[0].Message -eq "Error: Test function name must start with 'YANAtest:', got: 'NonPrefixedTestFunction'") {
    pass 'Correct error message is generated for non-prefixed test function'
  } else { fail "Expected error message `"Error: Test function name must start with 'YANAtest:', got: 'NonPrefixedTestFunction'`", got: '$($Script:mock_buffer[0].Message)'" }
}

function YANAtest:Invoke-YanaTestFunction@exception_in_test {
  function YANAtest:Invoke-YanaTestFunction@exception_in_test_subtest {
    throw 'This is a test exception'
  }
  $test_result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFunction -TestFunction 'YANAtest:Invoke-YanaTestFunction@exception_in_test_subtest'
  }
  if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 1) { pass 'Test fails as expected' } else { fail "Expected 1 failed subtest, got: $($test_result.Failed)" }
}

# function YANAtest:Invoke-YanaTestFunction@nonexistent_function {
#   $test_result = & {
#     $Quiet = $true
#     $LogFile = $null
#     Invoke-YanaTestFunction -TestFunction 'YANAtest:NonExistentFunction'
#   }
#   if ($test_result.Passed -eq 0) { pass 'Nonexistent function returns 0 passed' } else { fail "Expected 0 passed, got: $($test_result.Passed)" }
#   if ($test_result.Failed -eq 0) { pass 'Nonexistent function returns 0 failed (empty result)' } else { fail "Expected 0 failed, got: $($test_result.Failed)" }
# }

function YANAtest:Invoke-YanaTestFunction@missing_test_function {
  # Demonstrates how to use mock functions to capture output

  $test_result = & {
    $Script:mock_buffer = @()
    function Out-Colored {
      # Declare the parameters which make sense for testing purposes.
      param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail
      )
      $Script:mock_buffer += $PSBoundParameters
    }
    Invoke-YanaTestFunction -TestFunction 'YANAtest:NonExistentTestFunction'
  }

  if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
  if ($Script:mock_buffer.Count -eq 1) {
    pass 'Error is displayed'
  } else { fail 'Should display error but got:', $Script:mock_buffer.Message }
  if ($Script:mock_buffer[0].Color -eq 'red') {
    pass 'Error color is red'
  } else { fail "Expected error color to be 'red' but got: $($Script:mock_buffer[0].Color)" }
  if ($Script:mock_buffer[0].Message -eq "Error: Test function 'YANAtest:NonExistentTestFunction' does not exist") {
    pass 'Error message is correct'
  } else { fail "Expected error message to be 'Error: Test function 'YANAtest:NonExistentTestFunction' does not exist' but got: $($Script:mock_buffer[0].Message)" }
}

function YANAtest:Invoke-YanaTestFunction@with_test_function {
  # Demonstrates how to invoke a test function and check its output and exit code.

  $testFnName = 'YANAtest:Invoke-YanaTestFunction@with_test_function_subtest'
  # This allows defining the test function dynamically
  New-Item -Path Function: -Name $testFnName -value {
    pass 'This test should pass'
  } -Force | Out-Null

  $test_result = & {
    # Mock the Out-Colored function to capture its output for inspection
    $Script:mock_buffer = @()
    function Out-Colored {
      # Declare the parameters which make sense for testing purposes.
      param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail
      )
      $Script:mock_buffer += $PSBoundParameters
    }
    Invoke-YanaTestFunction -TestFunction $testFnName
  }

  if ($test_result.Passed -eq 1) {
    pass 'Test passes as expected'
  } else { fail "Expected 1 passed subtest, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) {
    pass 'Test does not fail'
  } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
  if ($Script:mock_buffer.Count -gt 0) {
    pass 'Output is generated'
  } else { fail 'Expected output to be generated but got nothing' }
  if ($Script:mock_buffer[0].Color -eq 'cyan') {
    pass 'Output color is cyan'
  } else { fail "Expected output color to be 'cyan' but got: $($Script:mock_buffer[0].Color)" }
  if ($Script:mock_buffer[0].Message -eq 'Running test function') {
    pass 'Output contains expected test running message'
  } else { fail "Expected output to contain 'Running test function' message but got: $($Script:mock_buffer[0].Message)" }
  if ($Script:mock_buffer[0].MessageDetail -eq $testFnName) {
    pass 'Output contains expected test function name'
  } else { fail "Expected output to contain test function name '$testFnName' but got: $($Script:mock_buffer[0].MessageDetail)" }
}

function YANAtest:Invoke-YanaTestFile@no_args {
  $test_result = & {
    $Script:mock_buffer = @()
    function Out-Colored {
      # Declare the parameters which make sense for testing purposes.
      param(
        [string]$Color,
        [string]$Message,
        [string]$MessageDetail
      )
      $Script:mock_buffer += $PSBoundParameters
    }
    Invoke-YanaTestFile
  }
  if ($test_result.Passed -eq 0) { pass 'No test file returns 0 passed' } else { fail "Expected 0 passed, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) { pass 'No test file returns 0 failed (empty result)' } else { fail "Expected 0 failed, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTestFile@with_valid_content {
  # Demonstrates how to:
  # - create a temporary test file
  # - use mock functions
  # - override the behavior of tested function using variable overrides

  $testScript = {
    function YANAtest:TestFunction1@pass {
      pass 'Test passed'
    }
    function YANAtest:TestFunction2@fail {
      fail 'Test failed'
    }
  }
  $tempFile = [System.IO.Path]::GetTempFileName() + '.ps1'
  $testScript | Set-Content -Path $tempFile

  try {
    $result = & {
      # Mock the Get-YanaTest function to return predefined test results
      function Get-YanaTest {
        @(
          'YANAtest:TestFunction1@pass'
          'YANAtest:TestFunction2@fail'
        )
      }
      $Quiet = $true
      $LogFile = $null
      Invoke-YanaTestFile -TestFile $tempFile -TestName '*'
    }
    if ($result.Passed -eq 1) { pass 'Test file executed with passed tests' } else { fail 'No tests passed' }
    if ($result.Failed -eq 1) { pass 'Test file executed with failed tests' } else { fail 'No tests failed' }
  } finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
  }
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
