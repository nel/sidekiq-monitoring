require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe SidekiqMonitoring::Queue do

  context 'check queue' do

    context 'with existing threshold' do

      before do
        stub_const('SidekiqMonitoring::Queue::DEFAULT_THRESHOLD', [ 5, 10 ])
      end

      subject(:queue) { SidekiqMonitoring::Queue.new('yolo', 50, 50) }

      it { expect(subject.as_json).to include('name', 'size', 'warning_threshold', 'critical_threshold', 'status') }

      it 'sort by status' do
        yolo = SidekiqMonitoring::Queue.new('yolo', 3, 50)
        monkey = SidekiqMonitoring::Queue.new('monkey', 7, 50)
        bird = SidekiqMonitoring::Queue.new('bird', 12, 50)

        expect(yolo.status).to eq('OK')
        expect(monkey.status).to eq('WARNING')
        expect(bird.status).to eq('CRITICAL')

        expect([monkey, yolo, bird].sort).to match_array([yolo, monkey, bird])
      end

      it 'does not fail without thresholds' do
        SidekiqMonitoring::Global.new(nil)

      end
    end

  end

end

describe SidekiqMonitoring::Global do
  context 'without queues' do

    before do
      allow(Sidekiq::Queue).to receive(:all) { [] }
    end

    subject(:result) { SidekiqMonitoring::Global.new.as_json }

    it 'unknown status' do
      expect(result['global_status']).to eq('UNKNOWN')
      expect(result['queues']).to be_empty
      expect(result['workers']).to be_empty
    end

  end

  context 'with many queues' do

    let(:queues_name) { %w(test_low test_medium test_high) }
    let(:thresholds) do
      { 'test_low' => [ 1_000, 2_000 ],
        'test_medium' => [ 10_000, 20_000 ],
        'test_high' => [ 10_000, 20_000 ] }
    end

    let(:latency_thresholds) do
      { 'test_low' => [ 300, 900 ],
        'test_medium' => [ 1_800, 3_600 ],
        'test_high' => [ 900, 1_800 ] }
    end

    let(:elapsed_thresholds) do
      { 'test_low' => [ 30, 90 ],
        'test_medium' => [ 180, 360 ],
        'test_high' => [ 90, 180 ] }
    end

    let(:queue_size) { 1 }
    let(:sidekiq_queues) { queues_name.map{ |name| Sidekiq::Queue.new(name).tap { |q| allow(q).to receive(:size) { queue_size } } } }

    context 'no configuration' do
      let(:thresholds) { nil }

      before do
        allow(Sidekiq::Queue).to receive(:all) { sidekiq_queues }
      end

      it { expect(SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds).as_json['queues'].size).to eq(3) }
    end

    context 'check default' do

      before do
        allow(Sidekiq::Queue).to receive(:all) { sidekiq_queues }
      end

      it { expect(Sidekiq::Queue.all.size).to eq(3) }
      it { expect(SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds).as_json['queues'].size).to eq(3) }

    end

    context 'with slow workers' do

      before do
        allow_any_instance_of(SidekiqMonitoring::Global).to receive(:workers) { [SidekiqMonitoring::Worker.new(1234, 'JID-123456', 1531207721, 'low', 'TestWorker', [200, 500])] }
      end

      it 'is OK' do
        allow_any_instance_of(SidekiqMonitoring::Worker).to receive(:elapsed_time) { 10 }
        sidekiq_monitoring = SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds)

        sidekiq_monitoring_json = sidekiq_monitoring.as_json
        expect(sidekiq_monitoring_json['workers'].size).to eq(1)
        expect(sidekiq_monitoring_json['global_status']).to eq('OK')
      end

      it 'is WARNING' do
        allow_any_instance_of(SidekiqMonitoring::Worker).to receive(:elapsed_time) { 250 }
        sidekiq_monitoring = SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds)

        sidekiq_monitoring_json = sidekiq_monitoring.as_json
        expect(sidekiq_monitoring_json['workers'].size).to eq(1)
        expect(sidekiq_monitoring_json['global_status']).to eq('WARNING')
      end

      it 'is CRITICAL' do
        allow_any_instance_of(SidekiqMonitoring::Worker).to receive(:elapsed_time) { 1200 }
        sidekiq_monitoring = SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds)

        sidekiq_monitoring_json = sidekiq_monitoring.as_json
        expect(sidekiq_monitoring_json['workers'].size).to eq(1)
        expect(sidekiq_monitoring_json['global_status']).to eq('CRITICAL')
      end

    end

    context 'with empty queues' do
      let(:queue_size) { 0 }
      before do
        allow(Sidekiq::Queue).to receive(:all) { sidekiq_queues }
      end

      subject(:empty_queues) { SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds).as_json }

      it 'skips empty queues' do
        expect(empty_queues['queues'].length).to eq(0)
        expect(empty_queues['global_status']).to eq('OK')
      end
    end

    context 'ok status' do

      before do
        allow(Sidekiq::Queue).to receive(:all) { sidekiq_queues }
      end

      subject(:ok) { SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds).as_json }

      it 'process as json' do
        expect(ok['queues'].length).to eq(3)
        expect(ok['queues']).to be_all{ |queue| queue['status'] == 'OK' }
        expect(ok['global_status']).to eq('OK')
      end

    end

    context 'warning status' do

      before do
        queue = sidekiq_queues.pop
        allow(queue).to receive(:size) { thresholds[queue.name][0] + 1 }
        allow(Sidekiq::Queue).to receive(:all) { sidekiq_queues + [queue] }
      end

      subject(:warning) { SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds).as_json }

      it 'process as json' do
        expect(warning['queues']).to be_one{ |queue| queue['status'] == 'WARNING' }
        expect(warning['global_status']).to eq('WARNING')
      end

    end

    context 'critical status' do

      before do
        queue = sidekiq_queues.pop
        allow(queue).to receive(:size) { thresholds[queue.name][1] + 1 }
        allow(Sidekiq::Queue).to receive(:all) { sidekiq_queues + [queue] }
      end

      subject(:critical) { SidekiqMonitoring::Global.new(thresholds, latency_thresholds, elapsed_thresholds).as_json }

      it 'process as json' do
        expect(critical['queues']).to be_one{ |queue| queue['status'] == 'CRITICAL' }
        expect(critical['global_status']).to eq('CRITICAL')
      end

    end

  end

end

describe SidekiqMonitoring do

  describe 'GET /sidekiq_queues' do

    it 'is success' do
      get '/sidekiq_queues'
      expect(last_response).to be_ok
      expect(last_response.content_type).to eq('application/json')
    end

  end

end
