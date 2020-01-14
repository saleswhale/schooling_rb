# Schooling

A simple wrapper around Redis streams. Motivation:

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

1. Subscribe to the topic in a group as a consumer, with an unique name
2. Call `process` with a proc/lambda

```ruby
require 'schooling/consumer'
require 'schooling/producer'
require 'redis'

processor = proc { |event| rand > 0.5 ? (raise 'I fail') : (sleep rand * 5) }
# or: -> (event) { puts event }
# or: Class.new { def call(event); puts event; end }.new

config1 = { topic: 't', group: 'g', consumer: 'c1' }
c = Schooling::Consumer.new(config1, redis: Redis.new)
t1 = Thread.new { 10.times { c.process(processor) } }

config2 = { topic: 't', group: 'g', consumer: 'c2' }
c2 = Schooling::Consumer.new(config2, redis: Redis.new)
t2 = Thread.new { 10.times { c2.process(processor) } }

p = Schooling::Producer.new(:t)
t3 = Thread.new { 100.times { |i| p.publish(i); sleep rand * 2 } }

[t1, t2, t3].each(&:join)
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
