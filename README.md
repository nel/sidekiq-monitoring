[![Build Status](https://travis-ci.org/dimelo/sidekiq-monitoring.svg?branch=master)](https://travis-ci.org/dimelo/sidekiq-monitoring)

# Rails 3, 4 and 5

Add `sinatra` (and `sprockets` if you are on Rails 3.0) to your Gemfile

```ruby
# if you require 'sinatra' you get the DSL extended to Object
gem 'sinatra', '>= 1.3.0', :require => nil
```

Add the following to your `config/routes.rb`:

```ruby
mount SidekiqMonitoring => '/checks'
```

# URL endpoint

To know the state of your sidekiq queues, go to: `<your_website_url>/checks/sidekiq_queues`
Please remember to mount the route before going to this URL

# Define custom threshold

Add the following to an initializer:

```ruby
SidekiqMonitoring.elapsed_thresholds = {
  'queue_name_1' => [warning, critical],
  'queue_name_2' => [warning, critical],
  'queue_name_3' => [warning, critical]
}

SidekiqMonitoring.queue_size_thresholds = {
  'queue_name_1' => [warning, critical],
  'queue_name_2' => [warning, critical],
  'queue_name_3' => [warning, critical]
}

SidekiqMonitoring.latency_thresholds = {
  'queue_name_1' => [warning, critical],
  'queue_name_2' => [warning, critical],
  'queue_name_3' => [warning, critical]
}
```

### Security

In a production application you'll likely want to protect access to this information. You can use the constraints feature of routing (in the _config/routes.rb_ file) to accomplish this:

#### Token

Allow any user who have a valid token

```ruby
constraints lambda { |req| req.params[:access_token] == '235b0ddfa5867d81a3232fa6c997a382' } do
  mount SidekiqMonitoring, :at => '/checks'
end
```

#### Devise

Allow any authenticated `User`

```ruby
# config/routes.rb
authenticate :user do
  mount SidekiqMonitoring => '/checks'
end
```

Same as above but also ensures that `User#admin?` returns true

```ruby
# config/routes.rb
authenticate :user, lambda { |u| u.admin? } do
  mount SidekiqMonitoring => '/checks'
end
```

#### Authlogic

```ruby
# lib/admin_constraint.rb
class AdminConstraint
  def matches?(request)
    return false unless request.cookies['user_credentials'].present?
    user = User.find_by_persistence_token(request.cookies['user_credentials'].split(':')[0])
    user && user.admin?
  end
end

# config/routes.rb
require "admin_constraint"
mount SidekiqMonitoring => '/checks', :constraints => AdminConstraint.new
```

#### Restful Authentication

Checks a `User` model instance that responds to `admin?`

```ruby
# lib/admin_constraint.rb
class AdminConstraint
  def matches?(request)
    return false unless request.session[:user_id]
    user = User.find request.session[:user_id]
    user && user.admin?
  end
end

# config/routes.rb
require 'admin_constraint'
mount SidekiqMonitoring => '/checks', :constraints => AdminConstraint.new
```

#### Custom External Authentication

```ruby
class AuthConstraint
  def self.admin?(request)
    return false unless (cookie = request.cookies['auth'])

    Rails.cache.fetch(cookie['user'], :expires_in => 1.minute) do
      auth_data = JSON.parse(Base64.decode64(cookie['data']))
      response = HTTParty.post(Auth.validate_url, :query => auth_data)

      response.code == 200 && JSON.parse(response.body)['roles'].to_a.include?('Admin')
    end
  end
end

# config/routes.rb
constraints lambda {|request| AuthConstraint.admin?(request) } do
  mount SidekiqMonitoring => '/checks'
end
```
