# Schooling

A simple wrapper around Redis streams. Motivation:

- [Notion Page](https://www.notion.so/saleswhale/Architecture-Discussion-1ffb11b51c02428d9b5dc1f5a88fe656)
- [Redis Streams](https://redis.io/topics/streams-intro)

Features:

- Publish/Subscribe
- Trim events (only keep last `x` events to save memory)
- Consumer Groups
- JSON handling
- Retry on error

## FAQ

### How do I include this gem in my ruby/rails application?

Add this line to your application's Gemfile:

```ruby
gem 'schooling', git: 'git@github.com:saleswhale/schooling_rb.git'

```

And then execute:

    $ bundle

### How do I use the library?

You need to

1. Supply a processor class
2. Supply a Redis client instance
3. Subscribe to the topic in a group as a consumer (unique name)
4. Call `process_batch`

```ruby
require 'schooling/subscriber'
require 'schooling/publisher'
require 'redis'

class Processor
  def process(e)
    raise 'I fail' if rand > 0.5
    sleep rand * 5
  end
end

p = Schooling::Publisher.new(redis: Redis.new, topic: 'topic')

s = described_class.new(
  redis: Redis.new,
  topic: 'topic',
  group: 'g1',
  consumer: 'c1',
  processor: Processor.new
)

s2 = described_class.new(
  redis: Redis.new,
  topic: 'topic',
  group: 'g1',
  consumer: 'c2',
  processor: Processor.new
)

p.publish('hello, world')
s.create_group

t1 = Thread.new { 100.times { s.process_batch } }
t2 = Thread.new { 100.times { s2.process_batch } }
t3 = Thread.new { 100.times { |i| p.publish(a: i); sleep rand * 2 } }

t1.join
t2.join
t3.join
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can
also run `bin/console` for an interactive prompt that will allow you to
experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).
