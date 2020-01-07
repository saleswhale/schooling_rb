# frozen_string_literal: true

require 'schooling/backoff'
require 'schooling/logger'

require 'json'

module Schooling
  class Subscriber
    attr_accessor :block, :backoff, :logger

    BATCH_SIZE = 1000 # How many events to fetch
    DEFAULT_BLOCK = 2 * 1000 # In seconds

    def initialize(config, redis: Redis.new)
      @redis = redis
      @topic = config[:topic]
      @group = config[:group]
      @consumer = config[:consumer]

      # Behavior
      @block = DEFAULT_BLOCK
      @backoff = Schooling::ExponentialBackoff.new
      @logger = Schooling::CliLogger.new(level: :debug)

      # Create the group and the topic
      create_group
    end

    def process(processor)
      process_failed_events(processor)
      process_unseen(processor)
    end

    private

    def create_group
      return if @redis.exists(@topic)

      @redis.xgroup(:create, @topic, @group, '$', mkstream: true)
    end

    def process_event(processor, id, event)
      @logger.info event: :start_processing, id: id
      processor.process(event)
      @redis.xack(@topic, @group, id)
      @logger.info event: :finish_processing, id: id
    rescue StandardError => e
      @logger.error event: :failed_processing, id: id, error: e.message
    end

    def process_failed_events(processor)
      @redis.xpending(@topic, @group, '-', '+', BATCH_SIZE).each do |event|
        id = event['entry_id']
        retries = event['count']
        idle_timeout = @backoff.timeout_ms(retries)

        failed = @redis.xclaim(@topic, @group, @consumer, idle_timeout.to_int, id)[0]
        next if failed.nil?

        @logger.info event: :retrying_event, retries: retries, id: id
        process_event(processor, id, JSON.parse(failed[1]['json']))
      end
    end

    def process_unseen(processor)
      events = @redis.xreadgroup(@group, @consumer, @topic, '>', count: BATCH_SIZE, block: @block)
      return if events == {}

      events.fetch(@topic).each { |id, event| process_event(processor, id, JSON.parse(event['json'])) }
    end
  end
end
