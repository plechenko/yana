. "$PSScriptRoot/yana.ps1"

function YANAtest:_yana_@no_arg {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function log {}
    function _yana_usage([string]$Mode) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      _yana_
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -ne 0) {
    pass 'Exit code is correct'
  } else {
    fail "Expected exit code 1 but got: $($result.exit_code)"
  }
  if ($null -ne $result.exception) {
    pass 'Exception is thrown'
    if ($result.exception.Message -eq 'Unknown mode: ''''. Use -help for usage information.') {
      pass 'Error message is correct'
    } else {
      fail "Expected error message to contain 'Unknown mode: ''. Use -help for usage information.' but got: $($result.exception.Message)"
    }
  } else {
    fail 'No exception is thrown'
  }
}

function YANAtest:_yana_@help_no_mode {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function log {}
    function _yana_usage([string]$Mode) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      _yana_ -help
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq '_yana_usage') {
      pass '_yana_usage is called'
    } else {
      fail "Expected _yana_usage to be called but got: $($result.output.Command)"
    }
    if ([string]::IsNullOrEmpty($result.output[0].Args['Mode'])) {
      pass '_yana_usage mode is empty'
    } else {
      fail "Expected _yana_usage mode to be empty but got: $($result.output[0].Args['Mode'])"
    }
  } else {
    fail "Expected _yana_usage to be called once but got: $($result.output.Length) times"
  }
  if ([string]::IsNullOrEmpty($result.output[0].Args['Mode'])) {
    pass '_yana_usage mode is empty'
  } else {
    fail "Expected _yana_usage mode to be empty but got: $($result.output[0].Args['Mode'])"
  }
}

function YANAtest:_yana_@help_with_mode {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function log {}
    function _yana_usage([string]$Mode) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      _yana_ -help -Mode apply
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq '_yana_usage') {
      pass '_yana_usage is called'
    } else {
      fail "Expected _yana_usage to be called but got: $($result.output.Command)"
    }
    if ($result.output[0].Args['Mode'] -eq 'apply') {
      pass '_yana_usage mode is apply'
    } else {
      fail "Expected _yana_usage mode to be apply but got: $($result.output[0].Args['Mode'])"
    }
  } else {
    fail "Expected _yana_usage to be called once but got: $($result.output.Length) times"
  }
}

function YANAtest:_yana_@version {
  function log {}
  $test_result = _yana_ Version
  if ($test_result -eq $Script:YANA_VERSION) {
    pass 'Version output is correct'
  } else {
    fail "Expected version output to be '$Script:YANA_VERSION' but got: $test_result"
  }
}

function YANAtest:_yana_@mode_apply {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function log {}
    function _yana_mode_apply([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    function _yana_mode_verify([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    function _yana_mode_pull([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      _yana_ -Mode 'apply' -Source some_source
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq '_yana_mode_apply') {
      pass '_yana_mode_apply is called'
      if ($result.output[0].Args['Source'] -eq 'some_source') {
        pass '_yana_mode_apply source is correct'
      } else {
        fail "Expected _yana_mode_apply source to be 'some_source' but got: $($result.output[0].Args['Source'])"
      }
    } else {
      fail "Expected _yana_mode_apply to be called but got: $($result.output[0].Command)"
    }
  } else {
    fail "Expected _yana_mode_apply to be called once but got: $($result.output.Length) times"
  }
}

function YANAtest:_yana_@mode_verify {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function log {}
    function _yana_mode_apply([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    function _yana_mode_verify([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    function _yana_mode_pull([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      _yana_ -Mode 'verify' -Source some_source
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq '_yana_mode_verify') {
      pass '_yana_mode_verify is called'
      if ($result.output[0].Args['Source'] -eq 'some_source') {
        pass '_yana_mode_verify source is correct'
      } else {
        fail "Expected _yana_mode_verify source to be 'some_source' but got: $($result.output[0].Args['Source'])"
      }
    } else {
      fail "Expected _yana_mode_verify to be called but got: $($result.output[0].Command)"
    }
  } else {
    fail "Expected _yana_mode_verify to be called once but got: $($result.output.Length) times"
  }
}

function YANAtest:_yana_@mode_pull {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function log {}
    function _yana_mode_apply([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    function _yana_mode_verify([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    function _yana_mode_pull([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      _yana_ -Mode 'pull' -Source some_source
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -eq 0) {
    pass 'Exit code is 0'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 1) {
    if ($result.output[0].Command -eq '_yana_mode_pull') {
      pass '_yana_mode_pull is called'
      if ($result.output[0].Args['Source'] -eq 'some_source') {
        pass '_yana_mode_pull source is correct'
      } else {
        fail "Expected _yana_mode_pull source to be 'some_source' but got: $($result.output[0].Args['Source'])"
      }
    } else {
      fail "Expected _yana_mode_pull to be called but got: $($result.output[0].Command)"
    }
  } else {
    fail "Expected _yana_mode_pull to be called once but got: $($result.output.Length) times"
  }
}

function YANAtest:_yana_@invalid_mode {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function log {}
    function _yana_mode_apply([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    function _yana_mode_verify([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    function _yana_mode_pull([string]$Source) { @{ Command = $MyInvocation.MyCommand.Name; Args = $PSBoundParameters } }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = $null, $null
    try {
      _yana_ -Mode 'unknown' -Source some_source
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array

  if ($result.exit_code -ne 0) {
    pass 'Exit code is non-zero'
  } else {
    fail "Expected exit code non-zero but got: $($result.exit_code)"
  }
  if ($result.output.Length -eq 0) {
    pass 'No mode functions are called'
  } else {
    fail "Expected no mode functions to be called but got: $($result.output.Command)"
  }
  if ($null -ne $result.exception) {
    pass 'Exception is thrown'
    if ($result.exception -is [System.Management.Automation.ParameterBindingException]) {
      pass 'Error message is correct'
    } else {
      fail "Expected error message to be of type 'System.Management.Automation.ParameterBindingException' but got: $($result.exception.GetType().FullName)"
    }
  } else {
    fail 'Expected exception to be thrown but got none'
  }
}

function YANAtest:_yana_@env_vars {
  $result = @{exit_code = 0; exception = $null; output = $null }
  $result.output = & {
    function log {}
    function _yana_mode_apply([string]$Source) { "apply: '$Source'" }
    function _yana_mode_verify([string]$Source) { "verify: '$Source'" }
    function _yana_mode_pull([string]$Source) { "pull: '$Source'" }
    $local:_YANA_MODE, $local:_YANA_SOURCE = $env:YANA_MODE, $env:YANA_SOURCE
    $env:YANA_MODE, $env:YANA_SOURCE = 'apply', 'some_source'
    try {
      _yana_
    } catch {
      $result.exception, $result.exit_code = $_.Exception, $_.Exception.HResult
    } finally {
      $env:YANA_MODE, $env:YANA_SOURCE = $local:_YANA_MODE, $local:_YANA_SOURCE
    }
  }
  if ($null -ne $result.output -and $result.output -isnot [array]) { $result.output = @($result.output) } # Ensure output is an array


  if ($result.exit_code -eq 0) {
    pass 'Exit code is correct'
  } else {
    fail "Expected exit code 0 but got: $($result.exit_code)"
  }
  if ($null -eq $result.exception) {
    pass 'No exception is thrown'
  } else {
    fail "Expected no exception to be thrown but got: $($result.exception.Message)"
  }
  if ($result.output.Length -eq 1) {
    $expect = "apply: 'some_source'"
    if ($result.output[0] -eq $expect) {
      pass 'Output is correct'
    } else {
      fail "Expected output to be '$expect' but got: $($result.output)"
    }
  } else {
    fail "Expected output length to be 1 but got: $($result.output.Length)"
  }
}
