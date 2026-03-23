[![Test](https://github.com/nel/sidekiq-monitoring/actions/workflows/test.yml/badge.svg)](https://github.com/nel/sidekiq-monitoring/actions/workflows/test.yml)

# Sidekiq Monitoring

A Sinatra-based monitoring API for Sidekiq queues. Returns JSON with queue sizes, latencies, worker elapsed times, and a global health status (OK, WARNING, CRITICAL, UNKNOWN).

## Installation

Add to your Gemfile:

```ruby
gem 'sidekiq-monitoring'
```

## Setup

### Rack / Sinatra

Mount in your `config.ru`:

```ruby
require 'sidekiq-monitoring'
run SidekiqMonitoring
```

### Rails

Mount in `config/routes.rb`:

```ruby
mount SidekiqMonitoring => '/checks'
```

### Sinatra 4+ host authorization

Sinatra 4 blocks requests from unknown hosts by default. If you're using Sinatra 4+, you need to permit your host:

```ruby
SidekiqMonitoring.set(:host_authorization, permitted: "your-domain.com")
```

Or to allow any host:

```ruby
SidekiqMonitoring.set(:host_authorization, permitted: "**")
```

## Usage

Check the state of your Sidekiq queues at:

```
GET /sidekiq_queues
```

Returns JSON:

```json
{
  "global_status": "OK",
  "queues": [
    {
      "name": "default",
      "status": "OK",
      "size": 42,
      "queue_size_warning_threshold": 1000,
      "queue_size_critical_threshold": 2000,
      "latency": 0.5,
      "latency_warning_threshold": 300,
      "latency_critical_threshold": 900
    }
  ],
  "workers": []
}
```

## Custom thresholds

Configure thresholds in an initializer. Values are `[warning, critical]` pairs.

```ruby
# Queue size: number of jobs in queue
SidekiqMonitoring.queue_size_thresholds = {
  'default' => [1_000, 2_000],
  'low'     => [10_000, 20_000]
}

# Latency: seconds since oldest job was enqueued
SidekiqMonitoring.latency_thresholds = {
  'default' => [300, 900],
  'low'     => [1_800, 3_600]
}

# Elapsed time: seconds a worker has been running
SidekiqMonitoring.elapsed_thresholds = {
  'default' => [60, 120],
  'low'     => [180, 360]
}
```

Queues without explicit thresholds use defaults:
- Queue size: 1,000 / 2,000
- Latency: 300s / 900s
- Elapsed time: 60s / 120s

## Security

You'll likely want to protect this endpoint in production.

### Token-based

```ruby
constraints lambda { |req| req.params[:access_token] == 'your-secret-token' } do
  mount SidekiqMonitoring => '/checks'
end
```

### Devise

```ruby
authenticate :user, lambda { |u| u.admin? } do
  mount SidekiqMonitoring => '/checks'
end
```

## Compatibility

| Sidekiq | Ruby   | Sinatra |
|---------|--------|---------|
| 6       | >= 3.1 | >= 3    |
| 7       | >= 3.1 | >= 3    |
| 8       | >= 3.2 | >= 4    |

## License

MIT
