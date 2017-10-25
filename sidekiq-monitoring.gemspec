# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sidekiq-monitoring'

Gem::Specification.new do |spec|
  spec.name          = "sidekiq-monitoring"
  spec.version       = SidekiqMonitoring::VERSION
  spec.authors       = ["Jeremy Carlier"]
  spec.email         = ["jeremy.carlier@dimelo.com"]

  spec.summary       = %q{Addons to provide a monitoring API for Sidekiq}
  spec.description   = %q{Give a state of sidekiq available queues}
  spec.homepage      = "http://github.com/dimelo/sidekiq-monitoring"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "sinatra", ">= 1.3"
  spec.add_runtime_dependency "multi_json"

  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "sidekiq", "~> 3.1"
end
