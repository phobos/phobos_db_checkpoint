module PhobosDBCheckpoint
  class Event < ActiveRecord::Base
    include PhobosDBCheckpoint::EventHelper
    after_initialize :assign_checksum

    scope :order_by_event_time_and_created_at, -> { order('event_time desc nulls last', 'created_at desc nulls last') }

    def exists?
      Event.where(topic: topic, group_id: group_id, checksum: checksum).exists?
    end

    def acknowledge!(ack)
      self.entity_id = ack.entity_id
      self.event_time = ack.event_time
      self.event_type = ack.event_type
      self.event_version = ack.event_version
      save!
    end

    private

    def assign_checksum
      self.checksum ||= Digest::MD5.hexdigest(payload.to_json) if payload
    end
  end
end
