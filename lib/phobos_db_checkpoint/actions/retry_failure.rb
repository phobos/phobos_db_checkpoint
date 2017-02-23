module PhobosDBCheckpoint
  class RetryFailure
    def initialize(failure)
      @failure = failure
    end

    def perform
      retry_failure!
      @failure.destroy
    end

    private

    def retry_failure!
      handler
        .consume(
          @failure.payload,
          @failure.metadata.merge(retry_count: 0)
        )
    end

    def handler
      @failure
        .configured_handler
        .new
    end
  end
end
