require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe SidekiqMonitoring::Queue do

  context 'check queue' do

    context 'with existing threshold' do

      before do
        stub_const('SidekiqMonitoring::Queue::DEFAULT_THRESHOLD', [ 5, 10 ])
      end

      subject(:queue) { SidekiqMonitoring::Queue.new('yolo', 50, 50) }

      it { subject.as_json.should include('name', 'size', 'warning_threshold', 'critical_threshold', 'status') }

      it 'sort by status' do
        yolo = SidekiqMonitoring::Queue.new('yolo', 3, 50)
        monkey = SidekiqMonitoring::Queue.new('monkey', 7, 50)
        bird = SidekiqMonitoring::Queue.new('bird', 12, 50)

        yolo.status.should be == 'OK'
        monkey.status.should be == 'WARNING'
        bird.status.should be == 'CRITICAL'

        [monkey, yolo, bird].sort.should == [yolo, monkey, bird]
      end

      it 'does not fail without thresholds' do
        SidekiqMonitoring::Global.new(nil)

      end
    end

  end

end

describe SidekiqMonitoring::Global do

  context 'without queues' do

    subject(:result) { SidekiqMonitoring::Global.new.as_json }

    it 'unknown status' do
      result['global_status'].should be == 'UNKNOWN'
      result['queues'].should be_empty
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

    let(:queue_size) { 1 }
    let(:sidekiq_queues) { queues_name.map{ |name| Sidekiq::Queue.new(name).tap { |q| q.stub(:size) { queue_size } } } }

    context 'no configuration' do
      let(:thresholds) { nil }

      before do
        Sidekiq::Queue.stub(:all) { sidekiq_queues }
      end

      it { SidekiqMonitoring::Global.new(thresholds, latency_thresholds).as_json['queues'].should have(3).queues }
    end

    context 'check default' do

      before do
        Sidekiq::Queue.stub(:all) { sidekiq_queues }
      end

      it { Sidekiq::Queue.all.should have(3).queues }
      it { SidekiqMonitoring::Global.new(thresholds, latency_thresholds).as_json['queues'].should have(3).queues }

    end

    context 'with empty queues' do
      let(:queue_size) { 0 }
      before do
        Sidekiq::Queue.stub(:all) { sidekiq_queues }
      end

      subject(:empty_queues) { SidekiqMonitoring::Global.new(thresholds, latency_thresholds).as_json }

      it 'skips empty queues' do
        empty_queues['queues'].length.should == 0
        empty_queues['global_status'].should == 'OK'
      end
    end

    context 'ok status' do

      before do
        Sidekiq::Queue.stub(:all) { sidekiq_queues }
      end

      subject(:ok) { SidekiqMonitoring::Global.new(thresholds, latency_thresholds).as_json }

      it 'process as json' do
        ok['queues'].length.should == 3
        ok['queues'].should be_all{ |queue| queue['status'] == 'OK' }
        ok['global_status'].should == 'OK'
      end

    end

    context 'warning status' do

      before do
        queue = sidekiq_queues.pop
        queue.stub(:size) { thresholds[queue.name][0] + 1 }
        Sidekiq::Queue.stub(:all) { sidekiq_queues + [queue] }
      end

      subject(:warning) { SidekiqMonitoring::Global.new(thresholds, latency_thresholds).as_json }

      it 'process as json' do
        warning['queues'].should be_one{ |queue| queue['status'] == 'WARNING' }
        warning['global_status'].should == 'WARNING'
      end

    end

    context 'critical status' do

      before do
        queue = sidekiq_queues.pop
        queue.stub(:size) { thresholds[queue.name][1] + 1 }
        Sidekiq::Queue.stub(:all) { sidekiq_queues + [queue] }
      end

      subject(:critical) { SidekiqMonitoring::Global.new(thresholds, latency_thresholds).as_json }

      it 'process as json' do
        critical['queues'].should be_one{ |queue| queue['status'] == 'CRITICAL' }
        critical['global_status'].should == 'CRITICAL'
      end

    end

  end

end

describe SidekiqMonitoring do

  describe 'GET /sidekiq_queues' do

    it 'is success' do
      get '/sidekiq_queues'
      last_response.should be_ok
      last_response.content_type.should == 'application/json'
    end

  end

end
