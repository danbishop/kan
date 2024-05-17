# frozen_string_literal: true

require 'open3'

APT_PACKAGES = %w[
  git
  ruby
  ruby-bundler
  inkscape
  lm-sensors
  steam
  sssd
  ssh
  zlib1g-dev
].freeze

# Which packages aren't installed?
_stdout, stderr, _thread = Open3.capture3('dpkg', '-s', *APT_PACKAGES)

not_installed = stderr

to_install = []
unless not_installed.nil?
  APT_PACKAGES.each do |row|
    to_install.push(row) if not_installed.match(/'#{row}'/)
  end
end

# Install packages
unless to_install.empty?
  puts 'Refreshing package sources:'
  `sudo aptdcon --refresh`
  to_install.each do |row|
    puts "Installing #{row}:"
    `sudo yes | aptdcon --hide-terminal --install "#{row}"`
  end
end
