#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# YANA - Yet Another Node Automator (Bash)
# ---------------------------------------------------------------------------

# Bash 4+ version check
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]:-1}" -lt 4 ]; then
	echo 'Error: Bash 4.0 or higher is required.' >&2
	exit 1
fi

# YANA_SOURCE='examples/linux'
# YANA_MODE='apply'
# YANA_TRACE=true

set -eEuo pipefail

[[ -z ${YANA_TITLE:-} ]] && builtin readonly YANA_TITLE='YANA - Yet Another Node Automator (Bash)'
[[ -z ${YANA_VERSION:-} ]] && builtin readonly YANA_VERSION='YANAVERSIONPLACEHOLDER'

FUNCNEST=100
[[ -z ${ERR_GENERAL:-} ]] && builtin readonly ERR_GENERAL=1 ERR_MISUSE=64 ERR_DATA_FORMAT=65 ERR_NO_INPUT=66

_yana_usage() {
	case "${YANA_MODE:-}" in
	apply)
		builtin echo "Usage: yana.sh apply -source <path|url>"
		builtin echo "  Applies the specified YANA Module."
		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to apply. Can be a local path or a URL. Uses YANA_SOURCE environment variable."
		;;
	verify)
		builtin echo "Usage: yana.sh verify -source <path|url>"
		builtin echo "  Compares the state of the system with the state specified by the YANA Module without making any changes."
		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to verify. Can be a local path or a URL. Uses YANA_SOURCE environment variable."
		;;
	pull)
		builtin echo "Usage: yana.sh pull -source <path|url>"
		builtin echo "  Pulls the specified YANA Module from the given source (path or URL)."
		builtin echo "Options:"
		builtin echo "  -source <path|url>         Specifies the source of YANA Module to pull. Can be path or URL. Uses YANA_SOURCE environment variable."
		;;
	version)
		builtin echo "Usage: yana.sh version"
		builtin echo "  Displays the version of YANA."
		;;
	*)
		builtin echo "Usage: yana.sh <general options> [mode] <mode options>"
		builtin echo "Modes:"
		builtin echo "  version									 	 Displays the version of YANA."
		builtin echo "  apply                      Applies the specified YANA Module."
		builtin echo "  verify                     Compares the state of the system with the state specified by the YANA Module without making any changes."
		builtin echo "  pull                       Pulls the specified YANA Module."
		;;
	esac
	builtin echo "General Options:"
	builtin echo "  -help                      Displays this help message."
	builtin echo "  -help <mode>               Displays help for the specified mode."
	builtin echo "  -logfile <file>            Log file path. Uses YANA_LOGFILE environment variable. If not specified, logs are not written to a file."
}

# Logs a colored message to the stderr.
# Takes care of logging to a file if $YANA_LOGFILE is specified.
log() {
	builtin local _level="${1:-${level:-info}}"
	builtin local _message="${2:-${message:-}}"
	_level="${_level^^}"
	[[ -n $_message ]] || throw "No message provided to log function." $ERR_NO_INPUT
	[[ ${YANA_TRACE:-false} != true && $_level == TRACE ]] && return 0
	[[ ${YANA_DEBUG:-${YANA_TRACE:-false}} != true && $_level == DEBUG ]] && return 0
	builtin local _logMessage _color_code='' _reset_code=''
	if [[ -t 2 ]]; then
		case "$_level" in
		TRACE | DEBUG) _color_code='\033[0;90m' ;;       # Gray
		INFO) _color_code='\033[0;36m' ;;                # Cyan
		OK | SUCCESS | PASS) _color_code='\033[0;32m' ;; # Green
		SKIP) _color_code='\033[0;33m' ;;                # Yellow
		WARN) _color_code='\033[0;93m' ;;                # Bright Yellow
		FAIL | ERROR) _color_code='\033[0;91m' ;;        # Bright Red
		FATAL) _color_code='\033[0;31m' ;;               # Red
		*) _color_code='\033[0m' ;;                      # Default
		esac
		_reset_code='\033[0m'
	fi
	_logMessage="${_color_code}$(date -u +'%Y-%m-%dT%H:%M:%SZ')\t${_level}\t${_message}${_reset_code}"
	builtin echo -e "$_logMessage" >&2
	if [[ -n ${YANA_LOGFILE:-} ]]; then
		# shellcheck disable=SC2097,SC2098
		builtin echo -e "${_logMessage}" >>"$YANA_LOGFILE" || YANA_LOGFILE='' log error "Failed to write to log file '$YANA_LOGFILE'. Check permissions and available disk space."
	fi
}

# Throws an error message and exits the script with the specified return code.
throw() {
	set +x
	builtin local _message="${1:-${message:-Halted}}"
	builtin local _rc="${2:-${rc:-$ERR_GENERAL}}"
	log fatal "$_message"
	builtin local _frame=0 _trace
	while true; do
		_trace=$(builtin caller $_frame | awk '{print $3 ":" $1 " (" $2 ") "}')
		[[ -z $_trace ]] && break
		log stack "$_trace"
		((_frame += 1))
	done
	builtin exit "$_rc"
}
# Tests if the required commands are available in the system PATH.
_yana_check_prerequisites() {
	builtin local cmd
	for cmd in "$@"; do builtin command -v "$cmd" &>/dev/null || throw "Prerequisite '$cmd' is not installed or not in the system PATH." $ERR_MISUSE; done
}
# Secret management variables and functions.
# Initializes the secret management by generating a random key and storing it in a secure file descriptor.
_yana_initialize_encryption() {
	_YANA_SECRET_KEY='' _YANA_SECRET_ALGORITHM='aes-256-cbc' _YANA_SECRET_PREFIX='<yanasecret:' _YANA_SECRET_SUFFIX='>'
	builtin local tmp
	{
		[[ -d /dev/shm ]] && tmp='/dev/shm' || tmp="${TMPDIR:-/tmp}"
		tmp=$(mktemp -p "$tmp")
		chmod 600 "$tmp"
		openssl rand -hex 32 >"$tmp"
		builtin exec {_YANA_SECRET_KEY}<"$tmp"
		rm -f "$tmp"
	} || throw "Failed to initialize encryption" $ERR_GENERAL
}
# Cleans up the secret management by closing the secure file descriptor and unsetting the key variable.
_yana_cleanup_encryption() {
	{
		[[ -n ${_YANA_SECRET_KEY:-} ]] && builtin exec {_YANA_SECRET_KEY}<&-
		builtin unset _YANA_SECRET_KEY
	}
}
# Encrypts a string using the initialized secret key and algorithm, returning the encrypted string with a prefix and suffix.
yana_encrypt_string() {
	builtin local _input="${1:-$(cat -)}"
	[[ -z ${_YANA_SECRET_KEY:-} ]] && throw "Secret key is not initialized. Call _yana_initialize_encryption first." $ERR_MISUSE
	builtin local _iv _cipher _hmac
	_iv=$(openssl rand -hex 16)
	_cipher=$(
		builtin set +x
		openssl enc -"$_YANA_SECRET_ALGORITHM" -a -A -K "$(cat /proc/self/fd/"${_YANA_SECRET_KEY}")" -iv "$_iv" -nosalt -pbkdf2 <<<"$_input"
	) || throw "Failed to encrypt string." $ERR_GENERAL
	[[ -n $_cipher ]] || throw "Encrypted string is empty." $ERR_GENERAL
	_hmac=$(
		builtin set +x
		openssl dgst -sha256 -mac HMAC -macopt "hexkey:$(cat /proc/self/fd/"${_YANA_SECRET_KEY}")" <<<"$_iv$_cipher" | awk '{print $2}'
	) || throw "Failed to compute HMAC for encrypted string." $ERR_GENERAL
	[[ -n $_hmac ]] || throw "HMAC is empty." $ERR_GENERAL
	echo -n "${_YANA_SECRET_PREFIX}${_hmac,,}${_iv}${_cipher}${_YANA_SECRET_SUFFIX}"
}

# Finds and Decrypts encrypted values in a string using the initialized secret key and algorithm, expecting the encrypted strings with a prefix and suffix.
yana_decrypt_string() {
	builtin local _input="${1:-$(cat -)}"
	[[ -z ${_YANA_SECRET_KEY:-} ]] && throw "Secret key is not initialized. Call _yana_initialize_encryption first." $ERR_MISUSE
	builtin local _pattern="$_YANA_SECRET_PREFIX([0-9a-f]{64})([0-9a-f]{32})([A-Za-z0-9+/=]+)$_YANA_SECRET_SUFFIX"
	# Find all unique occurrences of the encrypted string pattern in the input
	builtin local -a _secret_matches
	builtin readarray -t _secret_matches < <(grep -oP "$_pattern" <<<"$_input" | sort -u)
	builtin local _secret_match
	for _secret_match in "${_secret_matches[@]}"; do
		builtin local _hmac _iv _cipher _decrypted
		if [[ $_secret_match =~ $_pattern ]]; then
			_hmac="${BASH_REMATCH[1]}"
			_iv="${BASH_REMATCH[2]}"
			_cipher="${BASH_REMATCH[3]}"
			_computed_hmac=$(
				builtin set +x
				openssl dgst -sha256 -mac HMAC -macopt "hexkey:$(cat /proc/self/fd/"${_YANA_SECRET_KEY}")" <<<"$_iv$_cipher" | awk '{print $2}'
			) || {
				log skip "Failed to compute HMAC for encrypted string"
				continue
			}
			[[ $_hmac != "${_computed_hmac,,}" ]] && {
				log skip "HMAC mismatch for encrypted string"
				continue
			}
			_decrypted=$(
				builtin set +x
				openssl enc -d -"$_YANA_SECRET_ALGORITHM" -a -A -K "$(cat /proc/self/fd/"${_YANA_SECRET_KEY}")" -iv "$_iv" -nosalt -pbkdf2 <<<"$_cipher"
			) || {
				log skip "Failed to decrypt string"
				continue
			}
			_input="${_input//$_secret_match/$_decrypted}"
		fi
	done
	echo -n "$_input"

}
# Executes a function with the given prefix and name, passing the provided arguments, and captures the output in the specified reference variable.
# The function name should be in the format '[module/]script:function'.
# If the 3rd argument is 'true', the function is marked as sensitive, its output will be encrypted before being returned.
_yana_execute_fn() {
	builtin local _yana_fn_prefix="$1" _yana_fn="$2"
	builtin local -n _yana_output_ref="$3"
	builtin local -n _yana_args_ref="$4"
	log trace "_yana_execute_fn '$_yana_fn' with arguments: ${_yana_args_ref[*]}"

	# Parse function name. Format: `[module/]script:function`
	if [[ $_yana_fn =~ ^(([a-zA-Z0-9][a-zA-Z0-9_\.-]*)/)?([a-zA-Z0-9][a-zA-Z0-9_\.-]*)\:([a-zA-Z0-9_]+)$ ]]; then
		builtin local _yana_fn_module="${BASH_REMATCH[2]}"
		builtin local _yana_fn_script="${BASH_REMATCH[3]}"
		builtin local _yana_fn_func="${BASH_REMATCH[4]}"
		log debug "Parsed function name: module='$_yana_fn_module', script='$_yana_fn_script', function='$_yana_fn_func'"
	else
		throw "Invalid function name format: '$_yana_fn'. Expected format: '[module/]script:function'." $ERR_NO_INPUT
	fi
	builtin local _rc=0 _yana_source_dir
	_yana_source_dir=$(_yana_source_dir) || throw
	_yana_output_ref=$(
		# Unset any previously defined private _yana_ functions and variables to avoid conflicts
		for _fn in $(builtin declare -F | awk '$3 ~ /^_yana_/ {print $3}'); do unset -f "$_fn"; done
		# for _var in $(builtin declare -p | awk -F '[ =]' '$3 ~ /^_yana_/ {print $3}'); do builtin unset -v "$_var"; done
		# builtin unset -v _fn _var

		# Load the common scripts for the module if they exist
		builtin local -a _yana_include_scripts
		builtin readarray -t _yana_include_scripts < <(ls -1 "$_yana_source_dir/.yana"/*/.sh "$_yana_source_dir/.yana/.sh" 2>/dev/null || true)
		[[ -n $_yana_fn_script ]] && _yana_include_scripts+=("$_yana_source_dir/.yana/${_yana_fn_script}.sh")
		builtin local _yana_script_path
		for _yana_script_path in "${_yana_include_scripts[@]}"; do
			log trace "Sourcing script '$_yana_script_path'"
			# shellcheck source=/dev/null
			builtin source "$_yana_script_path" >&2 || throw "Failed to source script '$_yana_script_path'." $?
		done
		log trace "Executing function '${_yana_fn_prefix}_${_yana_fn_func}' from script '$_yana_fn_script' in module '$_yana_fn_module' with arguments: ${_yana_args_ref[*]}"
		#shellcheck disable=SC2034
		(
			set +x
			set -o pipefail
			builtin local YANA_COMMAND="${_yana_fn_prefix}_${_yana_fn_func}"
			builtin local -A YANA_ARGS
			for key in "${!_yana_args_ref[@]}"; do
				YANA_ARGS["$key"]=$(yana_decrypt_string "${_yana_args_ref[$key]}")
			done
			if [[ ${sensitive:-false} == true ]]; then
				"$YANA_COMMAND" | yana_encrypt_string
			else
				"$YANA_COMMAND"
			fi
		)
	) || _rc=$?
	builtin return $_rc
}

_yana_expand_var() {
	builtin local _yana_var_name="${1:-}"
	builtin local -n _output_ref="${2:-}"
	builtin local -n _yana_vars_ref="${3:-YANA_VARS}"
	[[ -n $_yana_var_name ]] || throw "No variable name provided to _yana_expand_var." $ERR_NO_INPUT
	[[ -v _yana_vars_ref[$_yana_var_name] ]] || throw "Variable '$_yana_var_name' is not defined in the YANA spec." $ERR_NO_INPUT
	builtin local _yana_var_val="${_yana_vars_ref[$_yana_var_name]}"
	log trace "Expanding variable '$_yana_var_name' with value: $_yana_var_val"
	if [[ $_yana_var_val == '"'*'"' ]]; then
		_output_ref=$(jq -r '.' <<<"$_yana_var_val") || throw "Failed to parse JSON string for variable '$_yana_var_name'. Ensure it is valid JSON." $ERR_DATA_FORMAT
		log trace "Variable '$_yana_var_name' resolved to JSON string: $_output_ref"
		return 0
	fi
	if [[ $_yana_var_val != '{'*'}' ]]; then
		_output_ref="$_yana_var_val"
		log trace "Variable '$_yana_var_name' resolved to non-object value: $_output_ref"
		return 0
	fi
	_output_ref=''
	log trace "Variable '$_yana_var_name' is a JSON object. Attempting to resolve as a function call."

	builtin local _yana_var_fn _yana_var_args_raw _yana_var_cached
	builtin local -a _yana_var_args_array
	builtin local -A _yana_var_args
	# If the value is a JSON object, parse it and extract the function and arguments
	_yana_var_fn=$(jq -r '.fn // empty' <<<"$_yana_var_val") || throw "Failed to parse JSON for variable '$_yana_var_name'. Ensure it is valid JSON." $ERR_DATA_FORMAT
	[[ -z $_yana_var_fn ]] && throw "Variable '$_yana_var_name' is defined as an object but has an empty 'fn' value. Ensure it is properly defined in the YANA spec." $ERR_DATA_FORMAT
	_yana_var_cached=$(jq -r '.cached == true' <<<"$_yana_var_val") || throw "Failed to parse JSON for variable '$_yana_var_name'. Ensure it is valid JSON." $ERR_DATA_FORMAT
	_yana_var_secret=$(jq -r '.secret == true' <<<"$_yana_var_val") || throw "Failed to parse JSON for variable '$_yana_var_name'. Ensure it is valid JSON." $ERR_DATA_FORMAT
	_yana_var_args_raw=$(jq -r '(.args | objects) // {} | to_entries | map("\(.key):\(.value|@text|@base64)") | .[]' <<<"$_yana_var_val") || throw "Failed to parse JSON for variable '$_yana_var_name'. Ensure it is valid JSON." $ERR_DATA_FORMAT
	_yana_resolve_args "$_yana_var_args_raw" _yana_var_args || throw "Failed to resolve arguments for variable '$_yana_var_name'." $ERR_DATA_FORMAT
	sensitive="${_yana_var_secret}" _yana_execute_fn 'yanavar' "${_yana_var_fn}" _output_ref _yana_var_args || throw "Function 'yanavar_$_yana_var_fn' failed" $?
	log trace "Function 'yanavar_$_yana_var_fn' executed and output: $_output_ref"
	if [[ $_yana_var_cached == true ]]; then
		_yana_vars_ref["$_yana_var_name"]=$(jq -R '.' <<<"$_output_ref") || throw "Failed to cache resolved value for variable '$_yana_var_name' as JSON string." $ERR_DATA_FORMAT
		log trace "Cached resolved value for variable '$_yana_var_name' as JSON string: ${_yana_vars_ref["$_yana_var_name"]}"
	fi
}
# Resolves variable placeholders in the input string.
_yana_expand_string() {
	builtin local _input="${1:-$(cat -)}"
	builtin local -n _output_ref="${2:-}"
	log trace "Expanding string '$_input'"
	builtin local _resolve_iters=0 _max_iters=${FUNCNEST:-50} _value=''
	while [[ $_input =~ \$\{(param|var):([a-zA-Z0-9_]+)\} ]]; do
		builtin local _var="${BASH_REMATCH[0]}" _ctx="${BASH_REMATCH[1]}" _key="${BASH_REMATCH[2]}" _value=''
		log trace "Resolving variable '$_var' with context '$_ctx' and key '$_key'"
		((_resolve_iters++))
		[[ $_resolve_iters -gt $_max_iters ]] && throw "Variable resolution exceeded $_max_iters iterations (possible circular reference)." $ERR_DATA_FORMAT
		case "$_ctx" in
		param) if [[ -v YANA_PARAMS["$_key"] ]]; then _value="${YANA_PARAMS[$_key]:-}"; else throw "Parameter '$_key' is not defined." $ERR_MISUSE; fi ;;
		var) if [[ -v YANA_VARS["$_key"] ]]; then _yana_expand_var "$_key" _value; else throw "Variable '$_key' is not defined." $ERR_MISUSE; fi ;;
		*) throw "Unknown variable type '$_ctx' in variable reference '$_var'. This should never happen. Please report this as a bug." $ERR_GENERAL ;;
		esac
		[[ -z $_value ]] && log warn "Variable '$_var' resolved to an empty value. Ensure that the variable is defined and has a non-empty value."
		log trace "Resolved variable '$_var' to value: $_value"
		_input="${_input//$_var/$_value}"
		log trace "Intermediate resolved input: $_input"
	done
	_output_ref="$_input"
}
_yana_resolve_args() {
	builtin local _yana_args="$1"
	builtin local -n _yana_args_ref="${2:-YANA_ARGS}"
	builtin local -a _yana_args_array
	builtin readarray -t _yana_args_array <<<"$_yana_args"
	_yana_args_ref=()
	builtin local _arg _key _value _result
	for _arg in "${_yana_args_array[@]}"; do
		[[ -n $_arg ]] || continue
		_key="${_arg%%:*}"
		_value="${_arg#*:}"
		_yana_expand_string "$(base64 -d <<<"$_value")" _result || throw "Failed to resolve variable placeholders in argument '$_key' with value '$_value'." $ERR_DATA_FORMAT
		_yana_args_ref["$_key"]="$_result"
	done
}
_yana_load_step() {
	builtin local _yana_step_b64="${1:-}"
	builtin local -n _yana_step_ref="${2:-YANA_STEP}"
	builtin local _yana_step_json
	[[ -n $_yana_step_b64 ]] || throw "No step data provided to _yana_load_step." $ERR_NO_INPUT
	_yana_step_json=$(builtin echo "$_yana_step_b64" | base64 -d) || throw "Failed to decode step data. Ensure it is valid base64." $ERR_NO_INPUT

	_yana_step_ref=()
	_yana_step_ref['id']=$(jq -r '.id // empty' <<<"$_yana_step_json")
	[[ -n ${_yana_step_ref['id']} && ! ${_yana_step_ref['id']} =~ ^[a-zA-Z0-9_]+$ ]] && throw "Step ID shall be empty or alphanumeric. Got: '${_yana_step_ref['id']}'" $ERR_NO_INPUT
	_yana_step_ref['name']=$(jq -r '.name // error' <<<"$_yana_step_json") || throw "Step name is missing in step data." $ERR_NO_INPUT
	_yana_step_ref['apply']=$(jq -r '.apply // "-"' 2>/dev/null <<<"$_yana_step_json")
	_yana_step_ref['verify']=$(jq -r '.verify // "-"' 2>/dev/null <<<"$_yana_step_json")
	_yana_step_ref['args']=$(jq -r '(.args | objects) // {} | to_entries | map("\(.key):\(.value|@text|@base64)") | .[]' <<<"$_yana_step_json")
	if [[ ${_yana_step_ref['apply']} == "-" && ${_yana_step_ref['verify']} == "-" ]]; then
		throw "Step '${_yana_step_ref['name']}' must have at least one of 'apply' or 'verify' defined." $ERR_NO_INPUT
	fi
	[[ ${_yana_step_ref['apply']} == "-" ]] && _yana_step_ref['apply']=""
	[[ ${_yana_step_ref['verify']} == "-" && -n ${_yana_step_ref['apply']} ]] && _yana_step_ref['verify']="${_yana_step_ref['apply']}"
	[[ ${_yana_step_ref['verify']} == "-" ]] && _yana_step_ref['verify']=""
	_yana_step_ref['if']=$(jq -r '.if // empty | @json' 2>/dev/null <<<"$_yana_step_json")
	_yana_step_ref['if_not']=$(jq -r '.if_not // empty | @json' 2>/dev/null <<<"$_yana_step_json")

}
# Evaluates the conditions for a step and returns 0 if the step should be executed, or 1 if it should be skipped.
_yana_eval_conditions() {
	builtin local -n _yana_step_ref="$1"
	builtin local _rc=0 _yana_step_condition _yana_cond _yana_cond_value
	builtin local -a _yana_if_conditions
	_yana_step_name="${_yana_step_ref['name']}"

	_yana_step_condition=${_yana_step_ref['if']:-}
	if [[ -n $_yana_step_condition ]]; then
		_yana_step_condition=$(jq -r 'if type=="array" then .[] else . end' <<<"$_yana_step_condition") || throw "Failed to parse 'if' conditions for step '${_yana_step_name}'." $ERR_DATA_FORMAT
		builtin readarray -t _yana_if_conditions <<<"$_yana_step_condition"
		for _yana_cond in "${_yana_if_conditions[@]}"; do
			_yana_expand_string "$_yana_cond" _yana_cond_value
			_rc=$?
			[[ ${_yana_cond_value,,} == true ]] && continue
			[[ -z $_yana_cond_value || $_rc -ne 0 ]] && return 1
		done
	fi

	_yana_step_condition=${_yana_step_ref['if_not']:-}
	if [[ -n $_yana_step_condition ]]; then
		_yana_step_condition=$(jq -r 'if type=="array" then .[] else . end' <<<"$_yana_step_condition") || throw "Failed to parse 'if_not' conditions for step '${_yana_step_name}'." $ERR_DATA_FORMAT
		builtin readarray -t _yana_if_conditions <<<"$_yana_step_condition"
		for _yana_cond in "${_yana_if_conditions[@]}"; do
			_yana_expand_string "$_yana_cond" _yana_cond_value
			_rc=$?
			[[ -z $_yana_cond_value || ${_yana_cond_value,,} == false ]] && continue
			[[ $_rc -eq 0 ]] && return 1
		done
	fi
}
_yana_verify_step() {
	# shellcheck disable=SC2034
	builtin local -A YANA_STEP _yana_step_args
	_yana_load_step "$@"
	if [[ -z ${YANA_STEP['verify']} ]]; then
		log skip "  - [SKIPPED] ${YANA_STEP[name]} (no verify function defined)"
		return 0
	fi
	if ! _yana_eval_conditions YANA_STEP; then
		log skip "  - [SKIPPED] ${YANA_STEP[name]} (conditions not met)"
		return 0
	fi
	_yana_resolve_args "${YANA_STEP['args']}" _yana_step_args || throw "Failed to resolve arguments for step '${YANA_STEP[name]}'." $ERR_DATA_FORMAT

	log info "  - [VERIFYING] ${YANA_STEP[name]} (checking if state is compliant)"
	builtin local _rc=0
	_yana_execute_fn 'yanaverify' "${YANA_STEP['verify']}" _yana_step_output _yana_step_args || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		log success "  - [COMPLIANT] ${YANA_STEP[name]} (state is compliant)"
		return 0
	elif [[ $_rc -eq 127 ]]; then
		log skip "  - [SKIPPED] ${YANA_STEP[name]} (verification function not found)"
		return 0
	else
		log error "  - [NON-COMPLIANT] ${YANA_STEP[name]} (state is not compliant)"
		return $_rc
	fi
}
_yana_apply_step() {
	# shellcheck disable=SC2034
	builtin local -A YANA_STEP #YANA_ARGS
	_yana_load_step "$@" YANA_STEP
	builtin local _rc=0 _yana_step_output
	if [[ -z ${YANA_STEP['apply']} ]]; then
		log skip "  - [SKIPPED] ${YANA_STEP[name]} (no apply function defined)"
		return 0
	fi
	if ! _yana_eval_conditions YANA_STEP; then
		log skip "  - [SKIPPED] ${YANA_STEP[name]} (conditions not met)"
		return 0
	fi
	builtin local -A _yana_step_args
	_yana_resolve_args "${YANA_STEP['args']}" _yana_step_args || throw "Failed to resolve arguments for step '${YANA_STEP[name]}'." $ERR_DATA_FORMAT
	if [[ -z ${YANA_STEP['verify']} ]]; then
		log skip "  - [SKIPPED] ${YANA_STEP[name]} (verify function undefined)"
	else
		log info "  - [VERIFYING] ${YANA_STEP[name]} (checking if changes are needed)"
		_yana_execute_fn 'yanaverify' "${YANA_STEP['verify']}" _yana_step_output _yana_step_args || _rc=$?
		if [[ $_rc -eq 0 ]]; then # compliant, no changes needed
			log success "  - [COMPLIANT] ${YANA_STEP[name]} (no changes needed)"
			return 0
		elif [[ $_rc -eq 1 ]]; then # non-compliant, changes needed
			log fail "  - [NON-COMPLIANT] ${YANA_STEP[name]} (changes needed)"
		elif [[ $_rc -eq 127 ]]; then # function not found
			log skip "  - [SKIPPED] ${YANA_STEP[name]} (verification function not found)"
			YANA_STEP['verify']=''
		else # argument/syntax/other errors
			log error "  - [FAILED] ${YANA_STEP[name]} (failed to verify compliance, return code: $_rc)"
			return $_rc
		fi
	fi
	log info "  - [APPLYING] ${YANA_STEP[name]} (making changes)"
	_rc=0
	_yana_execute_fn 'yanaapply' "${YANA_STEP['apply']}" _yana_step_output _yana_step_args || _rc=$?
	if [[ $_rc -eq 0 ]]; then
		log success "  - [APPLIED] ${YANA_STEP[name]} (changes applied)"
	else
		log error "  - [FAILED] ${YANA_STEP[name]} (failed to apply changes, return code: $_rc)"
		return $_rc
	fi
	[[ -z ${YANA_STEP['verify']} ]] && return 0
	log info "  - [POST-VERIFYING] ${YANA_STEP[name]} (checking if changes stuck)"
	if _yana_execute_fn 'yanaverify' "${YANA_STEP['verify']}" _yana_step_output _yana_step_args; then
		log success "  - [POST-COMPLIANT] ${YANA_STEP[name]} (changes verified)"
	else
		log error "  - [POST-NON-COMPLIANT] ${YANA_STEP[name]} (changes did not stick)"
		return 1
	fi
}
# Reads and parses the YANA spec file.
_yana_load_spec_file() {
	jq -e -r '.' "$YANA_SOURCE" >/dev/null 2>&1 || throw "Failed to parse YANA spec file '$YANA_SOURCE'. Ensure it is valid JSON." $ERR_DATA_FORMAT

	YANA_SPEC=()
	YANA_SPEC[name]=$(jq -r '.name // empty' "$YANA_SOURCE")
	YANA_SPEC[description]=$(jq -r '.description // empty' "$YANA_SOURCE")
	YANA_SPEC[version]=$(jq -r '.version // empty' "$YANA_SOURCE")
	YANA_SPEC[author]=$(jq -r '.author // empty' "$YANA_SOURCE")
	YANA_SPEC[license]=$(jq -r '.license // empty' "$YANA_SOURCE")
	YANA_REQUIRES=()
	builtin readarray -t YANA_REQUIRES < <(jq -r '(.requires // []) | .[]' "$YANA_SOURCE")
	YANA_STEPS=()
	builtin readarray -t YANA_STEPS < <(jq -r -c '.steps // [] | .[] | @base64' "$YANA_SOURCE")
	YANA_PARAMS=()
	# Extract parameters into associative array
	builtin local _yana_spec_params_raw _yana_spec_param _yana_spec_param_key _yana_spec_param_value _yana_spec_param_value_b64
	while IFS= builtin read -r _yana_spec_param; do
		[[ -n $_yana_spec_param ]] || continue
		_yana_spec_param_key="${_yana_spec_param%%:*}"
		_yana_spec_param_value=$(base64 -d <<<"${_yana_spec_param#*:}") || throw "Failed to decode base64 parameter value for key '$_yana_spec_param_key'." $ERR_DATA_FORMAT
		YANA_PARAMS["$_yana_spec_param_key"]="$_yana_spec_param_value"
	done < <(jq -r '(.params | objects) // {} | to_entries | map("\(.key):\(.value|@text|@base64)") | .[]' "$YANA_SOURCE")
	YANA_VARS=()
	# Extract variables into associative array
	builtin local _yana_spec_vars_raw _yana_spec_var _yana_spec_var_key _yana_spec_var_value _yana_spec_var_value_b64
	while IFS= builtin read -r _yana_spec_var; do
		[[ -n $_yana_spec_var ]] || continue
		_yana_spec_var_key="${_yana_spec_var%%:*}"
		_yana_spec_var_value=$(base64 -d <<<"${_yana_spec_var#*:}") || throw "Failed to decode base64 variable value for key '$_yana_spec_var_key'." $ERR_DATA_FORMAT
		YANA_VARS["$_yana_spec_var_key"]="$_yana_spec_var_value"
	done < <(jq -r '(.vars | objects) // {} | to_entries | map("\(.key):\(.value|@json|@base64)") | .[]' "$YANA_SOURCE")
}
# Outputs the version of YANA.
_yana_mode_version() { builtin echo "$YANA_VERSION"; }
# Outputs the source directory of the YANA Module based on the YANA_SOURCE variable.
_yana_source_dir() { [[ -d "$YANA_SOURCE" ]] && builtin echo "$YANA_SOURCE" || dirname "$YANA_SOURCE"; }
# Pulls and unpacks the YANA Module from the specified source (local path or URL).
_yana_mode_pull() {
	[[ -z $YANA_SOURCE ]] && throw 'No source specified' $ERR_MISUSE
	if [[ $YANA_SOURCE =~ ^https?:// ]]; then
		builtin local _yana_tmp_dir="${TMPDIR:-/tmp}/yana-$(date +%s%N)"
		mkdir -p "$_yana_tmp_dir" || throw "Failed to create temporary directory '$_yana_tmp_dir'." $ERR_GENERAL
		log info 'Downloading YANA Module from provided source'
		curl -fsSL "$YANA_SOURCE" -o "$_yana_tmp_dir/yana_module.tar.gz" || {
			[[ ${YANA_DEBUG:-false} == true ]] || rm -rf "$_yana_tmp_dir"
			throw 'Failed to download YANA Module' $ERR_GENERAL
		}
		log debug "Extracting downloaded YANA Module to temporary directory: $_yana_tmp_dir"
		tar -xzf "$_yana_tmp_dir/yana_module.tar.gz" -C "$_yana_tmp_dir" || {
			[[ ${YANA_DEBUG:-false} == true ]] || rm -rf "$_yana_tmp_dir"
			throw 'Failed to extract YANA Module from downloaded archive' $ERR_GENERAL
		}
		YANA_SOURCE="$_yana_tmp_dir"
	fi
	[[ -e $YANA_SOURCE ]] || throw "'$YANA_SOURCE': No such file or directory" $ERR_NO_INPUT
	[[ -d $YANA_SOURCE ]] && YANA_SOURCE="$YANA_SOURCE/.yana.json"
	YANA_SOURCE=$(realpath "$YANA_SOURCE") || throw "'$YANA_SOURCE': Failed to resolve real path" $ERR_GENERAL
	[[ -f $YANA_SOURCE ]] || throw "'$YANA_SOURCE': No such file" $ERR_NO_INPUT
	# Here we will validate the integrity of the YANA Module.
}
# Verifies the YANA Module from the specified source (local path or URL) without making any changes.
_yana_mode_verify() {
	[[ -z $YANA_SOURCE ]] && throw 'No source specified'
	_yana_mode_pull
	log info "Verifying YANASPEC: $YANA_SOURCE"
	builtin local -A YANA_SPEC YANA_PARAMS YANA_VARS
	builtin local -a YANA_STEPS YANA_REQUIRES
	_yana_load_spec_file
	#shellcheck disable=SC2086
	_yana_check_prerequisites "${YANA_REQUIRES[@]}"

	_yana_initialize_encryption
	builtin local _yana_step
	# Execute steps
	for _yana_step in "${YANA_STEPS[@]}"; do
		_yana_verify_step "$_yana_step" || return $?
	done
	log info "YANA Module verified successfully: $YANA_SOURCE"

}
# Applies the YANA Module from the specified source (local path or URL).
_yana_mode_apply() {
	[[ -z $YANA_SOURCE ]] && throw 'No source specified'
	_yana_mode_pull
	log info "Applying YANASPEC: $YANA_SOURCE"
	builtin local -A YANA_SPEC YANA_PARAMS YANA_VARS
	builtin local -a YANA_STEPS YANA_REQUIRES
	_yana_load_spec_file
	#shellcheck disable=SC2086
	_yana_check_prerequisites "${YANA_REQUIRES[@]}"

	_yana_initialize_encryption
	builtin local _yana_step
	# Execute steps
	for _yana_step in "${YANA_STEPS[@]}"; do
		_yana_apply_step "$_yana_step" || {
			log error "Step execution failed." $?
			return $?
		}
	done
	log info "YANA Module applied successfully: $YANA_SOURCE"
}
# Main entry point.
_yana_() {
	if [[ ${BASH_SOURCE[1]:-} != *bashdb ]]; then
		trap '_yana_cleanup_encryption' EXIT ERR
		trap '_yana_cleanup_encryption; exit 130' INT
		trap '_yana_cleanup_encryption; exit 143' TERM
	fi

	builtin local YANA_MODE="${YANA_MODE:-}" YANA_SOURCE="${YANA_SOURCE:-}" YANA_LOGFILE="${YANA_LOGFILE:-}" YANA_TRACE="${YANA_TRACE:-false}" YANA_DEBUG="${YANA_DEBUG:-false}" _yana_show_help=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
		apply | verify | pull | version) YANA_MODE="$1" ;;
		-source | --source)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -source'
			YANA_SOURCE="$1"
			;;
		-logfile | --logfile)
			builtin shift
			[[ $# -ge 1 && $1 != -* ]] || throw 'Missing value for -logfile'
			YANA_LOGFILE="$1"
			;;
		-help | --help) _yana_show_help=true ;;
		*)
			[[ $1 == -* ]] && throw "Unknown option: $1. Use -help to see available options."
			throw "Unknown mode: $1. Use -help to see available modes."
			;;
		esac
		builtin shift
	done
	# Display the title and version information
	log info "$YANA_TITLE" "Version: $YANA_VERSION" >&2
	if [[ $_yana_show_help == true ]]; then
		_yana_usage
		builtin return 0
	fi
	_yana_check_prerequisites jq base64 awk openssl
	[[ -z $YANA_MODE ]] && throw 'No mode specified. Use -help to see available modes.'
	_yana_mode_"$YANA_MODE"
}
if [[ -z ${BASH_SOURCE[1]:-} ]] || [[ ${BASH_SOURCE[1]:-} == *bashdb ]]; then
	# Proceed with the script execution only if it is executed directly or under bashdb.
	if [[ ${BASH_SOURCE[1]:-} != *bashdb ]]; then
		trap 'log fatal "An unexpected error occurred at line $LINENO in function ${FUNCNAME[0]}."' ERR
	fi
	(_yana_ "$@") || builtin exit $?
fi
