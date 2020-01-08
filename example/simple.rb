$:.unshift(File.expand_path('../lib/'))

require 'schooling/consumer'
require 'schooling/producer'
require 'redis'

Redis.new.flushdb

fail_sometimes = proc { |x| rand > 0.5 ? (raise 'I failed!') : (p success: x) }

config1 = { topic: 't', group: 'g', consumer: 'c1' }
c = Schooling::Consumer.new(config1, redis: Redis.new)
t1 = Thread.new { loop { c.process fail_sometimes } }

config2 = { topic: 't', group: 'g', consumer: 'c2' }
c2 = Schooling::Consumer.new(config2, redis: Redis.new)
t2 = Thread.new { loop { c2.process fail_sometimes } }

p = Schooling::Producer.new(:t)
t3 = Thread.new { 100.times { |i| p.publish(a: i); sleep rand * 3 } }

[t1, t2, t3].map(&:join)
