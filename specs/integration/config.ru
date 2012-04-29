
require "bundler/setup"

Bundler.require

class App < Sinatra::Base

  get "/" do
    haml :index
  end

  get "/specs" do
    haml :specs
  end


end

run App