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
require 'yaml'

enable :sessions

get '/' do
  if authenticated?
    erb :index
  else
    erb :login
  end
end

post '/prompt' do
  prompt = params[:prompt]
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
# DB Setup
# ----------------------------------------

before do
  DataMapper.setup(:default, ENV['DATABASE_URL'])
end