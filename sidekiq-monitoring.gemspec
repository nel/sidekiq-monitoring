# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require File.join(lib, 'sidekiq-monitoring', 'version')

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-monitoring'
  spec.version       = SidekiqMonitoringVersion::VERSION
  spec.authors       = ['Jeremy Carlier']
  spec.email         = ['jeremy.carlier@dimelo.com']

  spec.summary       = %q{Addons to provide a monitoring API for Sidekiq}
  spec.description   = %q{Give a state of sidekiq available queues}
  spec.homepage      = 'https://github.com/nel/sidekiq-monitoring'
  spec.license       = 'MIT'

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.require_paths = ['lib']
  spec.add_dependency 'sidekiq', '>= 5'
  spec.add_dependency 'sinatra', '>= 3.0'
end
