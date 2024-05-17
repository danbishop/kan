# frozen_string_literal: true

require_relative 'csr'

class Setup
  def first_time_setup
    cert = server_cert
    puts "\nFirst Run Setup".bold
    puts "There's no server certificate present yet, let's connect to your server."
    puts "Check the server fingerprint below carefully to ensure you\'re connecting to the correct server:\n\n"
    # Display fingerprint
    puts OpenSSL::Digest::SHA256.new(cert.to_pem).to_s.red
    puts "\nWarning about connecting to a bad server.".bold.blink
    puts 'Is this correct? [y/N]'
    continue_setup(gets.chomp, cert)
  end

  private

  def continue_setup(input, cert)
    quit_setup unless yes?(input)
    # Save server cert and public key
    save_server_cert(cert)
    puts 'Ok, all done. You have accepted the server certificate.'.green
    CSR.new
    puts 'Now logon to the server and accept this client.'
    exit 0
  end

  def quit_setup
    puts 'Ok, the server certificate has been rejected.'.red
    puts "You can rerun setup whenever you're ready."
    exit 0
  end

  def yes?(answer)
    true if answer.downcase == 'y'
  end

  def server_cert
    # Get certificate and fingerprint it, store if happy
    # require 'net/http'
    # cert = Net::HTTP.start(
    #   'dan-desktop.danbishop.org',
    #   '4792',
    #   use_ssl: true,
    #   verify_mode: OpenSSL::SSL::VERIFY_NONE,
    #   &:peer_cert
    # )
    # OpenSSL::X509::Certificate.new(cert)

    # Need to get CA cert now, not server cert

    # For now just copy it, but this will need to be delivered
    OpenSSL::X509::Certificate.new(File.read('/etc/kan/cert/ca.pem'))
  end

  def save_server_cert(cert)
    # Store certificate
    File.open("#{CONFIG_PATH}/ca/cert.pem", 'w') do |f|
      f.write cert.to_pem
    end
    # Store public key
    File.open("#{CONFIG_PATH}/ca/public.key", 'w') do |f|
      f.write cert.public_key.to_pem
    end
  end
end
