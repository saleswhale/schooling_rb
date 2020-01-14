# frozen_string_literal: true

require 'schooling/backoff'
require 'schooling/logger'

require 'json'

module Schooling
  # Subscribe to events from a stream
  #
  # Example:
  #
  #   c = Schooling::Consumer.new({ topic: :t, group: :g, consumer: c })
  #   c.process(processor_instance)
  #
  class Consumer
    attr_accessor :block, :backoff, :batch, :logger

    BATCH_SIZE = 1000 # How many events to fetch
    DEFAULT_BLOCK = 2 * 1000 # In seconds

    def initialize(config, redis: Redis.new)
      @redis = redis
      @config = config

      # Defaults
      @batch = BATCH_SIZE
      @block = DEFAULT_BLOCK
      @backoff = Schooling::ExponentialBackoff.new
      @logger = Schooling::NullLogger.new

      create_group
    end

    def process(processor)
      process_failed_events(processor)
      process_unseen(processor)
    end

    private

    def topic
      @topic ||= @config[:topic]
    end

    def group
      @group ||= @config[:group]
    end

    def consumer
      @consumer ||= @config[:consumer]
    end

    def create_group
      if @redis.exists(topic)
        groups = @redis.xinfo(:groups, topic).map { |g| g.dig('name') }
        return if groups.include? group
      end

      @redis.xgroup(:create, topic, group, '$', mkstream: true)
    end

    def process_event(processor, id, event)
      @logger.info event: :start_processing, id: id
      processor.call(event)
      @redis.xack(topic, group, id)
      @logger.info event: :finish_processing, id: id
    rescue StandardError => e
      @logger.error event: :failed_processing, id: id, error: e.message
    end

    def process_failed_event(processor, id, retries)
      failed = @redis.xclaim(topic, group, consumer,
                             @backoff.timeout_ms(retries).to_int, id)[0]
      return if failed.nil?

      unless failed&.dig(1, 'json')
        @logger.info event: :skipping_malformed, id: id
        @redis.xack(topic, group, id)
        return
      end

      process_event(processor, id, JSON.parse(failed.dig(1, 'json')))
    end

    def process_failed_events(processor)
      @redis.xpending(topic, group, '-', '+', @batch).each do |event|
        id = event['entry_id']
        retries = event['count']
        process_failed_event(processor, id, retries)
      end
    end

    def process_unseen(processor)
      events = @redis.xreadgroup(group, consumer, topic, '>', count: @batch, block: @block)
      return if events == {}

      events.fetch(topic).each do |id, event|
        unless event&.dig('json')
          @logger.info event: :skipping_malformed, id: id
          @redis.xack(topic, group, id)
          next
        end

        process_event(processor, id, JSON.parse(event['json']))
      end
    end
  end
end
