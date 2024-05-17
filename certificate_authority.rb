# frozen_string_literal: true

require 'socket'
require 'openssl'

class CertificateAuthority
  def initialize
    @subject = "/CN=#{Socket.gethostname}"
    @cert = "#{CONFIG_PATH}/ca.pem"
    @pub_key = "#{CONFIG_PATH}/ca-public.key"
    @priv_key = "#{CONFIG_PATH}/ca-private.key"
    # Check that root ca certificate exists, if not, create one
    @ca = check_root_cert
    # Check that server certificate exists, if not, create one
    check_server_cert
    # Ensure a pending directory exists for signing requests
    FileUtils.mkdir_p("#{CONFIG_PATH}/pending", mode: 0o700) unless File.directory?("#{CONFIG_PATH}/pending")
  end

  def new_signing_request(request, host)
    # Do we already have a request from this host?
    return 'pending' if File.exist?("#{CONFIG_PATH}/pending/#{host}.csr")

    csr = OpenSSL::X509::Request.new(request)
    check_hostname(csr, host)

    File.open("#{CONFIG_PATH}/pending/#{host}.csr", 'w') do |f|
      f.write csr
    end
    'request_accepted'
  end

  def sign_client_certificate(csr_path)
    csr = OpenSSL::X509::Request.new(File.read(csr_path))
    # Check signature
    raise 'CSR can not be verified' unless csr.verify csr.public_key

    host = csr_host(csr)

    File.open("#{CONFIG_PATH}/pending/#{host}.pem", 'w') do |f|
      f.write new_client_cert(csr)
    end
    # Remove pending CSR
    File.delete(csr_path)
  end

  def check_status(host)
    return 'pending' if File.exist?("#{CONFIG_PATH}/pending/#{host}.csr")
    return 'cert_ready' if File.exist?("#{CONFIG_PATH}/pending/#{host}.pem")

    'not_registered'
  end

  def list_pending
    pending = []
    Dir["#{CONFIG_PATH}/pending/*.csr"].each do |row|
      csr = OpenSSL::X509::Request.new(File.read(row))
      pending.push({
                     host: csr_host(csr),
                     time: File.ctime(row),
                     file: File.expand_path(row)
                   })
    end
    pending
  end

  private

  def new_ca_cert
    key = new_key

    cert = OpenSSL::X509::Certificate.new
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse(@subject)
    cert.not_before = Time.now
    cert.not_after = Time.now + 365 * 24 * 60 * 60
    cert.public_key = key.public_key
    cert.serial = Random.rand(65_534)
    cert.version = 2

    # Break out into a new function
    #######################################################################
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.extensions = [
      ef.create_extension('basicConstraints', 'CA:TRUE', true),
      ef.create_extension('subjectKeyIdentifier', 'hash'),
      ef.create_extension('keyUsage', 'cRLSign,keyCertSign', true)
    ]
    cert.add_extension ef.create_extension('authorityKeyIdentifier',
                                           'keyid:always,issuer:always')
    #######################################################################

    cert.sign key, OpenSSL::Digest::SHA256.new

    save_cert(key, cert)
    cert
  end

  def new_client_cert(csr)
    csr_cert = OpenSSL::X509::Certificate.new
    csr_cert.serial = Random.rand(65_534)
    csr_cert.version = 2
    csr_cert.not_before = Time.now
    csr_cert.not_after = Time.now + 600
    csr_cert.subject = csr.subject
    csr_cert.public_key = csr.public_key
    csr_cert.issuer = OpenSSL::X509::Name.parse(@subject)
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = csr_cert
    ef.issuer_certificate = @ca
    csr_cert.extensions = [
      ef.create_extension('basicConstraints', 'CA:FALSE', true),
      ef.create_extension('subjectKeyIdentifier', 'hash'),
      ef.create_extension('extendedKeyUsage', 'serverAuth, clientAuth, codeSigning, emailProtection', true)
    ]
    csr_cert.add_extension ef.create_extension('authorityKeyIdentifier',
                                               'keyid:always,issuer:always')
    csr_cert.sign OpenSSL::PKey::RSA.new(File.read(@priv_key)), OpenSSL::Digest::SHA256.new
    csr_cert.to_pem
  end

  def new_server_cert(csr)
    csr_cert = OpenSSL::X509::Certificate.new
    csr_cert.serial = Random.rand(65_534)
    csr_cert.version = 2
    csr_cert.not_before = Time.now
    csr_cert.not_after = Time.now + 600
    csr_cert.subject = csr.subject
    csr_cert.public_key = csr.public_key
    csr_cert.issuer = OpenSSL::X509::Name.parse(@subject)
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = csr_cert
    ef.issuer_certificate = @ca
    csr_cert.extensions = [
      ef.create_extension('basicConstraints', 'CA:FALSE', true),
      ef.create_extension('subjectKeyIdentifier', 'hash'),
      ef.create_extension('extendedKeyUsage', 'serverAuth, emailProtection', true)
    ]
    csr_cert.add_extension ef.create_extension('authorityKeyIdentifier',
                                               'keyid:always,issuer:always')
    csr_cert.sign OpenSSL::PKey::RSA.new(File.read(@priv_key)), OpenSSL::Digest::SHA256.new
    csr_cert.to_pem
  end

  def new_key
    OpenSSL::PKey::RSA.new(4096)
  end

  def set_permissions
    files = [@cert, @pub_key, @priv_key]
    File.chmod(0o600, *files)
    # FileUtils.chown('root', 'root', *files)
  end

  def save_cert(key, cert)
    File.open(@priv_key, 'w') do |f|
      f.write key.to_pem
    end

    File.open(@pub_key, 'w') do |f|
      f.write key.public_key.to_pem
    end

    File.open(@cert, 'w') do |f|
      f.write cert.to_pem
    end

    set_permissions
  end

  def csr_host(csr)
    csr.subject.to_s(OpenSSL::X509::Name::RFC2253).delete!('CN=')
  end

  def check_hostname(csr, host)
    requestor = OpenSSL::X509::Name.parse("/CN=#{host}")
    unless csr.subject.eql?(requestor)
      raise "Hostname of requestor (#{requestor}) does not match the hostname in the CSR (#{csr.subject})"
    end
  end

  def check_root_cert
    unless File.exist?("#{CONFIG_PATH}/ca.pem")
      puts 'Creating CA certificate...'
      return new_ca_cert
    end
    puts 'Found CA cert.'
    OpenSSL::X509::Certificate.new(File.read("#{CONFIG_PATH}/ca.pem"))
  end

  def check_server_cert
    unless File.exist?("#{CONFIG_PATH}/server.pem")
      require_relative 'csr'
      puts 'Creating server certificate...'
      # Create CSR
      CSR.new(csr_file: "#{CONFIG_PATH}/server.csr")
      csr = OpenSSL::X509::Request.new(File.read("#{CONFIG_PATH}/server.csr"))
      File.open("#{CONFIG_PATH}/server.pem", 'w') do |f|
        f.write new_server_cert(csr)
      end
    end
  end
end
