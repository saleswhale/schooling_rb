# frozen_string_literal: true

require 'schooling/backoff'
require 'schooling/logger'

require 'json'

module Schooling
  class Subscriber
    SECS = 1000

    BATCH_SIZE = 1000 # How many events to fetch
    DEFAULT_BLOCK = 2 * SECS

    def initialize(
          redis:,
          topic:,
          group:,
          consumer:,
          processor:,
          block: DEFAULT_BLOCK,
          backoff: Schooling::ExponentialBackoff.new,
          logger: Schooling::CliLogger.new(level: :debug)
        )
      @redis = redis

      # Settings
      @topic = topic
      @group = group
      @consumer = consumer
      @processor = processor
      @block = block

      # Behavior
      @backoff = backoff
      @logger = logger
    end

    def create_group
      @logger.info event: :group_create, topic: @topic, name: @group
      @redis.xgroup(:create, @topic, @group, '$', mkstream: true)
    end

    def list_groups
      check_topic
      @redis.xinfo(:groups, @topic)
    end

    def count
      check_topic
      @redis.xlen(@topic)
    end

    def process_batch
      check_topic
      process_failed_events
      process_unseen
    end

    private

    def check_topic
      return if topic_exists?

      @logger.error event: :topic_not_created, error: 'Please create the topic first'
      raise 'Topic not created'
    end

    def topic_exists?
      @logger.debug event: :check_topic_exists
      @redis.xinfo(:stream, @topic)
    rescue Redis::CommandError
      @logger.error event: :topic_not_created
      false
    end

    def process_event(id, event)
      @logger.info event: :processing, id: id
      @processor.process(event)
      @redis.xack(@topic, @group, id)
    rescue StandardError => e
      @logger.error event: :failed_processing, id: id, error: e.message
    end

    def process_failed_events
      @redis.xpending(@topic, @group, '-', '+', BATCH_SIZE).each do |event|
        id = event['entry_id']
        retries = event['count']
        idle_timeout = @backoff.timeout_ms(retries)

        failed = @redis.xclaim(@topic, @group, @consumer, idle_timeout.to_int, id)[0]
        next if failed.nil?

        @logger.info event: :retrying_event, retries: retries, id: id
        process_event(id, JSON.parse(failed[1]['json']))
      end
    end

    def process_unseen
      events = @redis.xreadgroup(@group, @consumer, @topic, '>', count: BATCH_SIZE, block: @block)
      return if events == {}

      events.fetch(@topic).each { |id, event| process_event(id, JSON.parse(event['json'])) }
    end
  end
end
