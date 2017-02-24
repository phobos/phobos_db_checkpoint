module PhobosDBCheckpoint
  class Failure < ActiveRecord::Base
    include PhobosDBCheckpoint::EventHelper

    scope :by_checksum, -> (val) { where("metadata->>'checksum' = ?", val) }
    scope :by_topic, -> (val) { where("metadata->>'topic' = ?", val) }
    scope :by_group_id, -> (val) { where("metadata->>'group_id' = ?", val) }

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
      by_checksum(checksum).exists?
    end

    def payload
      attributes['payload'].deep_symbolize_keys
    end

    def metadata
      attributes['metadata'].deep_symbolize_keys
    end

    def group_id
      metadata[:group_id]
    end
  end
end
