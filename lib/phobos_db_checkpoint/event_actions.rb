# frozen_string_literal: true

module PhobosDBCheckpoint
  Ack = Struct.new(:entity_id, :event_time, :event_type, :event_version)
end
