require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe Nagios::MonitoringSidekiq do

  context 'check queue' do

    context 'with existing threshold' do

      subject(:queue) { Nagios::MonitoringSidekiq::Queue.new('yolo', 50) }

      before do
        stub_const('Nagios::MonitoringSidekiq::Queue::THRESHOLD', {
          'default' => [ 5, 10 ],
          'yolo' => [ 10, 20 ]
        })
      end

      its(:threshold_from_queue) { should == [10, 20] }
      its(:as_json) { should include('name', 'size', 'warning_threshold', 'critical_threshold', 'status') }

    end

    context 'without existing threshold' do

      subject(:queue) { Nagios::MonitoringSidekiq::Queue.new('yata', 50) }

      before do
        stub_const('Nagios::MonitoringSidekiq::Queue::THRESHOLD', {
          'default' => [ 5, 10 ],
          'yolo' => [ 10, 20 ]
        })
      end

      its(:threshold_from_queue) { should == [5, 10] }
      its(:as_json) { should include('name', 'size', 'warning_threshold', 'critical_threshold', 'status') }

      it 'sort by status' do
        yolo = Nagios::MonitoringSidekiq::Queue.new('yolo', 3)
        monkey = Nagios::MonitoringSidekiq::Queue.new('monkey', 7)
        bird = Nagios::MonitoringSidekiq::Queue.new('bird', 12)

        yolo.status.should be == 'OK'
        monkey.status.should be == 'WARNING'
        bird.status.should be == 'CRITICAL'

        [monkey, yolo, bird].sort.should == [yolo, monkey, bird]
      end

    end

  end

  context 'without queues' do

    subject(:result) { Nagios::MonitoringSidekiq::Global.new.as_json }

    it 'unknown status' do
      result['global_status'].should be == 'UNKNOWN'
      result['queues'].should be_empty
    end

  end

  context 'with many queues' do

    let(:queues_name) { %w(test_low test_medium test_high) }
    let(:threshold) do
      stub_const('Nagios::MonitoringSidekiq::Queue::THRESHOLD', {
        'test_low' => [ 1_000, 2_000 ],
        'test_medium' => [ 10_000, 20_000 ],
        'test_high' => [ 10_000, 20_000 ]
      })
    end

    let(:sidekiq_queues) { queues_name.map{ |name| Sidekiq::Queue.new(name) } }

    context 'check default' do

      before do
        Sidekiq::Queue.stub(:all) { sidekiq_queues }
      end

      it { Sidekiq::Queue.all.should have(3).queues }
      it { Nagios::MonitoringSidekiq::Global.new.as_json['queues'].should have(3).queues }

    end

    context 'ok status' do

      before do
        Sidekiq::Queue.stub(:all) { sidekiq_queues }
      end

      subject(:ok) { Nagios::MonitoringSidekiq::Global.new.as_json }

      it 'process as json' do
        ok['queues'].should be_all{ |queue| queue['status'] == 'OK' }
        ok['global_status'].should == 'OK'
      end

    end

    context 'warning status' do

      before do
        queue = sidekiq_queues.pop
        queue.stub(:size) { threshold[queue.name][0] + 1 }
        Sidekiq::Queue.stub(:all) { sidekiq_queues + [queue] }
      end

      subject(:warning) { Nagios::MonitoringSidekiq::Global.new.as_json }

      it 'process as json' do
        warning['queues'].should be_one{ |queue| queue['status'] == 'WARNING' }
        warning['global_status'].should == 'WARNING'
      end

    end

    context 'critical status' do

      before do
        queue = sidekiq_queues.pop
        queue.stub(:size) { threshold[queue.name][1] + 1 }
        Sidekiq::Queue.stub(:all) { sidekiq_queues + [queue] }
      end

      subject(:critical) { Nagios::MonitoringSidekiq::Global.new.as_json }

      it 'process as json' do
        critical['queues'].should be_one{ |queue| queue['status'] == 'CRITICAL' }
        critical['global_status'].should == 'CRITICAL'
      end

    end

  end

end
