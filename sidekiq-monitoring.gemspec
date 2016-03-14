Gem::Specification.new do |gem|
  gem.version            = File.read('VERSION').chomp
  gem.date               = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name               = 'sidekiq-monitoring'
  gem.license            = 'MIT'
  gem.authors            = ['Jeremy Carlier']
  gem.summary            = 'Addons to provide a monitoring API for Sidekiq'
  gem.description        = 'Give a state of sidekiq available queues'
  gem.email              = 'jeremy.carlier@dimelo.com'

  gem.platform           = Gem::Platform::RUBY
  gem.files              = %w(README.md VERSION) + Dir.glob('lib/*.rb')
  gem.bindir             = %q()
  gem.executables        = %w()
  gem.require_paths      = %w(lib)
  gem.extensions         = %w()
  gem.test_files         = %w()
  gem.has_rdoc           = false
  gem.homepage    = 'http://github.com/dimelo/sidekiq-monitoring'

  gem.required_ruby_version              = '>= 1.9.2'
  gem.requirements                       = []
  gem.add_runtime_dependency             'sinatra', ["~>1.3"]
  gem.add_runtime_dependency             'multi_json'
  gem.add_development_dependency         'rack-test'
  gem.add_development_dependency         'rspec', ['~>2']
  gem.add_development_dependency         'sidekiq', ["~>3.1"]
  gem.post_install_message               = nil
end
