module PhobosDBCheckpoint
  module EventHelper
    def configured_handler
      Phobos
        .config
        .listeners
        .find { |l| l.group_id == self.group_id }
        .handler
        .constantize
    rescue NoMethodError => e
      raise(HandlerNotFoundError, self.group_id) if e.message =~ /handler/
      raise e
    end
  end
end
