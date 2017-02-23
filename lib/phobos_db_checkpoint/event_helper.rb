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
  end
end
