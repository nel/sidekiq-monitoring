# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'sidekiq-monitoring'
  spec.version       = '1.3.4'
  spec.authors       = ['Jeremy Carlier']
  spec.email         = ['jeremy.carlier@dimelo.com']

  spec.summary       = %q{Addons to provide a monitoring API for Sidekiq}
  spec.description   = %q{Give a state of sidekiq available queues}
  spec.homepage      = 'http://github.com/dimelo/sidekiq-monitoring'
  spec.license       = 'MIT'

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.require_paths = ['lib']
  spec.add_dependency 'sidekiq', '>= 2.12.3', '< 6.0'
  spec.add_dependency 'sinatra'
  spec.add_dependency 'multi_json'

  spec.add_development_dependency 'bundler', '~> 1.16'
end
