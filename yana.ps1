#!/usr/bin/env pwsh
#Requires -Version 5.1
# ---------------------------------------------------------------------------
# YANA - Yet Another Node Automator (PowerShell)
# ---------------------------------------------------------------------------

Set-Variable -Name YANA_TITLE -Value 'YANA - Yet Another Node Automator (PowerShell)' -Option Constant -Scope Script -ErrorAction:Ignore
Set-Variable -Name YANA_VERSION -Value 'YANAVERSIONPLACEHOLDER' -Option Constant -Scope Script -ErrorAction:Ignore

# Outputs help information for the specified mode.
# If mode is not specified, displays general help information.
function _yana_usage([string]$Mode) {
  switch ($Mode) {
    'apply' {
      Write-Host 'Usage: yana.ps1 apply -source <path|url>'
      Write-Host '  Applies the specified YANA Module.'
      Write-Host 'Options:'
      Write-Host '  -source <path|url>         Specifies the source of YANA Module to apply. Can be a local path or a URL. Uses YANA_SOURCE environment variable.'
      break
    }
    'verify' {
      Write-Host 'Usage: yana.ps1 verify -source <path|url>'
      Write-Host '  Compares the state of the system with the state specified by the YANA Module without making any changes.'
      Write-Host 'Options:'
      Write-Host '  -source <path|url>         Specifies the source of YANA Module to verify. Can be a local path or a URL. Uses YANA_SOURCE environment variable.'
      break
    }
    'pull' {
      Write-Host 'Usage: yana.ps1 pull -source <path|url>'
      Write-Host '  Pulls the specified YANA Module from the given source (path or URL).'
      Write-Host 'Options:'
      Write-Host '  -source <path|url>         Specifies the source of YANA Module to pull. Can be path or URL. Uses YANA_SOURCE environment variable.'
    }
    'version' {
      Write-Host 'Usage: yana.ps1 version'
      Write-Host '  Displays the version of YANA.'
    }
    default {
      Write-Host 'Usage: yana.ps1 <general options> [mode] <mode options>'
      Write-Host 'Modes:'
      Write-Host '  version                    Displays the version of YANA.'
      Write-Host '  apply                      Applies the specified YANA Module.'
      Write-Host '  verify                     Compares the state of the system with the state specified by the YANA Module without making any changes.'
      Write-Host '  pull                       Pulls the specified YANA Module.'
    }
  }
  Write-Host 'General Options:'
  Write-Host '  -help                      Displays this help message.'
  Write-Host '  -help <mode>               Displays help for the specified mode.'
  Write-Host '  -logfile <file>            Log file path. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file.'
}
# Logs a message with the specified level and message.
# If the level is 'trace' or 'debug', the message is logged only if the corresponding switch is enabled.
# If a log file is specified, the message is also written to the log file.
function log([string]$Level, [string]$Message) {
  if ($Level -eq 'trace' -and $Script:YANA_TRACE -ne $true) { return }
  if ($Level -eq 'debug' -and $Script:YANA_DEBUG -ne $true) { return }
  $logMessage = "[$([datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))]`t$($Level.ToUpper())`t$Message"
  try {
    if ($level -in @('trace', 'debug')) { [Console]::ForegroundColor = [ConsoleColor]::DarkGray }
    elseif ($level -eq 'info') { [Console]::ForegroundColor = [ConsoleColor]::Cyan }
    elseif ($level -in @('ok', 'success', 'pass')) { [Console]::ForegroundColor = [ConsoleColor]::DarkGreen }
    elseif ($level -in @('skip')) { [Console]::ForegroundColor = [ConsoleColor]::Yellow }
    elseif ($level -in @('warn', 'warning')) { [Console]::ForegroundColor = [ConsoleColor]::DarkYellow }
    elseif ($level -in @('fail', 'failure', 'error')) { [Console]::ForegroundColor = [ConsoleColor]::Red }
    elseif ($level -eq 'fatal') { [Console]::ForegroundColor = [ConsoleColor]:: DarkRed }
    [Console]::Error.WriteLine($logMessage)
  } finally { [Console]::ResetColor() }
  if ($LogFile) {
    try {
      Add-Content -Path $LogFile -Value $logMessage -Force -ErrorAction Stop
    } catch {
      $LogFile = $null
      throw "Failed to write to log file '$LogFile': $($_.Exception.Message)"
    }
  }
}
# Checks for required prerequisites and throws an error if any are missing.
function _yana_check_prerequisites([string[]]$Prerequisites) {
  foreach ($prerequisite in $Prerequisites) {
    if (-not (Get-Command $prerequisite -ErrorAction SilentlyContinue)) {
      throw "Prerequisite '$prerequisite' is not installed or not in the system PATH."
    }
    log debug "Prerequisite '$prerequisite' is installed."
  }
}
# Initializes encryption by generating a random secret key and setting the secret prefix, suffix and algorithm.
function _yana_initialize_encryption() {
  $Script:_YANA_SECRET_PREFIX = '<yanasecret:'
  $Script:_YANA_SECRET_SUFFIX = '>'
  $Script:_YANA_SECRET_PROVIDER = [System.Security.Cryptography.AesCryptoServiceProvider]::new()
  $Script:_YANA_SECRET_PROVIDER.KeySize = 256
  $Script:_YANA_SECRET_PROVIDER.Mode = [System.Security.Cryptography.CipherMode]::CBC
  $Script:_YANA_SECRET_PROVIDER.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
  $Script:_YANA_SECRET_PROVIDER.GenerateKey()
}
# Cleans up encryption by clearing the secret key from memory.
function _yana_cleanup_encryption() {
  if ($null -ne $Script:_YANA_SECRET_PROVIDER) {
    $Script:_YANA_SECRET_PROVIDER.Clear()
    $Script:_YANA_SECRET_PROVIDER.Dispose()
    $Script:_YANA_SECRET_PROVIDER = $null
  }
}
# Encrypts a string using derived key and returns the encrypted string in the format: <yanasecret:{hmac}{iv}{ciphertext}>
function yana_encrypt_string([Parameter(ValueFromPipeline = $true)][string]$InputString) {
  if ($null -eq $Script:_YANA_SECRET_PROVIDER) { throw 'Secret Provider is not initialized. Call _yana_initialize_encryption first.' }
  $Script:_YANA_SECRET_PROVIDER.GenerateIV()
  $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
  $encryptor = $Script:_YANA_SECRET_PROVIDER.CreateEncryptor()
  $cipherBytes = $encryptor.TransformFinalBlock($inputBytes, 0, $inputBytes.Length)
  $hmac = [System.Security.Cryptography.HMACSHA256]::new($Script:_YANA_SECRET_PROVIDER.Key)
  try { $hmacBytes = $hmac.ComputeHash($Script:_YANA_SECRET_PROVIDER.IV + $cipherBytes) } finally { $hmac.Dispose() }
  $cipherB64 = [Convert]::ToBase64String($hmacBytes + $Script:_YANA_SECRET_PROVIDER.IV + $cipherBytes)
  [string]::Concat($Script:_YANA_SECRET_PREFIX, $cipherB64, $Script:_YANA_SECRET_SUFFIX)
}

# Finds and Decrypts encrypted values in a string using the initialized secret provider, expecting the encrypted strings with a prefix and suffix.
function yana_decrypt_string([Parameter(ValueFromPipeline = $true)][string]$InputString) {
  if ($null -eq $Script:_YANA_SECRET_PROVIDER) { throw 'Secret Provider is not initialized. Call _yana_initialize_encryption first.' }
  $pattern = "$([regex]::Escape($Script:_YANA_SECRET_PREFIX))(?<ciphertext>[A-Za-z0-9+/=]+)$([regex]::Escape($Script:_YANA_SECRET_SUFFIX))"
  foreach ($placeholder in ([Regex]::Matches($InputString, $pattern) | ForEach-Object { [pscustomobject]@{ value = $_.Value; ciphertext = $_.Groups['ciphertext'].Value } } | Select-Object -Unique)) {
    if ($placeholder.ciphertext.Length -lt 88) {
      log warn "Encrypted string is too short to be valid: $($placeholder.ciphertext)"
      continue
    }
    try {
      $cipherBytes = [Convert]::FromBase64String($placeholder.ciphertext)
      $hmacBytes = $cipherBytes[0..31]
      $ivBytes = $cipherBytes[32..47]
      $actualCipherBytes = $cipherBytes[48..($cipherBytes.Length - 1)]
      $hmac = [System.Security.Cryptography.HMACSHA256]::new($Script:_YANA_SECRET_PROVIDER.Key)
      try { $hmacBytesComputed = $hmac.ComputeHash($ivBytes + $actualCipherBytes) } finally { $hmac.Dispose() }
      if ([Convert]::ToBase64String($hmacBytesComputed) -ne [Convert]::ToBase64String($hmacBytes)) {
        log warn "HMAC validation failed for encrypted string: $($placeholder.ciphertext)"
        continue
      }
      $decryptor = $Script:_YANA_SECRET_PROVIDER.CreateDecryptor($Script:_YANA_SECRET_PROVIDER.Key, $ivBytes)
      $decryptedBytes = $decryptor.TransformFinalBlock($actualCipherBytes, 0, $actualCipherBytes.Length)
      $decryptedString = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
      $InputString = $InputString.Replace($placeholder.value, $decryptedString)
    } catch {
      log warn "Decryption failed for encrypted string: $cipherText. Error: $($_.Exception.Message)"
      continue
    }
    # Process each unique match here
  }
  $InputString
}

# Executes a function with the specified prefix and name.
function _yana_execute_fn([string]$RootDir = $Script:YANA_SOURCE, [string]$Prefix, [string]$Name, [bool]$Sensitive = $false, [hashtable]$Arguments) {
  # Parse function name. Format: `[module/]script:function`
  # Module and script supports alphanumeric characters, underscores, hyphens, and dots.
  # Function supports only alphanumeric characters and underscores.
  if ($Name -match '^((?<module>[a-zA-Z0-9][a-zA-Z0-9_\.-]*)/)?(?<script>[a-zA-Z0-9][a-zA-Z0-9_\.-]*)\:(?<function>[a-zA-Z0-9_]+)$') {
    $local:fnModule = $matches['module']
    $local:fnScript = $matches['script']
    $local:fnFunction = $matches['function']
  } else {
    throw "Invalid function name: '$Name'. Expected format: '[module/]script:function'."
  }
  $fnArgs = _yana_resolve_args $Arguments
  $local:fullFnName = "${Prefix}_${local:fnFunction}"
  log debug "Executing function '$local:fullFnName' from module '$local:fnModule', script '$local:fnScript' with arguments: $($fnArgs | ConvertTo-Json -Compress)"
  $sb = {
    Get-Item @(
      ([System.IO.Path]::Combine($YANA_SOURCE, '.yana', '*', '.ps1')),
      ([System.IO.Path]::Combine($YANA_SOURCE, '.yana', '.ps1')),
      ([System.IO.Path]::Combine($YANA_SOURCE, '.yana', $fnModule, "$fnScript.ps1"))
    ) -Force -ErrorAction Ignore | ForEach-Object {
      log trace "Loading script: $($_.FullName)"
      . $_.FullName }
    $yana_cmd = Get-Command $YANA_COMMAND -ErrorAction SilentlyContinue
    if ($null -eq $yana_cmd) { throw "Function '$YANA_COMMAND' not found in the loaded scripts." }
    log trace "Invoking function '$YANA_COMMAND' with arguments: $($YANA_ARGS | ConvertTo-Json -Compress)"
    $YANA_ARGS = @{}
    foreach ($arg in $fnArgs.GetEnumerator()) {
      $YANA_ARGS[$arg.Name] = if ($arg.Value -is [string]) { yana_decrypt_string $arg.Value } else { $arg.Value }
      if ($yana_cmd.Parameters.ContainsKey($arg.Name) -and $yana_cmd.Parameters[$arg.Name].ParameterType -eq [securestring]) {
        $YANA_ARGS[$arg.Name] = ConvertTo-SecureString -String $YANA_ARGS[$arg.Name] -AsPlainText -Force
      }
    }
    if ($Sensitive) {
      log debug "Function '$local:fullFnName' is marked as sensitive. Its output will be encrypted."
      & $YANA_COMMAND @YANA_ARGS | yana_encrypt_string
    } else {
      & $YANA_COMMAND @YANA_ARGS
    }
  }
  $output = $sb.InvokeWithContext(
    @{
      log = (Get-Command log).ScriptBlock
    },
    @(
      [psvariable]::new('YANA_COMMAND', $local:fullFnName, 'ReadOnly'),
      [psvariable]::new('fnArgs', $fnArgs, 'ReadOnly'),
      [psvariable]::new('YANA_SOURCE', $RootDir, 'ReadOnly')
    ), $null
  )

  log trace "Function '$local:fullFnName' executed successfully"
  $output
}
# Converts an object to a hashtable recursively.
function _yana_tohashtable([Parameter(ValueFromPipeline = $true)]$InputObject) {
  $resultValue = @{}
  if ($InputObject -is [System.Collections.IDictionary]) {
    foreach ($key in $InputObject.Keys) { $resultValue[$key] = _yana_tohashtable($InputObject[$key]) }
  } elseif ($InputObject -is [System.Collections.ICollection]) {
    $resultValue = @()
    $InputObject | ForEach-Object { $resultValue += _yana_tohashtable($_) }
  } elseif ($InputObject -is [System.Management.Automation.PSCustomObject]) {
    foreach ($prop in $InputObject.PSObject.Properties) { $resultValue[$prop.Name] = _yana_tohashtable($prop.Value) }
  } else {
    $resultValue = $InputObject
  }
  Write-Output $resultValue -NoEnumerate:($resultValue -is [Array])
}
# Loads and parses the YANA spec file.
function _yana_load_spec_file([string]$Source) {
  $_yana_spec_file = [System.IO.Path]::GetFullPath($Source)
  if (Test-Path -Path $_yana_spec_file -PathType Container) { $_yana_spec_file = [System.IO.Path]::Combine($_yana_spec_file, '.yana.json') }
  if (-not (Test-Path -Path $_yana_spec_file -PathType Leaf)) { throw "Source '$_yana_spec_file' does not exist." }

  $spec = Get-Content -Path $_yana_spec_file -Raw | ConvertFrom-Json | _yana_tohashtable
  if ($spec -isnot [hashtable]) { throw "Failed to parse YANA spec file '$_yana_spec_file'." }

  $Script:YANA_SPEC = @{
    name        = $spec['name']
    description = $spec['description']
    version     = $spec['version']
    author      = $spec['author']
    license     = $spec['license']
  }
  $Script:YANA_REQUIRES = $spec['requires']
  if ($null -eq $Script:YANA_REQUIRES) { $Script:YANA_REQUIRES = @() }
  if ($Script:YANA_REQUIRES -isnot [array]) { throw "Spec field 'requires' must be an array." }
  $Script:YANA_STEPS = $spec['steps']
  if ($null -eq $Script:YANA_STEPS) { $Script:YANA_STEPS = @() }
  if ($Script:YANA_STEPS -isnot [array]) { throw "Spec field 'steps' must be an array." }
  $Script:YANA_PARAMS = $spec['params']
  if ($null -eq $Script:YANA_PARAMS) { $Script:YANA_PARAMS = @{} }
  if ($Script:YANA_PARAMS -isnot [hashtable]) { throw "Spec field 'params' must be an object." }
  $Script:YANA_VARS = $spec['vars']
  if ($null -eq $Script:YANA_VARS) { $Script:YANA_VARS = @{} }
  if ($Script:YANA_VARS -isnot [hashtable]) { throw "Spec field 'vars' must be an object." }
  return [System.IO.Path]::GetDirectoryName($_yana_spec_file)
}
function _yana_expand_var([string]$VarName, [hashtable]$Vars) {
  if (-not $Vars.ContainsKey($VarName)) { throw "Variable '$VarName' is not defined." }
  $output = $Vars[$VarName]
  if ($output -is [hashtable]) {
    $cached = $output['cached'] -eq $true
    $secret = $output['secret'] -eq $true
    log trace "Resolving variable '$VarName', cached: $cached, secret: $secret, function: $($output['fn']), args: $($output['args'])"
    # $fnArgs=_yana_resolve_args $output['args']
    $output = _yana_execute_fn -RootDir $Script:YANA_SOURCE -Prefix 'yanavar' -Name $output['fn'] -Arguments $output['args'] -Sensitive $secret
    if ($cached) {
      log trace "Caching resolved value for variable '$VarName' as '$output'"
      $Vars[$VarName] = $output
    }
  }
  $output
}
function _yana_expand_param([string]$ParamName, [hashtable]$Params) {
  if ($Params.ContainsKey($ParamName)) { $Params[$ParamName] } else { throw "Parameter '$ParamName' is not defined." }
}
# Resolves variable placeholders in the input string.
function _yana_expand_string([Parameter(ValueFromPipeline = $true)][string]$InputString, [hashtable]$Params, [hashtable]$Vars) {
  $Script:MaxNestingDepth = 50
  if ((Get-PSCallStack).Count -gt $Script:MaxNestingDepth) { throw "Maximum nesting depth of $Script:MaxNestingDepth exceeded while expanding string." }
  $_iteration = 0
  log debug "Expanding string '$InputString'"
  while ($InputString -match '\$\{(?<ctx>param|var):(?<name>[a-zA-Z0-9_]+)\}') {
    $_iteration++
    if ($_iteration -gt $Script:MaxNestingDepth) { throw "Maximum nesting depth of $Script:MaxNestingDepth exceeded while expanding string." }
    $placeholder = $Matches[0]
    $ctx = $Matches['ctx']
    $name = $Matches['name']
    if ($ctx -eq 'param') { $value = _yana_expand_param -ParamName $name -Params $Params }
    elseif ($ctx -eq 'var') { $value = _yana_expand_var -VarName $name -Vars $Vars }
    else { throw "Unknown context '$ctx' in placeholder '$placeholder'." }
    $InputString = $InputString.Replace($placeholder, $value)
    log trace "Resolved placeholder '$placeholder' to value '$value'"
  }
  $InputString
}

function _yana_resolve_args([hashtable]$SpecArgs) {
  $resolvedArgs = @{}
  foreach ($key in $SpecArgs.Keys) {
    $value = $SpecArgs[$key]
    if ($value -is [string]) {
      $resolvedArgs[$key] = _yana_expand_string -InputString $value -Params $Script:YANA_PARAMS -Vars $Script:YANA_VARS
    } else {
      $resolvedArgs[$key] = $value | convertto-json -Compress -Depth 5 | _yana_expand_string -Params $Script:YANA_PARAMS -Vars $Script:YANA_VARS
    }
  }
  $resolvedArgs
}
# Evaluates the conditions for a step and returns $true if the step should be executed, or $false if it should be skipped.
function _yana_eval_conditions([hashtable]$Step) {
  $stepName = $Step['name']
  $stepConditions = $Step['if']
  if ([string]::IsNullOrEmpty($stepConditions)) { $stepConditions = @() }
  if ($stepConditions -isnot [array]) { $stepConditions = @($stepConditions) }
  foreach ($cond in $stepConditions) {
    $condValue = _yana_expand_string -InputString $cond -Params $Script:YANA_PARAMS -Vars $Script:YANA_VARS
    if (-not [bool]$condValue) {
      log debug "Step '$stepName' skipped due to 'if' condition: '$cond'"
      return $false
    }
    log debug "Step '$stepName' passed 'if' condition: '$cond'"
  }
  $stepConditions = $Step['if_not']
  if ([string]::IsNullOrEmpty($stepConditions)) { $stepConditions = @() }
  if ($stepConditions -isnot [array]) { $stepConditions = @($stepConditions) }
  foreach ($cond in $stepConditions) {
    $condValue = _yana_expand_string -InputString $cond -Params $Script:YANA_PARAMS -Vars $Script:YANA_VARS
    if ([bool]$condValue) {
      log debug "Step '$stepName' skipped due to 'if_not' condition: '$cond'"
      return $false
    }
    log debug "Step '$stepName' passed 'if_not' condition: '$cond'"
  }
  $true
}
# Verifies a step from the YANA spec.
function _yana_verify_step([hashtable]$Step, [string]$RootDir = $Script:YANA_SOURCE) {
  $stepName = $Step['name']
  $stepFunction = $Step['verify']

  if ($null -eq $stepFunction) { $stepFunction = $Step['apply'] }
  if ($stepFunction -eq '-') { $stepFunction = '' }

  if ([string]::IsNullOrEmpty($stepFunction)) { log skip "Step '$stepName' has no 'verify' function defined" ; return }
  if (-not (_yana_eval_conditions -Step $Step)) { log skip "Step '$stepName' conditions not met" ; return }
  log info "Verifying step: $stepName using function: $stepFunction"
  try {
    _yana_execute_fn -RootDir $RootDir -Prefix 'yanaverify' -Name $stepFunction -Arguments $Step['args']
  } catch [System.Management.Automation.CommandNotFoundException] {
    log skip "Verification function '$stepFunction' for step '$stepName' not found"
  }
}

# Applies a step from the YANA spec.
function _yana_apply_step([hashtable]$Step, [string]$RootDir = $Script:YANA_SOURCE) {
  $stepName = $Step['name']
  $applyFn = $Step['apply']
  if ([string]::IsNullOrEmpty($applyFn)) { log skip "Step '$stepName' has no 'apply' function defined" ; return }
  if (-not (_yana_eval_conditions -Step $Step)) { log skip "Step '$stepName' conditions not met" ; return }
  $verifyResult = _yana_verify_step -Step $Step -RootDir $RootDir
  if ($verifyResult) { log success "Step '$stepName' is already compliant" ; return }
  log info "Applying step: $stepName using function: $applyFn"
  _yana_execute_fn -RootDir $RootDir -Prefix 'yanaapply' -Name $applyFn -Arguments $Step['args']
  $verifyResult = _yana_verify_step -Step $Step -RootDir $RootDir
  if ($null -eq $verifyResult) { return }
  if ([bool]$verifyResult) { log success "Step '$stepName' is fully compliant" ; return }
  throw "Step '$stepName' is not compliant after apply"
}

# Pulls, unpacks and verifies the YANA Module as yanapack from the specified source (url/path).
# Returns path to the unpacked YANA Module.
function _yana_mode_pull([ValidateNotNullOrEmpty()][string]$Source = $Env:YANA_SOURCE) {
  if ($Source -match '^https?://') {
    $uri = $null
    [uri]::TryCreate($Source, [uriKind]::Absolute, [ref]$uri) | Out-Null
    if ($null -eq $uri -or ($uri.Scheme -notin 'http', 'https')) { throw "Source '$Source' is not a valid URL." }
    log info 'Downloading YANA Module from provided source'
    $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $zipFile = [System.IO.Path]::Combine($tempDir, 'yanapack.zip')
    Invoke-WebRequest -Uri $Source -OutFile $zipFile -ErrorAction Stop -UseBasicParsing -TimeoutSec 30
    log debug "Downloaded YANA Module to '$zipFile'. Unpacking..."
    Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
    Remove-Item -Path $zipFile -Force
    # Later add verification of the downloaded module (e.g., checksum, signature) if needed.
    $Source = $tempDir
  }
  $Source = [System.IO.Path]::GetFullPath($Source)
  if (Test-Path -Path $Source -PathType Container) { $Source = [System.IO.Path]::Combine($Source, '.yana.json') }
  if (-not (Test-Path -Path $Source -PathType leaf)) { throw "Source '$Source' does not exist." }
  return $Source
}
#	Applies the specified YANA Module.
function _yana_mode_apply([ValidateNotNullOrEmpty()][string]$Source = $Env:YANA_SOURCE) {
  # if ([string]::IsNullOrEmpty($Source)) { throw 'Source is required for ''apply'' mode.' }
  $Source = _yana_mode_pull -Source $Source
  log info "Applying YANA Module from source: $Source"

  $Script:YANA_SOURCE = _yana_load_spec_file -Source $Source
  _yana_check_prerequisites -Prerequisites $Script:YANA_REQUIRES
  _yana_initialize_encryption
  foreach ($step in $Script:YANA_STEPS) {
    _yana_apply_step -Step $step
  }
  log success "YANA Module applied successfully: $Script:YANA_SOURCE"
}
function _yana_mode_verify([ValidateNotNullOrEmpty()][string]$Source = $Env:YANA_SOURCE) {
  # if ([string]::IsNullOrEmpty($Source)) { throw 'Source is required for ''verify'' mode' }
  $Source = _yana_mode_pull -Source $Source
  log info "Verifying YANA Module from source: $Source"

  $Script:YANA_SOURCE = _yana_load_spec_file -Source $Source
  _yana_check_prerequisites -Prerequisites $Script:YANA_REQUIRES
  _yana_initialize_encryption
  foreach ($step in $Script:YANA_STEPS) {
    $verifyResult = _yana_verify_step -Step $step
    if ($null -eq $verifyResult) { continue }
    if ([bool]$verifyResult) { log success "Step '$($step['name'])' is compliant" ; continue }
    throw "Step '$($step['name'])' is not compliant"
  }
  log success "YANA Module verified successfully: $Script:YANA_SOURCE"
}

# The main entry point for YANA.
function _yana_ {
  param(
    # If specified, outputs help information and exits.
    [switch]$Help,
    [Parameter(Position = 0)]
    [ValidateSet('apply', 'verify', 'pull', 'version')]
    [string]$Mode = $Env:YANA_MODE,
    # If specified, the source of the YANA Module to apply/verify/pull.
    # [Parameter(Position = 1)]
    [string]$Source = $Env:YANA_SOURCE,
    # If specified, outputs log messages to the given file.
    # Uses YANA_LOGFILE environment variable if set.
    [string]$LogFile = $Env:YANA_LOGFILE
  )
  # Disable progress bar output
  $Script:ProgressPreference = 'SilentlyContinue'
  log info "$Script:YANA_TITLE Version: $Script:YANA_VERSION"
  $Script:YANA_TRACE = $Env:YANA_TRACE -eq 'true'
  $Script:YANA_DEBUG = $Script:YANA_TRACE -or $Env:YANA_DEBUG -eq 'true'
  if ($Script:YANA_DEBUG) { log debug 'Debug logging is enabled.' }
  if ($Script:YANA_TRACE) { $script:VerbosePreference = 'Continue' }
  if ($Help) { _yana_usage -Mode $Mode; return }
  switch ($Mode) {
    'apply' { _yana_mode_apply -Source $Source }
    'verify' { _yana_mode_verify -Source $Source }
    'pull' { _yana_mode_pull -Source $Source }
    'version' { $Script:YANA_VERSION }
    default { throw "Unknown mode: '$Mode'. Use -help for usage information." }
  }
}

# Prevent running when dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
  $ErrorActionPreference = 'Stop'
  try {
    _yana_ @args
  } catch {
    log fatal $_.Exception.Message
    $_.ScriptStackTrace | ForEach-Object { log stack $_ }
    _yana_cleanup_encryption
    exit 1
  }
}
