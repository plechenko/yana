# This script contains tests for YANA Testing Framework itself.
# Many tests are included into the YANA Testing Framework.
# Below are some additional tests as a demonstration of how to write tests.

# Example of how to write mock functions for testing purposes.
# Store the output of Out-Colored in a variable so that we can inspect it later.
$Script:YANA_Mock_outBuffer = @()
# Mock function to replace Out-Colored during tests.
# It captures the parameters passed to it and stores them in the previously defined variable $script:YANA_Mock_outBuffer for later inspection.
function Out-Colored_Mock {
  # Capture the parameters passed to the function which make sense for testing purposes.
  param(
    [string]$Color,
    [string]$Message,
    [string]$MessageDetail
  )
  $Script:YANA_Mock_outBuffer += $PSBoundParameters
}


function YANAtest:Invoke-YanaTestFunction@exception {
  try {
    throw 'This is a test exception'
    fail 'This should not be reached'
  } catch {
    pass "Caught exception: $($_.Exception.Message)"
  }
}

function YANAtest:Invoke-YanaTestFunction@missing_test_function {
  # $Script:YANA_Mock_outBuffer.Clear()
  $test_result = & {
    # Mock the Out-Colored function to capture its output for inspection
    $Script:YANA_Mock_outBuffer = @()
    Set-Alias -Name Out-Colored -Value Out-Colored_Mock -Scope Local
    Invoke-YanaTestFunction -TestFunctionName 'NonExistentTestFunction'
  }

  if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
  if ($Script:YANA_Mock_outBuffer.Count -eq 1) {
    pass 'Error is displayed'
  } else { fail 'Should display error but got:', $Script:YANA_Mock_outBuffer.Message }
  if ($Script:YANA_Mock_outBuffer[0].Color -eq 'red') {
    pass 'Error color is red'
  } else { fail "Expected error color to be 'red' but got: $($YANA_Mock_outBuffer[0].Color)" }
  if ($Script:YANA_Mock_outBuffer[0].Message -eq "Error: Test function 'NonExistentTestFunction' does not exist") {
    pass 'Error message is correct'
  } else { fail "Expected error message to be 'Error: Test function 'NonExistentTestFunction' does not exist' but got: $($YANA_Mock_outBuffer[0].Message)" }
}

function YANAtest:Invoke-YanaTestFunction@with_test_function {
  $testFnName = 'YANAtest:Invoke-YanaTestFunction@with_test_function_subtest'
  New-Item -Path Function: -Name $testFnName -value {
    pass 'This test should pass'
  } -Force | Out-Null

  # $Script:YANA_Mock_outBuffer.Clear()
  $test_result = & {
    $Script:YANA_Mock_outBuffer = @()
    # Mock the Out-Colored function to capture its output for inspection
    Set-Alias -Name Out-Colored -Value Out-Colored_Mock -Scope Local
    Invoke-YanaTestFunction -TestFunctionName $testFnName
  }

  if ($test_result.Passed -eq 1) {
    pass 'Test passes as expected'
  } else { fail "Expected 1 passed subtest, got: $($test_result.Passed)" }
  if ($test_result.Failed -eq 0) {
    pass 'Test does not fail'
  } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
  if ($Script:YANA_Mock_outBuffer.Count -gt 0) {
    pass 'Output is generated'
  } else { fail 'Expected output to be generated but got nothing' }
  if ($Script:YANA_Mock_outBuffer[0].Color -eq 'cyan') {
    pass 'Output color is cyan'
  } else { fail "Expected output color to be 'cyan' but got: $($Script:YANA_Mock_outBuffer[0].Color)" }
  if ($Script:YANA_Mock_outBuffer[0].Message -eq 'Running test function') {
    pass 'Output contains expected test running message'
  } else { fail "Expected output to contain 'Running test function' message but got: $($Script:YANA_Mock_outBuffer[0].Message)" }
  if ($Script:YANA_Mock_outBuffer[0].MessageDetail -eq $testFnName) {
    pass 'Output contains expected test function name'
  } else { fail "Expected output to contain test function name '$testFnName' but got: $($Script:YANA_Mock_outBuffer[0].MessageDetail)" }
}

function YANAtest:Invoke-YanaTestFile@with_valid_content {
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

function YANAtest:Invoke-YanaTestFile@nonexistent_file {
  $result = & {
    $Quiet = $true
    $LogFile = $null
    Invoke-YanaTestFile -TestFile '/nonexistent/path/test.ps1'
  }
  if ($result.Passed -eq 0 -and $result.Failed -eq 0) { pass 'Returns empty result for nonexistent file' } else { fail 'Expected zero results for missing file' }
}
