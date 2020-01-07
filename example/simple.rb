require 'schooling/consumer'
require 'schooling/producer'
require 'redis'

class Processor
  def process(e)
    raise 'I fail' if rand > 0.5

    sleep rand * 5
  end
end

p = Schooling::Producer.new(:t)

config1 = { topic: :t, group: :g, consumer: :c1 }
c = Schooling::Consumer.new(config1, redis: Redis.new)

config2 = { topic: :t, group: :g, consumer: :c2 }
c2 = Schooling::Consumer.new(config2, redis: Redis.new)

processor = Processor.new
t1 = Thread.new { 10.times { c.process(processor) } }
t2 = Thread.new { 10.times { c2.process(processor) } }
t3 = Thread.new { 100.times { |i| p.publish(i); sleep rand * 2 } }

t1.join
t2.join
t3.join
