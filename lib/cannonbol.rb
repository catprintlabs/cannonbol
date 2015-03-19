require_relative 'cannonbol/cannonbol'
require_relative 'cannonbol/version'
unless RUBY_ENGINE == 'opal'
  begin 
    require 'opal'
    Opal.append_path File.expand_path('..', __FILE__).untaint
  rescue LoadError
  end
end