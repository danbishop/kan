# frozen_string_literal: true

require_relative 'colours'
require_relative 'certificate_authority'

# Ensure local config directory exists
CONFIG_PATH = '/etc/kan/cert'
FileUtils.mkdir_p(CONFIG_PATH, mode: 0o600) unless File.directory?(CONFIG_PATH)

CA = CertificateAuthority.new

pending = CA.list_pending

if pending.empty?
  puts 'There are no pending certificate requests.'.green
else
  puts 'Pending Keys:'.green.underline
  pending.each_with_index do |row, index|
    puts "#{index + 1}) #{row[:host]}"
  end

  puts '----------------------------------'
  puts "Enter 'a' to accept all clients, or provide a space separated list of numbers to accept just those clients:"

  command = gets
  case command.chomp.downcase
  when 'a'
    puts 'accept all'
    pending.each do |row|
      CA.sign_client_certificate(row[:file])
    end
  else
    puts 'ok thanks bye'
  end
end
