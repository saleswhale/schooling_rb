# frozen_string_literal: true

module Schooling
  # Prevent logging
  class NullLogger
    def debug(msg); end

    def info(msg); end

    def warn(msg); end

    def error(msg); end
  end

  # Log to stdout
  class CliLogger
    LEVELS = {
      debug: 0,
      info: 1,
      warn: 2,
      error: 3
    }.freeze

    FORMAT = '%<time>s [%<level>s] %<msg>s'

    def initialize(level: :info)
      @level = LEVELS[level]
    end

    def debug(msg)
      output(:debug, msg)
    end

    def info(msg)
      output(:info, msg)
    end

    def warn(msg)
      output(:warn, msg)
    end

    def error(msg)
      output(:error, msg)
    end

    private

    def output(level, msg)
      out = { time: Time.now, level: level, msg: msg }
      puts FORMAT % out if LEVELS[level] >= @level
    end
  end
end
