# frozen_string_literal: true

require 'schooling/version'
require 'schooling/logger'
require 'schooling/backoff'
require 'redis'
require 'json'

module Schooling
  class Stream
    SECS = 1000

    DEFAULT_CAP = 10_000 # Max events stored
    DEFAULT_BLOCK = 2 * SECS

    def initialize(
          topic:,
          group:,
          consumer:,
          processor:,
          cap: DEFAULT_CAP,
          block: DEFAULT_BLOCK,
          backoff: Schooling::ExponentialBackoff.new,
          logger: Schooling::CliLogger.new(level: :debug)
        )
      @redis = Redis.new

      # Settings
      @topic = topic
      @group = group
      @consumer = consumer
      @processor = processor
      @cap = cap
      @block = block

      # Behavior
      @backoff = backoff
      @logger = logger
    end

    def create_group
      @logger.info event: :group_create, topic: @topic, name: @group
      @redis.xgroup(:create, @topic, @group, '$')
    end

    def list_groups
      @redis.xinfo(:groups, @topic)
    end

    def count
      @redis.xlen(@topic)
    end

    def publish(body)
      @logger.debug event: :publish, topic: @topic
      @redis.xadd(@topic, { json: JSON.dump(body) }, maxlen: ['~', @cap])
    end

    def process_batch
      unless topic_exists?
        return @logger.error event: :topic_not_created, error: 'Please create the topic first'
      end

      process_failed_events
      process_unseen
    end

    private

    def topic_exists?
      @logger.debug event: :check_topic_exists
      @redis.xinfo(:stream, @topic)
    rescue Redis::CommandError
      @logger.error event: :topic_not_created
      false
    end

    def process_failed_events
      @logger.debug event: :checking_pending

      @redis.xpending(@topic, @group, '-', '+', @cap).each do |event|
        id = event['entry_id']
        retries = event['count']
        elapsed = event['elapsed']
        idle_timeout = @backoff.timeout_ms(retries)

        failed = @redis.xclaim(@topic, @group, @consumer, idle_timeout.to_int, id)[0]
        unless failed.nil?
          @logger.info event: :retrying_event, retries: retries, elapsed: elapsed
          @logger.info event: :processing, id: id
          @processor.process(JSON.parse(failed[1]['json']))
          @redis.xack(@topic, @group, id)
        end
      rescue StandardError => e
        @logger.error event: :failed_processing, id: id, error: e.message
      end
    end

    def process_unseen
      @logger.info event: :polling, topic: @topic, group: @topic, name: @consumer
      events = @redis.xreadgroup(@group, @consumer, @topic, '>', count: @cap, block: @block)
      return if events == {}

      events.fetch(@topic).each do |id, event|
        @logger.info event: :processing, id: id
        @processor.process(JSON.parse(event['json']))
        @redis.xack(@topic, @group, id)
      rescue StandardError => e
        @logger.error event: :failed_processing, id: id, error: e.message
      end
    end
  end
end
