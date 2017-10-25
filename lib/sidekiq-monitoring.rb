require 'sinatra/base'
require 'multi_json'

class SidekiqMonitoring < Sinatra::Base
  VERSION = "1.2.0"
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

  get '/sidekiq_queues' do
    content_type :json
    MultiJson.dump SidekiqMonitoring::Global.new(@@thresholds, @@latency_thresholds)
  end

  module Monitorable
    ALERT_STATUS = {
      'OK' => 0,
      'WARNING' => 1,
      'CRITICAL' => 2,
      'UNKNOWN' => 3
    }

    attr_accessor :warning_threshold, :critical_threshold, :status

    def <=>(other)
      ALERT_STATUS[status] <=> ALERT_STATUS[other.status]
    end

  end

  class Worker
    include Monitorable

    DEFAULT_THRESHOLD = [ 60, 120 ]

    attr_accessor :process_id, :jid, :run_at, :queue, :worker_class

    def initialize(process_id, jid, run_at, queue, worker_class, thresholds = nil)
      @process_id = process_id
      @jid = jid
      @run_at = run_at
      @queue = queue
      @worker_class = worker_class
      @warning_threshold, @critical_threshold = thresholds ? thresholds : DEFAULT_THRESHOLD
    end

    def as_json
      {
        'queue' => queue,
        'jid' => jid,
        'worker_class' => worker_class,
        'elapsed_time' => elapsed_time,
        'warning_threshold' => warning_threshold,
        'critical_threshold' => critical_threshold,
        'status' => status,
        'process_id' => process_id
      }
    end

    def elapsed_time
      @elapsed_time ||= Time.now.to_i - run_at
    end

    def status
      return 'CRITICAL' if elapsed_time >= critical_threshold
      return 'WARNING' if elapsed_time >= warning_threshold
      'OK'
    end

  end

  class Queue
    include Monitorable

    DEFAULT_THRESHOLD = [ 1_000, 2_000 ]
    DEFAULT_LATENCY_THRESHOLD = [ 300, 900 ]

    attr_accessor :name, :size, :latency, :warning_latency_threshold, :critical_latency_threshold

    def initialize(name, size, latency, thresholds = nil, latency_thresholds = nil)
      @name = name
      @size = size
      @latency = latency
      @warning_threshold, @critical_threshold = (thresholds ? thresholds : DEFAULT_THRESHOLD)
      @warning_latency_threshold, @critical_latency_threshold = (latency_thresholds ? latency_thresholds : DEFAULT_LATENCY_THRESHOLD)
      @status = monitoring_status
    end

    def as_json
      {
        'name' => name,
        'size' => size,
        'warning_threshold' => warning_threshold,
        'critical_threshold' => critical_threshold,
        'latency_warning_threshold' => warning_latency_threshold,
        'latency_critical_threshold' => critical_latency_threshold,
        'latency' => latency,
        'status' => status
      }
    end

    def monitoring_status
      return 'CRITICAL' if size >= critical_threshold || latency >= critical_latency_threshold
      return 'WARNING' if size >= warning_threshold || latency >= warning_latency_threshold
      'OK'
    end

    def criticality
      ALERT_STATUS[monitoring_status]
    end

  end

  class Global

    attr_accessor :thresholds, :latency_thresholds

    def as_json(options = {})
      {
        'global_status' => global_status,
        'queues' => queues.select { |q| q.size > 0 }.sort_by(&:criticality).reverse!.map!(&:as_json),
        'workers' => workers.map(&:as_json)
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

    def initialize(thresholds = {}, latency_thresholds = {})
      @thresholds = thresholds
      @latency_thresholds = latency_thresholds
    end

    def queues
      @queues ||= Sidekiq::Queue.all.map do |queue|
        Queue.new(queue.name, queue.size, queue.latency, thresholds_from_queue(queue.name), latency_thresholds_from_queue(queue.name))
      end
    end

    def workers
      @workers ||= Sidekiq::Workers.new.map do |process_id, thread_id, work|
        payload = work['payload']
        Worker.new(process_id, payload['jid'], work['run_at'], work['queue'], payload['class'], latency_thresholds_from_queue(work['queue']))
      end
    end

    def thresholds_from_queue(queue_name)
      (thresholds || {})[queue_name]
    end

    def latency_thresholds_from_queue(queue_name)
      (latency_thresholds || {})[queue_name]
    end

  end

end
