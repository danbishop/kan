# frozen_string_literal: true

require 'openssl'
require 'socket'

class CSR
  def initialize(csr_file: "#{CONFIG_PATH}/cert.csr")
    LOG.info("Creating new CSR for /CN=#{Socket.gethostname}")
    @subject = "/CN=#{Socket.gethostname}"
    @private_key = OpenSSL::PKey::RSA.new(4096)
    @digest = OpenSSL::Digest::SHA256.new
    @request = OpenSSL::X509::Request.new
    @csr_file = csr_file
    @private_key_file = "#{CONFIG_PATH}/private.key"
    build_request
  end

  private

  def build_request
    @request.subject = OpenSSL::X509::Name.parse(@subject)
    @request.public_key = @private_key.public_key
    @request.sign(@private_key, @digest)
    save_csr
  end

  def save_csr
    File.open(@private_key_file, 'w') do |f|
      f.write @private_key.to_pem
    end

    File.open(@csr_file, 'w') do |f|
      f.write @request.to_pem
    end
    set_permissions
    LOG.info("CSR saved and permissions set: #{@csr_file}")
  end

  def set_permissions
    files = [@csr_file, @private_key_file]
    File.chmod(0o600, *files)
    # FileUtils.chown('root', 'root', *files)
  end
end
