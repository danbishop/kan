# frozen_string_literal: true

require 'base64'
require 'sinatra'
require 'logger'
require_relative 'certificate_authority'
require_relative 'net_functions'

LOG = Logger.new(STDOUT)

# Ensure local config directory exists
# CONFIG_PATH = '/etc/kan/cert'
CONFIG_PATH = './cert'
FileUtils.mkdir_p(CONFIG_PATH, mode: 0o700) unless File.directory?(CONFIG_PATH)

CA = CertificateAuthority.new

LOG.info('㊬ Kan started...')

configure do
  set :environment, :production
  set :bind, '0.0.0.0'
  # set :bind, "ssl://0.0.0.0:4792?key=#{CONFIG_PATH}/private.key&cert=#{CONFIG_PATH}/server.pem&ca=#{CONFIG_PATH}/ca.pem&verify_mode=force_peer"
  set :server, :puma
end

get '/' do
  'main'
end

# New clients hit this
get '/register' do
  content_type :json
  {
    status: CA.check_status(request.host)
  }.to_json
end

post '/register' do
  Log.info("New registration request: #{params}")
  content_type :json
  csr = CA.new_signing_request(Base64.decode64(request.body.read), request.host)
  {
    status: csr
  }.to_json
end

# Get Cert
get '/certificate' do
  send_file("#{CONFIG_PATH}/pending/#{request.host}.pem", type: 'application/octet-stream')
  LOG.info("#{request.host} collected its signed certificate")
end

get '/config' do
  content_type :json
  LOG.info("#{request.env['peer']} requested latest config.")
  {
    roles: %w[desktop],
    apt_packages: %w[package apt yes]
  }.to_json
end

get '/autoinstall.yaml' do
  @test = 'dan-test'
  erb :autoinstall
  # content_type :yaml
end
