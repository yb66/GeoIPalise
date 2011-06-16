# encoding: utf-8

root = File.expand_path File.dirname(__FILE__)
require File.join( root , "app.rb" )

app = Rack::Builder.app do
  
  run GeoIPalie
end

run app