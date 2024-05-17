# frozen_string_literal: true

require 'open3'

SNAP_PACKAGES = %w[
  kita
  warzone2100
  code
  dbeaver-ce
  glimpse-editor
  spotify
  slack
  supertuxkart
  zoom-client
].freeze

# Which packages aren't installed?
snaps_installed = []
stdout, stderr, wait_thr = Open3.capture3('snap', 'list')

stdout.split("\n").drop(1).each do |row|
  package = row.split(' ').each
  snaps_installed.push(package.first)
end

to_install = SNAP_PACKAGES - snaps_installed

# Install packages
to_install&.each do |row|
  puts "Installing snap #{row}:"
  stdout, stderr, wait_thr = Open3.capture3('snap', 'install', row)
  if stderr.end_with?("--classic.\n")
    puts "#{row} needs classic confinement"
    stdout, stderr, wait_thr = Open3.capture3('snap', 'install', '--classic', row)
  end
  puts stdout
  puts stderr
end
