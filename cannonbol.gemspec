# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cannonbol/version'

Gem::Specification.new do |spec|
  spec.name          = "cannonbol"
  spec.version       = Cannonbol::VERSION
  spec.authors       = ["catmando"]
  spec.email         = ["mitch@catprint.com"]

  if spec.respond_to?(:metadata)
  end

  spec.summary       = %q{Cannonbol is a ruby dsl for patten matching based on SNOBOL4 and SPITBOL}
  spec.description   = %q{
Makes complex patterns easier to read and write!
Combine regexes, plain strings and powerful new primitive match functions!
Makes capturing match results easy!
Allows recursive patterns!
Complete SNOBOL4 + SPITBOL extensions!
Based on the well documented, proven SNOBOL4 language!
Simple syntax looks great alongside ruby!
                       }
  spec.homepage      = "https://github.com/catprintlabs/cannonbol"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "opal-rspec"
  spec.add_development_dependency "opal"
  spec.required_ruby_version = '~> 1.9'
end
