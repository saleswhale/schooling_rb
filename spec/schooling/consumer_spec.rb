require 'schooling/consumer'
require 'redis'

describe Schooling::Consumer do
  before(:each) do
    Redis.new.flushdb
  end

  describe '#initialize' do
    let(:config) { { topic: 't', group: 'g', consumer: 'c' } }
    let(:redis) { Redis.new }
    let(:client) { described_class.new(config, redis: redis) }

    it 'should create the group' do
      expect(redis).to receive(:xgroup)
      client
    end

    context 'when the topic does not exist' do
      it 'should create the topic' do
        expect { client }.to change { redis.exists('t') }.to(true)
      end
    end

    context 'when the group already exists' do
      it 'should not fail' do
        redis.xgroup(:create, 't', 'g', '$', mkstream: true)
        expect { client }.not_to raise_error
      end
    end
  end
end
