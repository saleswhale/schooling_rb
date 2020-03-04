require 'schooling/consumer'
require 'redis'

describe Schooling::Consumer do
  before(:each) do
    Redis.new.flushdb
  end

  let(:config) { { topic: 't', group: 'g', consumer: 'c' } }
  let(:redis) { Redis.new }
  let(:client) { described_class.new(config, redis: redis) }

  describe '#initialize' do
    context 'when the key does not exist' do
      it 'should create the group and the key' do
        expect { client }.to change { redis.exists('t') }.from(false).to(true)
      end
    end

    it 'should create the group' do
      redis.xadd('t', key: :value) # Creates the topic

      expect { client }
        .to change { redis.xinfo(:groups, 't').map { |g| g['name'] } }
        .from([]).to(['g'])
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

  describe '#process' do
    before(:each) { client.block = 1 } # disable blocking

    it 'should not fail without events' do
      expect { client.process -> {} }.not_to raise_error
    end

    context 'for a json payload' do
      it 'should receive the deserialized output' do
        redis.xadd('t', json: '[{"a": 42, "b": null}, 0.3]')

        m = []
        expect { client.process ->(x) { m << x } }
          .to change { m }
          .from([])
          .to([[{ 'a' => 42, 'b' => nil }, 0.3]])
      end
    end

    context 'for a malformed payload' do
      it 'should drop the message' do
        redis.xadd('t', mal: :formed)

        expect { client.process -> {} }
          .not_to(change { redis.xinfo(:groups, 't').dig(0, 'pending') })
      end
    end

    context 'for a malformed pending message' do
      it 'should drop the message' do
        client.backoff = Class.new { def timeout_ms(_); 0; end }.new

        redis.xadd('t', mal: :formed)
        redis.xreadgroup('g', 'c', 't', '>')

        expect { client.process ->(event) { puts event } }
          .to change { x = redis.xinfo(:groups, 't').dig(0, 'pending') }
          .from(1).to(0)
      end
    end
  end

  describe '#input_lag' do
    before(:each) { client.block = 1 } # disable blocking

    context 'when the stream does not have any messages' do
      it 'should be zero' do
        expect(client.input_lag).to eq(0)
      end
    end

    context 'when there are some unread messages on the stream' do
      before { 3.times { redis.xadd('t', json: '42') } }

      it 'should be the count' do
        expect(client.input_lag).to eq(3)
      end

      context 'which have been processed' do
        before { client.process ->() {} }

        it 'should be back to 0' do
          expect(client.input_lag).to eq(0)
        end
      end
    end
  end
end
