module PhobosDBCheckpoint
  Ack = Struct.new(:entity_id, :event_time, :event_type, :event_version)
  Nack = Struct.new(:entity_id, :event_time)
end
