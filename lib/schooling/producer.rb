# frozen_string_literal: true

require 'schooling/logger'

require 'json'

module Schooling
  # Publish events on a stream
  #
  # Example:
  #
  #   p = Schooling::Producer.new('topic')
  #   p.publish a: 42, time: Time.now
  #
  class Producer
    attr_accessor :cap, :logger
    DEFAULT_CAP = 100_000 # Max events stored

    def initialize(topic, redis: Redis.new)
      @topic = topic
      @redis = redis

      @cap = DEFAULT_CAP
      @logger = Schooling::CliLogger.new
    end

    def publish(body)
      @logger.debug event: :publish, topic: @topic
      @redis.xadd(@topic, { json: JSON.dump(body) }, maxlen: ['~', @cap])
    end
  end
end
