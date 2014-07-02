Gem::Specification.new do |gem|
  gem.version            = File.read('VERSION').chomp
  gem.date               = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name               = 'nagios-monitoring_sidekiq'
  gem.authors            = ['Jérémy Carlier']
  gem.summary            = 'Sidekiq monitoring for Nagios'
  gem.description        = 'Give a state of all sidekiq available queues'
  gem.email              = 'jeremy.carlier@dimelo.com'

  gem.platform           = Gem::Platform::RUBY
  gem.files              = %w(README.md VERSION) + Dir.glob('lib/**/*.rb')
  gem.bindir             = %q()
  gem.executables        = %w()
  gem.require_paths      = %w(lib)
  gem.extensions         = %w()
  gem.test_files         = %w()
  gem.has_rdoc           = false
  #gem.homepage    = 'http://github.com/ambethia/rack-google_analytics'

  gem.required_ruby_version              = '>= 1.9.2'
  gem.requirements                       = []
  gem.add_runtime_dependency             'sinatra', ["~>1.4.0"]
  gem.add_runtime_dependency             'sinatra-contrib', ["~>1.4.2"]
  gem.add_runtime_dependency             'activesupport'
  gem.add_runtime_dependency             'activemodel'
  gem.add_development_dependency         'rspec'
  gem.add_development_dependency         'sidekiq', ["~>3.1.0"]
  gem.post_install_message               = nil
end
