source 'https://rubygems.org'
gemspec

if ENV['SIDEKIQ_VERSION'] == 'edge'
  gem 'sidekiq', github: 'sidekiq/sidekiq'
elsif ENV['SIDEKIQ_VERSION']
  gem 'sidekiq', "~> #{ENV['SIDEKIQ_VERSION']}.0"
end

if ENV['SINATRA_VERSION'] == 'edge'
  gem 'sinatra', github: 'sinatra/sinatra'
elsif ENV['SINATRA_VERSION']
  gem 'sinatra', "~> #{ENV['SINATRA_VERSION']}.0"
end

group :test do
  gem 'rack-test'
  gem 'rspec'
end
