require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'sprockets'
require './youoweme'

map '/assets' do
  environment = Sprockets::Environment.new
  
  environment.append_path 'assets/js'
  environment.append_path 'assets/css'

  run environment
end

map '/' do
  run Sinatra::Application
end