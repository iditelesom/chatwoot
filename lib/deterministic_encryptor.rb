require 'openssl'

class DeterministicEncryptor
  def initialize(secret)
    @key = OpenSSL::Digest::SHA256.digest(secret)
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
secret = Rails.application.credentials.dig(:encryption, :deterministic_key)
encryptor = DeterministicEncryptor.new(secret)

plain_text = 'source_id_value'
encrypted_text = encryptor.encrypt(plain_text)
puts "Encrypted text: #{encrypted_text}"

decrypted_text = encryptor.decrypt(encrypted_text)
puts "Decrypted text: #{decrypted_text}"
