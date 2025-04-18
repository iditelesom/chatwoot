require 'openssl'

class DeterministicEncryptor
  def initialize(deterministic_key = nil)
    deterministic_key ||= Rails.application.config.active_record.encryption.deterministic_key
    if deterministic_key.nil?
      raise ArgumentError,
            "One or more encryption keys are not set or not loaded. " \
            "Check your Rails configuration and environment variables " \
            "for PRIMARY_KEY, DETERMINISTIC_KEY, and KEY_DERIVATION_SALT. " \
            "Refer to https://guides.rubyonrails.org/active_record_encryption.html for more details."
    end
    @key = OpenSSL::Digest::SHA256.digest(deterministic_key)
  end

  def encrypt(plain_text)
    cipher = OpenSSL::Cipher::AES256.new(:ECB)
    cipher.encrypt
    cipher.key = @key
    encrypted = cipher.update(plain_text) + cipher.final
    encrypted.unpack1('H*')
  end

  def decrypt(encrypted_text)
    encrypted_text = [encrypted_text].pack('H*') # Convert hex to binary
    cipher = OpenSSL::Cipher::AES256.new(:ECB)
    cipher.decrypt
    cipher.key = @key
    cipher.update(encrypted_text) + cipher.final
  end
end

# Usage example
encryptor = DeterministicEncryptor.new

plain_text = 'source_id_value'
encrypted_text = encryptor.encrypt(plain_text)
puts "Encrypted text: #{encrypted_text}"

decrypted_text = encryptor.decrypt(encrypted_text)
puts "Decrypted text: #{decrypted_text}"
