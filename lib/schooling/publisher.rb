# frozen_string_literal: true

require 'schooling/logger'

require 'redis'
require 'json'

module Schooling
  # Publish events on a stream
  #
  # Example:
  #
  #   p = Publisher.new(topic: 'topic')
  #   p.publish a: 42, time: Time.now
  #
  class Publisher
    DEFAULT_CAP = 100_000 # Max events stored

    def initialize(url: nil, topic:, cap: DEFAULT_CAP,
                   logger: Schooling::CliLogger.new)
      @redis = Redis.new(url: url)

      @topic = topic
      @cap = cap
      @logger = logger
    end

    def publish(body)
      @logger.debug event: :publish, topic: @topic
      @redis.xadd(@topic, { json: JSON.dump(body) }, maxlen: ['~', @cap])
    end
  end
end
