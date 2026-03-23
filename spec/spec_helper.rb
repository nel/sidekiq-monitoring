Bundler.require *[:default, 'test']

require 'sidekiq/api'

Dir["./lib/*.rb"].each { |f| require f  }

def stub_sidekiq_queue(name:, size: 1, latency: 0)
  instance_double(Sidekiq::Queue, name: name, size: size, latency: latency)
end

def app
  # Sinatra 4+ blocks unknown hosts by default; permit rack-test's default host
  SidekiqMonitoring.set(:host_authorization, permitted: "example.org") if SidekiqMonitoring.respond_to?(:host_authorization)
  SidekiqMonitoring.new
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end
