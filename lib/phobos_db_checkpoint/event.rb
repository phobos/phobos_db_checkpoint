module PhobosDBCheckpoint
  class Event < ActiveRecord::Base
    after_initialize :assign_checksum

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

    def configured_handler
      Phobos
        .config
        .listeners
        .find { |listener| listener.group_id == self.group_id }
        &.handler
    end

    private

    def assign_checksum
      self.checksum ||= Digest::MD5.hexdigest(payload.to_json) if payload
    end
  end
end
