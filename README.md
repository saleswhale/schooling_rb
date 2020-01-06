# Schooling

A simple wrapper around Redis streams. Motivation:

- [Notion Page](https://www.notion.so/saleswhale/Architecture-Discussion-1ffb11b51c02428d9b5dc1f5a88fe656)
- [Redis Streams](https://redis.io/topics/streams-intro)

Features:

- [ ] Publish/Subscribe
- [ ] Trim events (only keep last `x` events to save memory)
- [ ] Consumer Groups
- [ ] JSON handling
- [ ] Retry on error
- [ ] Deadset

## FAQ

### How do I include this gem in my ruby/rails application?

Add this line to your application's Gemfile:

```ruby
gem 'schooling', git: 'git@github.com:saleswhale/schooling_rb.git'

```

And then execute:

    $ bundle

### How do I use the library?

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can
also run `bin/console` for an interactive prompt that will allow you to
experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).
