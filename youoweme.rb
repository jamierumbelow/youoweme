# You Owe Me!
#
# (c)2012 Jamie Rumbelow
# https://github.com/jamierumbelow/youoweme

require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'oauth2'
require 'stripe'
require 'data_mapper'
require 'dm-migrations'
require 'pony'
require 'encryptor'

enable :sessions

get '/' do
  if authenticated?
    erb :index
  else
    erb :login
  end
end

post '/prompt' do
  redirect '/' unless authenticated?

  @p = Prompt.new params[:prompt]
  
  @p.stripe_publishable_key = Encryptor.encrypt(session[:stripe_publishable_key], :key => ENV['STRIPE_SECRET'])
  @p.stripe_access_token = Encryptor.encrypt(session[:access_token], :key => ENV['STRIPE_SECRET'])
  @p.token = rand(36**8).to_s(36)

  @p.save

  Pony.mail to: @p.their_email,
            from: @p.your_email,
            subject: "You owe #{@p.your_name}",
            html_body: erb(:email, layout: false)

  redirect to '/success'
end

get '/pay/:token' do
  @p = Prompt.first token: params[:token]
  raise Sinatra::NotFound unless @p

  

  erb :pay
end

# ----------------------------------------
# oAuth Framework
# ----------------------------------------

post '/login' do
  redirect @client.auth_code.authorize_url
end

get '/callback' do
  @access_token = @client.auth_code.get_token params[:code], 
    :headers => {'Authorization' => "Bearer #{ENV['STRIPE_API_SECRET']}"}
  
  session[:access_token] = @access_token.token
  session[:stripe_publishable_key] = @access_token.params["stripe_publishable_key"]

  redirect to('/')
end

before do
  session[:oauth] ||= {}

  @client = OAuth2::Client.new(ENV['STRIPE_KEY'], ENV['STRIPE_SECRET'], 
                               :site => 'https://connect.stripe.com')

  if session[:access_token]
    Stripe.api_key = session[:access_token]
  end

  def authenticated?; session[:access_token]; end
end

# ----------------------------------------
# Models
# ----------------------------------------

class Prompt
  include DataMapper::Resource

  property :id,                     Serial
  property :token,                  String
  property :stripe_publishable_key, Binary
  property :stripe_access_token,    Binary

  %w{name email}.each do |w|
    property :"their_#{w}", String
    property :"your_#{w}", String
  end
  property :amount, Integer
  property :date, Date
  property :what, String

  property :created_at, DateTime

  before :create do
    created_at = DateTime.now
  end
end

# ----------------------------------------
# DB Setup
# ----------------------------------------

before do
  DataMapper::Logger.new($stdout, :debug)
  DataMapper.setup(:default, ENV['DATABASE_URL'])
  DataMapper.finalize
  DataMapper.auto_upgrade!
end