require 'sinatra/base'
require 'multi_json'

class SidekiqMonitoring < Sinatra::Base

  # Set yours down thresholds configuration
  # {'default' => [ 1_000, 2_000 ], 'low' => [ 10_000, 20_000 ] }
  def self.thresholds=(thresholds)
    @@thresholds = thresholds
  end
  @@thresholds = {}

  get '/sidekiq_queues' do
    content_type :json
    MultiJson.dump SidekiqMonitoring::Global.new(@@thresholds)
  end

  class Queue

    ALERT_STATUS = {
      'OK' => 0,
      'WARNING' => 1,
      'CRITICAL' => 2,
      'UNKNOWN' => 3
    }

    DEFAULT_THRESHOLD = [ 1_000, 2_000 ]

    attr_accessor :name, :size, :warning_threshold, :critical_threshold, :status

    def as_json(options = {})
      {
        'name' => name,
        'size' => size,
        'warning_threshold' => warning_threshold,
        'critical_threshold' => critical_threshold,
        'status' => status
      }
    end

    def initialize(name, size, thresholds = nil)
      @name = name
      @size = size
      @warning_threshold, @critical_threshold = (thresholds ? thresholds : DEFAULT_THRESHOLD)
      @status = monitoring_status
    end

    def <=>(other)
      ALERT_STATUS[status] <=> ALERT_STATUS[other.status]
    end

    def monitoring_status
      return 'CRITICAL' if size >= critical_threshold
      return 'WARNING' if size >= warning_threshold
      'OK'
    end

  end

  class Global

    attr_accessor :thresholds

    def as_json(options = {})
      {
        'global_status' => global_status,
        'queues' => queues.map(&:as_json)
      }
    end

    def global_status
      @global_status ||= (queues.sort.last && queues.sort.last.status) || 'UNKNOWN'
    end

    def initialize(thresholds = {})
      @thresholds = thresholds
    end

    def queues
      @queues ||= Sidekiq::Queue.all.collect{ |queue|
        Queue.new(queue.name, queue.size, thresholds_from_queue(queue.name))
      }
    end

    def thresholds_from_queue(queue_name)
      (thresholds || {})[queue_name]
    end

  end

end
