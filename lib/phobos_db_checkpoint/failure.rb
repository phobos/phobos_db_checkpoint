module PhobosDBCheckpoint
  class Failure < ActiveRecord::Base
    include PhobosDBCheckpoint::EventHelper

    scope :order_by_event_time_or_created_at, -> {
      order('CASE WHEN event_time IS NOT NULL THEN event_time ELSE created_at END desc NULLS LAST')
    }

    def self.record(event:, event_metadata:, exception: nil)
      return if exists?(event_metadata[:checksum])

      create do |record|
        record.topic           = event_metadata[:topic]
        record.group_id        = event_metadata[:group_id]
        record.entity_id       = event.fetch_entity_id
        record.event_time      = event.fetch_event_time
        record.event_type      = event.fetch_event_type
        record.event_version   = event.fetch_event_version
        record.checksum        = event_metadata[:checksum]
        record.payload         = event.payload
        record.metadata        = event_metadata
        record.error_class     = exception&.class&.name
        record.error_message   = exception&.message
        record.error_backtrace = exception&.backtrace
      end
    end

    def self.exists?(checksum)
      where(checksum: checksum).exists?
    end

    def payload
      attributes['payload'].deep_symbolize_keys
    end

    def metadata
      attributes['metadata'].deep_symbolize_keys
    end

    def group_id
      attributes['group_id'] || metadata[:group_id]
    end
  end
end
