. "$PSScriptRoot/yana.ps1"

function YANAtest:secrets() {
	_yana_initialize_encryption
	if ($null -eq $_YANA_SECRET_PROVIDER) {
		throw 'YANA_SECRET_PROVIDER should be initialized by _yana_initialize_encryption'
	}
	if ([string]::IsNullOrEmpty($_YANA_SECRET_PROVIDER.Key)) {
		throw 'YANA_SECRET_PROVIDER.Key should be initialized by _yana_initialize_encryption'
	}
	if ([string]::IsNullOrEmpty($_YANA_SECRET_PREFIX)) {
		throw 'YANA_SECRET_PREFIX should be initialized by _yana_initialize_encryption'
	}
	if ([string]::IsNullOrEmpty($_YANA_SECRET_SUFFIX)) {
		throw 'YANA_SECRET_SUFFIX should be initialized by _yana_initialize_encryption'
	}

	$_test_string = 'This is a test string.'
	$_encrypted_string = yana_encrypt_string $_test_string
	if (-not $_encrypted_string.StartsWith($_YANA_SECRET_PREFIX) -or -not $_encrypted_string.EndsWith($_YANA_SECRET_SUFFIX)) {
		throw "Encrypted string should be wrapped with prefix and suffix. Expected: '$_YANA_SECRET_PREFIX'...'$_YANA_SECRET_SUFFIX', got: '$_encrypted_string'"
	}
	if ([string]::IsNullOrEmpty($_encrypted_string)) {
		throw 'Encrypted string should not be empty.'
	}

	$_decrypted_string = yana_decrypt_string $_encrypted_string
	if ($_decrypted_string -ne $_test_string) {
		throw "Decrypted string should match original. Expected: '$_test_string', got: '$_decrypted_string'"
	}

	$_encrypted_string_2 = yana_encrypt_string $_test_string
	if ($_encrypted_string -eq $_encrypted_string_2) {
		throw 'Encrypted strings should be different for the same input.'
	}
	if (-not ($_encrypted_string_2.StartsWith($_YANA_SECRET_PREFIX) -and $_encrypted_string_2.EndsWith($_YANA_SECRET_SUFFIX))) {
		throw "Encrypted string should be wrapped with prefix and suffix. Expected: '$_YANA_SECRET_PREFIX'...'$_YANA_SECRET_SUFFIX', got: '$_encrypted_string_2'"
	}

	$_decrypted_string = yana_decrypt_string $_encrypted_string_2
	if ($_decrypted_string -ne $_test_string) {
		throw "Decrypted string should match original. Expected: '$_test_string', got: '$_decrypted_string'"
	}

	$_malformed_string = $_encrypted_string.Substring(0, $_encrypted_string.Length - 5) + '0000>'
	$decrypted_string = yana_decrypt_string $_malformed_string
	if ($decrypted_string -ne $_malformed_string) { throw "Decrypted malformed string should match original. Got: '$decrypted_string'"	}

	$_malformed_string1 = [string]::Concat('<yanasecret:', '0' * 10, '>')
	$_malformed_string2 = [string]::Concat('<yanasecret:', '0' * 100, '>')

	$decrypted_string = yana_decrypt_string $_malformed_string1
	if ($decrypted_string -ne $_malformed_string1) {
		throw "Decrypted malformed string should match original. Got: '$decrypted_string'"
	}
	$decrypted_string = yana_decrypt_string $_malformed_string2
	if ($decrypted_string -ne $_malformed_string2) {
		throw "Decrypted malformed string should match original. Got: '$decrypted_string'"
	}

	$_decrypted_string = yana_decrypt_string "hello $_encrypted_string ${_encrypted_string}_<yanasecret:${_encrypted_string}>-${_malformed_string1}"
	if ($_decrypted_string -ne "hello ${_test_string} ${_test_string}_<yanasecret:${_test_string}>-${_malformed_string1}") {
		throw "Decrypted multiple encrypted string entries should match original. Got: '$_decrypted_string'"
	}

	_yana_cleanup_encryption
	if ($null -ne $_YANA_SECRET_PROVIDER) { throw 'YANA_SECRET_PROVIDER should be cleaned up by _yana_cleanup_encryption'	}
}
