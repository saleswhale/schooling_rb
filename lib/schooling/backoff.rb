module Schooling
  class ExponentialBackoff
    SECONDS = 1000
    MIN_TIMEOUT = 30 * SECONDS

    def timeout_ms(retries)
      MIN_TIMEOUT + rand * (2**retries - 1) * SECONDS
    end
  end

  class LinearBackoff
    def timeout_ms(retries)
      MIN_TIMEOUT + retries * SECONDS
    end
  end
end
