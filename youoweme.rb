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

# ----------------------------------------
# It's Hassel Time!
# ----------------------------------------

get '/' do
  erb (authenticated? ? :index : :login), layout: !authenticated?.nil?
end

post '/prompt' do
  redirect '/' unless authenticated?

  # Grab the form data and throw it into the database, alongside the currently
  # authenticated user's public key and access token
  @p = Prompt.new params[:prompt]
  @p.stripe_publishable_key = session[:stripe_publishable_key]
  @p.stripe_access_token = session[:access_token]
  @p.token = rand(36**8).to_s(36)
  @p.save

  # Send out the email, yo
  Pony.mail to: @p.their_email,
            from: @p.your_email,
            subject: "You owe #{@p.your_name}",
            html_body: erb(:email, layout: false)

  redirect to '/success'
end

get '/pay/:token' do
  @p = Prompt.first token: params[:token]
  raise Sinatra::NotFound unless @p
  @title = "You Owe #{@p.your_name}"

  erb :pay
end

get('/success') { erb :success }
get('/success/paid') { erb :success_paid }

# ----------------------------------------
# Stripe Processing
# ----------------------------------------

post '/pay/:token' do
  @p = Prompt.first token: params[:token]
  @amount = @p.amount * 100

  Stripe::Charge.create(
    :amount      => @amount,
    :card        => params[:stripeToken],
    :description => 'Sinatra Charge',
    :currency    => 'usd'
  )

  # Clear out the access token and public key...
  # don't want to hang onto them any longer then we have to!
  @p.stripe_publishable_key = nil
  @p.stripe_access_token = nil
  @p.save

  redirect to '/success/paid'
end

error Stripe::CardError do
  env['sinatra.error'].message
end

# ----------------------------------------
# oAuth Framework
# ----------------------------------------

# We're being asked to log in with Stripe, so redirect away
post '/login' do
  redirect @client.auth_code.authorize_url scope: 'read_write'
end

get '/logout' do
  session[:access_token] = session[:stripe_publishable_key] = session[:account_email] = nil
  redirect to '/'
end

# The user has logged in. Get the response code, trade it for an access
# token, store 'em and redirect back to the main page to cause some mayhem
get '/callback' do
  redirect to '/' if params[:error]
  @access_token = @client.auth_code.get_token params[:code], 
    :headers => {'Authorization' => "Bearer #{ENV['STRIPE_SECRET']}"}
  
  session[:access_token] = @access_token.token
  session[:stripe_publishable_key] = @access_token.params["stripe_publishable_key"]
  Stripe.api_key = @access_token.token
  session[:account_email] = Stripe::Account.retrieve.email

  redirect to '/'
end

# Before each request, establish the session and get the oAuth client,
# as well as set up Stripe and such.
before do
  session[:oauth] ||= {}

  @client = OAuth2::Client.new(ENV['STRIPE_KEY'], ENV['STRIPE_SECRET'], 
                               :site => 'https://connect.stripe.com')

  if session[:access_token]
    Stripe.api_key = session[:access_token]
  end

  # Some small syntax sugar to use in other methods
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

  # The following are getters and setters for the two encrypted user access
  # tokens. They're messy, I know. Due to the way Ruby's super works - and my
  # sub-standard knowledge of DataMapper - I can't DRY this up particularly
  # well, so I'm leaving it like this... for now...

  def stripe_publishable_key
    @stripe_pk ||= super ? Encryptor.decrypt(super, :key => ENV['STRIPE_SECRET']) : nil
  end

  def stripe_publishable_key= new_str
    if new_str
      super Encryptor.encrypt(new_str, :key => ENV['STRIPE_SECRET'])
    else
      super
    end
  end

  def stripe_access_token
    @stripe_at ||= super ? Encryptor.decrypt(super, :key => ENV['STRIPE_SECRET']) : nil
  end

  def stripe_access_token= new_str
    if new_str
      super Encryptor.encrypt(new_str, :key => ENV['STRIPE_SECRET'])
    else
      super
    end
  end
end

# ----------------------------------------
# DB Setup
# ----------------------------------------

# Set up DataMapper, finalize the models, get the tables synced!
DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'])
DataMapper.finalize
DataMapper.auto_upgrade!

# Configure Pony for emails
if ENV['RACK_ENV'] == 'production'
  Pony.options = {
    :via => :smtp,
    :via_options => {
      :address => 'smtp.sendgrid.net',
      :port => '587',
      :domain => 'heroku.com',
      :user_name => ENV['SENDGRID_USERNAME'],
      :password => ENV['SENDGRID_PASSWORD'],
      :authentication => :plain,
      :enable_starttls_auto => true
    }
  }
end