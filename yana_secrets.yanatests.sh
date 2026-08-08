# shellcheck shell=bash
. "${BASH_SOURCE[0]%/*}/yana.sh"

function YANAtest:secrets {
	_yana_initialize_encryption
	[[ -n $_YANA_SECRET_KEY ]] || throw 'YANA_SECRET_KEY should be initialized by _yana_initialize_encryption'
	[[ -n $_YANA_SECRET_ALGORITHM ]] || throw 'YANA_SECRET_ALGORITHM should be initialized by _yana_initialize_encryption'
	[[ -n $_YANA_SECRET_PREFIX ]] || throw 'YANA_SECRET_PREFIX should be initialized by _yana_initialize_encryption'
	[[ -n $_YANA_SECRET_SUFFIX ]] || throw 'YANA_SECRET_SUFFIX should be initialized by _yana_initialize_encryption'
	local _test_string="This is a test string."
	local _encrypted_string _encrypted_string_2 _decrypted_string
	_encrypted_string=$(yana_encrypt_string "$_test_string") || throw 'Failed to encrypt string.'
	[[ $_encrypted_string == "$_YANA_SECRET_PREFIX"*"$_YANA_SECRET_SUFFIX" ]] ||
		throw "Encrypted string should be wrapped with prefix and suffix. Expected: '$_YANA_SECRET_PREFIX'...'$_YANA_SECRET_SUFFIX', got: '$_encrypted_string'"

	[[ -n $_encrypted_string ]] || throw 'Encrypted string should not be empty.'
	_decrypted_string=$(yana_decrypt_string "$_encrypted_string") ||
		throw 'Failed to decrypt string.'
	[[ $_decrypted_string == "$_test_string" ]] || throw "Decrypted string should match original. Expected: '$_test_string', got: '$_decrypted_string'"

	_encrypted_string_2=$(yana_encrypt_string "$_test_string") || throw 'Failed to encrypt string.'
	[[ $_encrypted_string != "$_encrypted_string_2" ]] || throw 'Encrypted strings should be different for the same input.'
	[[ $_encrypted_string_2 == "$_YANA_SECRET_PREFIX"*"$_YANA_SECRET_SUFFIX" ]] ||
		throw "Encrypted string should be wrapped with prefix and suffix. Expected: '$_YANA_SECRET_PREFIX'...'$_YANA_SECRET_SUFFIX', got: '$_encrypted_string_2'"

	_decrypted_string=$(yana_decrypt_string "$_encrypted_string_2") ||
		throw 'Failed to decrypt string.'
	[[ $_decrypted_string == "$_test_string" ]] || throw "Decrypted string should match original. Expected: '$_test_string', got: '$_decrypted_string'"

	_malformed_string='<yanasecret:0102030405060708091a1b1c1d1e1f0102030405060708091a1b1c1d1e10102030405060708091a1b1c1d1e1f0102030405060708091a1b1c1d1e10102030405060708091a1b1c1d1e1f0102030405060708091a1b1c1d1e1fqwerty>'
	_decrypted_string=$(yana_decrypt_string "$_malformed_string") || throw 'Failed to decrypt string.'
	[[ $_decrypted_string == "$_malformed_string" ]] || throw "Decrypted malformed string should match original. Got: '$_decrypted_string'"

	_decrypted_string=$(
		yana_decrypt_string \
			"hello $_encrypted_string ${_encrypted_string}_<yanasecret:${_encrypted_string}>-$_malformed_string"
	) || throw 'Failed to decrypt string.'
	[[ $_decrypted_string == "hello ${_test_string} ${_test_string}_<yanasecret:${_test_string}>-$_malformed_string" ]] ||
		throw "Decrypted multiple encrypted string entries should match original. Got: '$_decrypted_string'"

	_yana_cleanup_encryption
	[[ -z ${_YANA_SECRET_KEY+x} ]] || throw '_YANA_SECRET_KEY should be unset after cleanup.'
}
