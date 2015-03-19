require 'bundler'
Bundler.require

require 'opal-rspec'
Opal.append_path File.expand_path('../spec', __FILE__)

run Opal::Server.new { |s|
  s.main = 'opal/rspec/sprockets_runner'
  s.append_path 'spec'
  s.debug = false
  s.index_path = 'spec/index.html.erb'
}

