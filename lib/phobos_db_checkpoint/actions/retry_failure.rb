# frozen_string_literal: true

module PhobosDBCheckpoint
  class RetryFailure
    include PhobosDBCheckpoint::Handler

    def initialize(failure)
      @failure = failure
      @action_taken = nil
    end

    def perform
      around_consume(payload, metadata) do
        @action_taken = handler.consume(payload, metadata)
      end

      @failure.destroy
      @action_taken
    end

    private

    def payload
      @failure.payload.to_json
    end

    def metadata
      @failure.metadata.merge(retry_count: 0)
    end

    def handler
      @failure
        .configured_handler
        .new
    end
  end
end
