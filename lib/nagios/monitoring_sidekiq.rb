require 'sinatra/base'
require 'multi_json'

module Nagios

  class MonitoringSidekiq < Sinatra::Base

    class Queue

      ALERT_STATUS = {
        'OK' => 0,
        'WARNING' => 1,
        'CRITICAL' => 2,
        'UNKNOWN' => 3
      }

      THRESHOLD = {
        'default' => [ 1_000, 2_000 ],
        'low' => [ 10_000, 20_000 ],
        'io_slow' => [ 10_000, 20_000 ]
      }

      attr_accessor :name, :size, :warning_threshold, :critical_threshold, :status

      def as_json(options = {})
        {
          'name' => name,
          'size' => size,
          'warning_threshold' => warning_threshold,
          'critical_threshold' => critical_threshold,
          'status' => status
        }
        super
      end

      def initialize(name, size)
        @name = name
        @size = size
        @warning_threshold, @critical_threshold = threshold_from_queue
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

      def threshold_from_queue
        THRESHOLD.fetch(name) { THRESHOLD['default'] }
      end

    end

    class Global

      def as_json(options = {})
        {
          'global_status' => global_status,
          'queues' => queues
        }
        super
      end

      def global_status
        @global_status ||= queues.sort.last.try(:status) || 'UNKNOWN'
      end

      def queues
        @queues ||= Sidekiq::Queue.all.collect{ |queue| Queue.new(queue.name, queue.size) }
      end

    end

    get '/sidekiq_queues' do
      content_type :json
      MultiJson.dump MonitoringSidekiq::Global.new
    end

  end

end
