require 'sinatra/base'
require 'multi_json'

class SidekiqMonitoring < Sinatra::Base
  VERSION = "1.2.1"
  # Set your down thresholds configuration
  # {'default' => [ 1_000, 2_000 ], 'low' => [ 10_000, 20_000 ] }
  def self.thresholds=(thresholds)
    @@thresholds = thresholds
  end
  @@thresholds = {}

  def self.latency_thresholds=(latency_thresholds)
    @@latency_thresholds = latency_thresholds
  end
  @@latency_thresholds = {}

  def self.elapsed_thresholds=(elapsed_thresholds)
    @@elapsed_thresholds = elapsed_thresholds
  end
  @@elapsed_thresholds = {}

  get '/sidekiq_queues' do
    content_type :json
    MultiJson.dump SidekiqMonitoring::Global.new(@@thresholds, @@latency_thresholds, @@elapsed_thresholds)
  end

  module Monitorable
    ALERT_STATUS = {
      'OK' => 0,
      'WARNING' => 1,
      'CRITICAL' => 2,
      'UNKNOWN' => 3
    }

    attr_accessor :status

    def <=>(other)
      ALERT_STATUS[status] <=> ALERT_STATUS[other.status]
    end

    def criticality
      ALERT_STATUS[monitoring_status]
    end

    def monitoring_status
      raise NotImplementedError.new "#{self.class}#monitoring_status"
    end
  end

  class Worker
    include Monitorable

    DEFAULT_ELAPSED_THRESHOLD = [ 60, 120 ]

    attr_accessor :process_id, :jid, :run_at, :queue, :worker_class, :elapsed_warning_threshold, :elapsed_critical_threshold

    def initialize(process_id, jid, run_at, queue, worker_class, elapsed_thresholds = nil)
      @process_id = process_id
      @jid = jid
      @run_at = run_at
      @queue = queue
      @worker_class = worker_class
      @elapsed_warning_threshold, @elapsed_critical_threshold = elapsed_thresholds ? elapsed_thresholds : DEFAULT_ELAPSED_THRESHOLD
      @status = monitoring_status
    end

    def as_json
      {
        'queue' => queue,
        'jid' => jid,
        'process_id' => process_id,
        'worker_class' => worker_class,
        'status' => status,
        'elapsed_time' => elapsed_time,
        'elapsed_warning_threshold' => warning_elapsed_threshold,
        'elapsed_critical_threshold' => critical_elapsed_threshold
      }
    end

    def elapsed_time
      @elapsed_time ||= Time.now.to_i - run_at
    end

    def monitoring_status
      return 'CRITICAL' if elapsed_time >= elapsed_critical_threshold
      return 'WARNING' if elapsed_time >= elapsed_warning_threshold
      'OK'
    end
  end

  class Queue
    include Monitorable

    DEFAULT_THRESHOLD = [ 1_000, 2_000 ]
    DEFAULT_LATENCY_THRESHOLD = [ 300, 900 ]

    attr_accessor :name, :size, :warning_threshold, :critical_threshold, :latency, :latency_warning_threshold, :latency_critical_threshold

    def initialize(name, size, latency, thresholds = nil, latency_thresholds = nil)
      @name = name
      @size = size
      @latency = latency
      @warning_threshold, @critical_threshold = (thresholds ? thresholds : DEFAULT_THRESHOLD)
      @latency_warning_threshold, @latency_critical_threshold = (latency_thresholds ? latency_thresholds : DEFAULT_LATENCY_THRESHOLD)
      @status = monitoring_status
    end

    def as_json
      {
        'name' => name,
        'size' => size,
        'status' => status,
        'warning_threshold' => warning_threshold,
        'critical_threshold' => critical_threshold,
        'latency' => latency,
        'latency_warning_threshold' => latency_warning_threshold,
        'latency_critical_threshold' => latency_critical_threshold
      }
    end

    def monitoring_status
      return 'CRITICAL' if size >= critical_threshold || latency >= latency_critical_threshold
      return 'WARNING' if size >= warning_threshold || latency >= latency_warning_threshold
      'OK'
    end
  end

  class Global
    attr_accessor :thresholds, :latency_thresholds, :elapsed_thresholds

    def as_json(options = {})
      {
        'global_status' => global_status,
        'queues' => queues.select { |q| q.size > 0 }.sort_by(&:criticality).reverse!.map!(&:as_json),
        'workers' => workers.sort_by(&:criticality).reverse!.map!(&:as_json),
      }
    end

    def global_status
      queue_status = (queues.sort.last && queues.sort.last.status) || 'UNKNOWN'
      worker_status = (workers.sort.last && workers.sort.last.status) || 'UNKNOWN'
      status = if worker_status != 'UNKNOWN' && Monitorable::ALERT_STATUS[worker_status] > Monitorable::ALERT_STATUS[queue_status]
        worker_status
      else
        queue_status
      end
      @global_status ||= status
    end

    def initialize(thresholds = {}, latency_thresholds = {}, elapsed_thresholds = {})
      @thresholds = thresholds
      @latency_thresholds = latency_thresholds
      @elapsed_thresholds = elapsed_thresholds
    end

    def queues
      @queues ||= Sidekiq::Queue.all.map do |queue|
        Queue.new(queue.name, queue.size, queue.latency, thresholds_from_queue(queue.name), latency_thresholds_from_queue(queue.name))
      end
    end

    def workers
      @workers ||= Sidekiq::Workers.new.map do |process_id, thread_id, work|
        payload = work['payload']
        Worker.new(process_id, payload['jid'], work['run_at'], work['queue'], payload['class'], elapsed_thresholds_from_queue(work['queue']))
      end
    end

    def thresholds_from_queue(queue_name)
      (thresholds || {})[queue_name]
    end

    def latency_thresholds_from_queue(queue_name)
      (latency_thresholds || {})[queue_name]
    end

    def elapsed_thresholds_from_queue(queue_name)
      (elapsed_thresholds || {})[queue_name]
    end
  end
end
