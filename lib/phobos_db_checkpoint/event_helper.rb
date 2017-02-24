module PhobosDBCheckpoint
  module EventHelper
    def configured_listener
      listener = Phobos
        .config
        .listeners
        .find { |l| l.group_id == self.group_id }

      raise(ListenerNotFoundError, self.group_id) unless listener

      listener
    end

    def configured_handler
      configured_listener
        .handler
        .constantize
    end

    def fetch_entity_id
      handler = configured_handler.new
      handler.entity_id if handler.respond_to?(:entity_id)
    end

    def fetch_event_time
      handler = configured_handler.new
      handler.event_time if handler.respond_to?(:event_time)
    end

    def fetch_event_type
      handler = configured_handler.new
      handler.event_type if handler.respond_to?(:event_type)
    end

    def fetch_event_version
      handler = configured_handler.new
      handler.event_version if handler.respond_to?(:event_version)
    end
  end
end
