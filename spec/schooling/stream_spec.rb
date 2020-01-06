require 'schooling/stream'
require 'redis'

class Processor
  def process(e)
    raise 'I fail' if rand > 0.5
    sleep rand * 5
  end
end

describe Schooling::Stream do
  it 'should' do
    Redis.new.flushdb

    s = described_class.new(
      topic: 'topic',
      group: 'g1',
      consumer: 'c1',
      processor: Processor.new
    )

    s2 = described_class.new(
      topic: 'topic',
      group: 'g1',
      consumer: 'c2',
      processor: Processor.new
    )

    s.publish('hello, world')
    s.create_group

    t1 = Thread.new { 100.times { s.process_batch } }
    t2 = Thread.new { 100.times { s2.process_batch } }
    t3 = Thread.new { 100.times { |i| s.publish(a: i); sleep rand * 2 } }

    t1.join
    t2.join
    t3.join
  end
end
