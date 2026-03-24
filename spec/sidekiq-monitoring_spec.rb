require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe SidekiqMonitoring::Queue do

  context 'check queue' do

    context 'with existing threshold' do

      before do
        stub_const('SidekiqMonitoring::Queue::DEFAULT_THRESHOLD', [ 5, 10 ])
      end

      subject(:queue) { SidekiqMonitoring::Queue.new('yolo', 50, 50) }

      it { expect(subject.as_json).to include('name', 'size', 'queue_size_warning_threshold', 'queue_size_critical_threshold', 'status', 'latency', 'latency_warning_threshold', 'latency_critical_threshold') }

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

describe 'Sidekiq API contract' do
  it 'Queue responds to name, size, latency' do
    queue = Sidekiq::Queue.new('default')
    expect(queue).to respond_to(:name)
    expect(queue).to respond_to(:size)
    expect(queue).to respond_to(:latency)
  end

  it 'Queue.all exists' do
    expect(Sidekiq::Queue).to respond_to(:all)
  end

  it 'Workers is enumerable' do
    workers = SIDEKIQ_WORK_SET_CLASS.new
    expect(workers).to respond_to(:each)
    expect(workers).to respond_to(:map)
  end
end

describe SidekiqMonitoring::Global do
  before do
    allow(Sidekiq::Queue).to receive(:all).and_return(sidekiq_queues)
    allow(SIDEKIQ_WORK_SET_CLASS).to receive(:new).and_return(sidekiq_workers)
  end

  let(:sidekiq_queues) { [] }
  let(:sidekiq_workers) { [] }

  context 'without queues' do
    subject(:result) { SidekiqMonitoring::Global.new.as_json }

    it 'unknown status' do
      expect(result['global_status']).to eq('UNKNOWN')
      expect(result['queues']).to be_empty
      expect(result['workers']).to be_empty
    end
  end

  context 'with existing queues' do

    let(:queue_size_thresholds) do
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

    let(:sidekiq_queues) do
      [
        stub_sidekiq_queue(name: 'test_low', size: 1, latency: 0),
        stub_sidekiq_queue(name: 'test_medium', size: 1, latency: 0),
        stub_sidekiq_queue(name: 'test_high', size: 1, latency: 0)
      ]
    end

    context 'checks defaults shared with other tests' do
      it { expect(Sidekiq::Queue.all.size).to eq(3) }
      it { expect(SidekiqMonitoring::Global.new(queue_size_thresholds, latency_thresholds, elapsed_thresholds).as_json['queues']).to be_all { |queue| queue['size'] == 1 } }
      it { expect(SidekiqMonitoring::Global.new(queue_size_thresholds, latency_thresholds, elapsed_thresholds).as_json['queues'].size).to eq(3) }
    end

    context 'without configuration (or broken configuration)' do
      it { expect(SidekiqMonitoring::Global.new(nil, latency_thresholds, elapsed_thresholds).as_json['queues'].size).to eq(3) }
    end

    context 'without job in queue' do
      let(:sidekiq_queues) do
        [
          stub_sidekiq_queue(name: 'test_low', size: 0, latency: 0),
          stub_sidekiq_queue(name: 'test_medium', size: 0, latency: 0),
          stub_sidekiq_queue(name: 'test_high', size: 0, latency: 0)
        ]
      end

      subject { SidekiqMonitoring::Global.new(queue_size_thresholds, latency_thresholds, elapsed_thresholds).as_json }

      it 'is OK' do
        expect(subject['queues'].length).to eq(0)
        expect(subject['global_status']).to eq('OK')
      end
    end

    context 'with slow workers - rely on elapsed thresholds' do
      subject { SidekiqMonitoring::Global.new(queue_size_thresholds, latency_thresholds, elapsed_thresholds) }

      before do
        allow_any_instance_of(SidekiqMonitoring::Global).to receive(:workers) { [SidekiqMonitoring::Worker.new(1234, 'JID-123456', 1531207721, 'low', 'TestWorker', [200, 500])] }
      end

      it 'is OK' do
        allow_any_instance_of(SidekiqMonitoring::Worker).to receive(:elapsed_time) { 10 }
        expect(subject.as_json['workers'].size).to eq(1)
        expect(subject.as_json['global_status']).to eq('OK')
      end

      it 'is WARNING' do
        allow_any_instance_of(SidekiqMonitoring::Worker).to receive(:elapsed_time) { 250 }
        expect(subject.as_json['workers'].size).to eq(1)
        expect(subject.as_json['global_status']).to eq('WARNING')
      end

      it 'is CRITICAL' do
        allow_any_instance_of(SidekiqMonitoring::Worker).to receive(:elapsed_time) { 1200 }
        expect(subject.as_json['workers'].size).to eq(1)
        expect(subject.as_json['global_status']).to eq('CRITICAL')
      end
    end

    context 'with too many jobs in queue - rely on queue size thresholds' do
      subject { SidekiqMonitoring::Global.new(queue_size_thresholds, latency_thresholds, elapsed_thresholds) }

      context 'is OK' do
        it 'process as json' do
          expect(subject.as_json['queues'].length).to eq(3)
          expect(subject.as_json['queues']).to be_all { |queue| queue['status'] == 'OK' }
          expect(subject.as_json['global_status']).to eq('OK')
        end
      end

      context 'is WARNING' do
        let(:sidekiq_queues) do
          [
            stub_sidekiq_queue(name: 'test_low', size: 1_001, latency: 0),
            stub_sidekiq_queue(name: 'test_medium', size: 1, latency: 0),
            stub_sidekiq_queue(name: 'test_high', size: 1, latency: 0)
          ]
        end

        it 'process as json' do
          expect(subject.as_json['queues'].length).to eq(3)
          expect(subject.as_json['queues']).to be_one { |queue| queue['status'] == 'WARNING' }
          expect(subject.as_json['global_status']).to eq('WARNING')
        end
      end

      context 'is CRITICAL' do
        let(:sidekiq_queues) do
          [
            stub_sidekiq_queue(name: 'test_low', size: 2_001, latency: 0),
            stub_sidekiq_queue(name: 'test_medium', size: 1, latency: 0),
            stub_sidekiq_queue(name: 'test_high', size: 1, latency: 0)
          ]
        end

        it 'process as json' do
          expect(subject.as_json['queues'].length).to eq(3)
          expect(subject.as_json['queues']).to be_one { |queue| queue['status'] == 'CRITICAL' }
          expect(subject.as_json['global_status']).to eq('CRITICAL')
        end
      end
    end

    context 'with a worker waiting too long to be processed - rely on latency thresholds' do
      subject { SidekiqMonitoring::Global.new(queue_size_thresholds, latency_thresholds, elapsed_thresholds) }

      context 'is OK' do
        let(:sidekiq_queues) { [stub_sidekiq_queue(name: 'test_low', size: 1, latency: 4 * 60)] }

        it 'process as json' do
          expect(subject.as_json['queues'].length).to eq(1)
          expect(subject.as_json['queues']).to be_all { |queue| queue['status'] == 'OK' }
          expect(subject.as_json['global_status']).to eq('OK')
        end
      end

      context 'is WARNING' do
        let(:sidekiq_queues) { [stub_sidekiq_queue(name: 'test_low', size: 1, latency: 6 * 60)] }

        it 'process as json' do
          expect(subject.as_json['queues'].length).to eq(1)
          expect(subject.as_json['queues']).to be_one { |queue| queue['status'] == 'WARNING' }
          expect(subject.as_json['global_status']).to eq('WARNING')
        end
      end

      context 'is CRITICAL' do
        let(:sidekiq_queues) { [stub_sidekiq_queue(name: 'test_low', size: 1, latency: 16 * 60)] }

        it 'process as json' do
          expect(subject.as_json['queues'].length).to eq(1)
          expect(subject.as_json['queues']).to be_one { |queue| queue['status'] == 'CRITICAL' }
          expect(subject.as_json['global_status']).to eq('CRITICAL')
        end
      end
    end
  end
end

describe SidekiqMonitoring do

  before do
    allow(Sidekiq::Queue).to receive(:all).and_return([])
    allow(SIDEKIQ_WORK_SET_CLASS).to receive(:new).and_return([])
  end

  describe 'GET /sidekiq_queues' do

    it 'is success' do
      get '/sidekiq_queues'
      expect(last_response).to be_ok
      expect(last_response.content_type).to eq('application/json')
      body = JSON.parse(last_response.body)
      expect(body).to include('global_status', 'queues', 'workers')
    end

  end

  describe '#queue_size_thresholds=' do
    let(:queue_size_thresholds) {{
      :test => [100, 1000]
    }}
    it 'should setup queue_size_thresholds' do
      SidekiqMonitoring.queue_size_thresholds = queue_size_thresholds
      expect(SidekiqMonitoring.queue_size_thresholds).to eq(queue_size_thresholds)
    end
  end

  describe '#latency_thresholds=' do
    let(:latency_thresholds) {{
      :test => [100, 1000]
    }}
    it 'should setup latency_thresholds' do
      SidekiqMonitoring.latency_thresholds = latency_thresholds
      expect(SidekiqMonitoring.latency_thresholds).to eq(latency_thresholds)
    end
  end

  describe '#elapsed_thresholds=' do
    let(:elapsed_thresholds) {{
      :test => [100, 1000]
    }}
    it 'should setup elapsed_thresholds' do
      SidekiqMonitoring.elapsed_thresholds = elapsed_thresholds
      expect(SidekiqMonitoring.elapsed_thresholds).to eq(elapsed_thresholds)
    end
  end

end
