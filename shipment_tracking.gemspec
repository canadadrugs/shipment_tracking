# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shipment_tracking/version'

Gem::Specification.new do |spec|
  spec.name          = "shipment_tracking"
  spec.version       = ShipmentTracking::VERSION
  spec.authors       = ["Jason Barnabe"]
  spec.email         = ["jason.barnabe@canadadrugs.com"]

  spec.summary       = 'Looks up shipment tracking info.'
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rest-client", "~> 2.0.0"
  spec.add_dependency "nokogiri", ">= 1.6.0"
  spec.add_dependency "savon", "~> 2.11.0"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.5.0"
  spec.add_development_dependency "byebug"
end
