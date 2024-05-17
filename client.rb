# frozen_string_literal: true

require 'faraday'
require_relative 'colours'
require 'socket'
require 'json'
require 'openssl'
require 'logger'

LOG = Logger.new(STDOUT)

puts "Running on: #{Socket.gethostname}"

# Running as root?
unless Process.uid.zero?
  warn('Error: You must run kan with root privileges via sudo')
  exit 1
end

# Ensure local config directory exists
CONFIG_PATH = '/etc/kan-client/cert'
FileUtils.mkdir_p("#{CONFIG_PATH}/ca", mode: 0o600) unless File.directory?("#{CONFIG_PATH}/ca")

# Check that CA certificate exists, if not, start setup
unless File.exist?("#{CONFIG_PATH}/ca/cert.pem")
  require_relative 'setup'
  Setup.new.first_time_setup
end

#vvvvvvv move this into a module or class or something vvvvvvvvvvvv
# Check that client certificate exists, if not...
unless File.exist?("#{CONFIG_PATH}/cert.pem")
  # Is there an active csr, create one if not
  unless File.exist?("#{CONFIG_PATH}/cert.csr")
    require_relative 'csr'
    Log.info('Creating certificate signing request...')
    CSR.new
  end

  #############################################
  # Register CSR with server
  #############################################
  ssl_options = {
    verify: false
  }

  begin
    require 'base64'
    conn = Faraday.new(url: 'https://kan.danbishop.org:4792/', ssl: ssl_options)
    # Get the current registration status from the server
    status = JSON.parse(conn.get('/register').body)['status']
    puts "Current registration status: #{status}"
    case status
    when 'not_registered'
      request = conn.post(
        '/register',
        Base64.encode64(File.read("#{CONFIG_PATH}/cert.csr")),
        'Content-Type' => 'text/plain'
      ).body
      p request
      LOG.info('Sent CSR to the server.')
      exit 0
    when 'cert_ready'
      puts 'Certificate has been accepted and signed. Retrieving...'
      cert = conn.get('/certificate').body
      puts 'Installing...'
      File.open("#{CONFIG_PATH}/cert.pem", 'wb') { |file| file.write(cert) }
      LOG.info('Installed new signed certificate from the server.')
      puts 'Installed'
    when 'pending'
      puts "Certificate hasn't been accepted by the server yet."
      exit 0
    end
  rescue StandardError => e
    warn "Can't register with the server..."
    p e
    exit 1
  end
  ###############################################
end
#^^^^^^^ move this into a module or class or something ^^^^^^^^

puts 'Client certificate exists...'

ssl_options = {
  verify: false
  # client_cert: OpenSSL::X509::Certificate.new(File.read("#{CONFIG_PATH}/cert.pem")),
  # client_key: OpenSSL::PKey::RSA.new(File.read("#{CONFIG_PATH}/private.key")),
  # ca_file: '/etc/kan-client/cert/ca/cert.pem'
}

begin
  conn = Faraday.new(url: 'https://kan.danbishop.org:4792/', ssl: ssl_options)
  # conn = Faraday.new(url: 'https://localhost:4792/')
  p conn.get('/config').body
rescue Faraday::SSLError => e
  warn 'Server certificate error. Refusing to connect.'
  warn 'If you want to connect to a new server remove the cert and key'
  warn "stored at #{CONFIG_PATH}/ca"
  p e
  exit 1
end

# require_relative 'apt'
# require_relative 'snap'
