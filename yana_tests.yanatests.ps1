# This script contains tests for YANA Testing Framework itself.
# Many tests are included into the YANA Testing Framework.
# Below are some additional tests as a demonstration of how to write tests.

# Example of how to write mock functions for testing purposes.
# Store the output of Out-Colored in a variable so that we can inspect it later.
$script:YANA_Mock_outBuffer = @()
# Mock function to replace Out-Colored during tests.
# It captures the parameters passed to it and stores them in the previously defined variable $script:YANA_Mock_outBuffer for later inspection.
function Out-Colored_Mock {
	# Capture the parameters passed to the function which make sense for testing purposes.
	param(
		[string]$Color,
		[string]$Message,
		[string]$MessageDetail
	)
	$script:YANA_Mock_outBuffer += $PSBoundParameters
}


function YANAtest:Invoke-YanaTest@exception {
	try {
		throw 'This is a test exception'
		fail 'This should not be reached'
	}
	catch {
		pass "Caught exception: $($_.Exception.Message)"
	}
}

function YANAtest:Invoke-YanaTest@missing_test_function {
	$YANA_Mock_outBuffer.Clear()
	$test_result = & {
		# Mock the Out-Colored function to capture its output for inspection
		Set-Alias -Name Out-Colored -Value Out-Colored_Mock -Scope Local
		Invoke-YanaTest -TestName 'NonExistentTestFunction'
	}

	if ($YANA_Mock_outBuffer.Count -eq 0) { pass 'Nothing is displayed' } else { fail 'Should be nothing displayed but got:', $YANA_Mock_outBuffer }
	if ($test_result.Passed -eq 0) { pass 'Test does not pass' } else { fail "Expected 0 passed subtests, got: $($test_result.Passed)" }
	if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
}

function YANAtest:Invoke-YanaTest@with_test_function {
	$testFnName = 'YANAtest:Invoke-YanaTest@with_test_function_subtest'
	New-Item -Path Function: -Name $testFnName -value {
		pass 'This test should pass'
	} -Force | Out-Null

	$YANA_Mock_outBuffer.Clear()
	$test_result = & {
		# Mock the Out-Colored function to capture its output for inspection
		Set-Alias -Name Out-Colored -Value Out-Colored_Mock -Scope Local
		Invoke-YanaTest -TestName $testFnName
	}

	if ($test_result.Passed -eq 1) { pass 'Test passes as expected' } else { fail "Expected 1 passed subtest, got: $($test_result.Passed)" }
	if ($test_result.Failed -eq 0) { pass 'Test does not fail' } else { fail "Expected 0 failed subtests, got: $($test_result.Failed)" }
	if ($YANA_Mock_outBuffer.Count -gt 0) { pass 'Output is generated' } else { fail 'Expected output to be generated but got nothing' }
	if ($YANA_Mock_outBuffer[0].Color -eq 'cyan') { pass 'Output color is cyan' } else { fail "Expected output color to be 'cyan' but got: $($YANA_Mock_outBuffer[0].Color)" }
	if ($YANA_Mock_outBuffer[0].Message -eq 'Running test') { pass 'Output contains expected test running message' } else { fail "Expected output to contain 'Running test' message but got: $($YANA_Mock_outBuffer[0].Message)" }
	if ($YANA_Mock_outBuffer[0].MessageDetail -eq $testFnName) { pass 'Output contains expected test function name' } else { fail "Expected output to contain test function name '$testFnName' but got: $($YANA_Mock_outBuffer[0].MessageDetail)" }
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
			Invoke-YanaTestFile -TestFile $tempFile -TestName '*'
		}
		if ($result.Passed -eq 1) { pass 'Test file executed with passed tests' } else { fail 'No tests passed' }
		if ($result.Failed -eq 1) { pass 'Test file executed with failed tests' } else { fail 'No tests failed' }
	}
 finally {
		Remove-Item $tempFile -ErrorAction SilentlyContinue
	}
}

function YANAtest:Invoke-YanaTestFile@nonexistent_file {
	$result = & {
		$Quiet = $true
		Invoke-YanaTestFile -TestFile '/nonexistent/path/test.ps1'
	}
	if ($result.Passed -eq 0 -and $result.Failed -eq 0) { pass 'Returns empty result for nonexistent file' } else { fail 'Expected zero results for missing file' }
}
