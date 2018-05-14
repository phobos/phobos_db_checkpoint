# frozen_string_literal: true

module PhobosDBCheckpoint
  module EventHelper
    def configured_listener
      listener = Phobos
                 .config
                 .listeners
                 .find { |l| l.group_id == group_id }

      raise(ListenerNotFoundError, group_id) unless listener

      listener
    end

    def configured_handler
      configured_listener
        .handler
        .constantize
    end

    def method_missing(m, *args, &block)
      rex = m.to_s.match(/^fetch_(.+)/)

      if rex
        handler = configured_handler.new
        return handler.send(rex[1], payload) if handler.respond_to?(rex[1])
      else
        super
      end
    end
  end
end
