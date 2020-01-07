require 'schooling/subscriber'
require 'schooling/publisher'
require 'redis'

class Processor
  def process(e)
    raise 'I fail' if rand > 0.5
    sleep rand * 5
  end
end

p = Schooling::Publisher.new('t')

config_1 = { topic: 't', group: 'g', consumer: 'c1' }
s = Schooling::Subscriber.new(config_1, redis: Redis.new)

config_2 = { topic: 't', group: 'g', consumer: 'c2' }
s2 = Schooling::Subscriber.new(config_2, redis: Redis.new)

processor = Processor.new
t1 = Thread.new { 100.times { s.process(processor) } }
t2 = Thread.new { 100.times { s2.process(processor) } }
t3 = Thread.new { 100.times { |i| p.publish(a: i); sleep rand * 2 } }

t1.join
t2.join
t3.join
