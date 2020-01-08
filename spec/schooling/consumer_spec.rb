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
    let(:processor) do
      Class.new do
        attr_accessor :m

        def process(event)
          (@m ||= []) << event
        end
      end.new
    end

    before(:each) { client.block = 1 } # disable blocking

    it 'should not fail without events' do
      expect { client.process(processor) }.not_to raise_error
    end

    context 'for a json payload' do
      it 'should receive the deserialized output' do
        redis.xadd('t', json: '[{"a": 42, "b": null}, 0.3]')

        expect { client.process(processor) }
          .to change { processor.m }
          .from(nil)
          .to([[{ 'a' => 42, 'b' => nil }, 0.3]])
      end
    end

    context 'for a malformed payload' do
      it 'should drop the message' do
        redis.xadd('t', mal: :formed)

        expect { client.process(processor) }
          .not_to(change { redis.xinfo(:groups, 't').dig(0, 'pending') })
      end
    end

    context 'for a malformed pending message' do
      it 'should drop the message' do
        redis.xadd('t', mal: :formed)
        redis.xreadgroup('g', 'c', 't', '>')

        expect { client.process(processor) }
          .to change { redis.xinfo(:groups, 't').dig(0, 'pending') }
          .from(1).to(0)
      end
    end
  end
end
