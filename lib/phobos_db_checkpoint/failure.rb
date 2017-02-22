module PhobosDBCheckpoint
  class Failure < ActiveRecord::Base
    def self.record(event_payload:, event_metadata:, exception: nil)
      return if exists?(event_metadata[:checksum])

      create do |record|
        record.payload         = event_payload
        record.metadata        = event_metadata
        record.error_class     = exception&.class&.name
        record.error_message   = exception&.message
        record.error_backtrace = exception&.backtrace
      end
    end

    def self.exists?(checksum)
      where("metadata->>'checksum' = ?", checksum).exists?
    end

    def payload
      attributes['payload'].deep_symbolize_keys
    end

    def metadata
      attributes['metadata'].deep_symbolize_keys
    end

    # Can we delete the failure already at this stage?
    # Since a new error will be created after failing again X times in a row?
    # This would make retrying errors a simple task, one click and forget about it.
    def retry!
      configured_handler
        .new
        .consume(
          payload,
          metadata.merge(retry_count: 0)
        )
    end

    def configured_handler
      Phobos
        .config
        .listeners
        .find { |l| l.group_id == metadata[:group_id] }
        .handler
        .constantize
    rescue NoMethodError => e
      raise(HandlerNotFoundError, metadata[:group_id]) if e.message =~ /handler/
      raise e
    end
  end
end
