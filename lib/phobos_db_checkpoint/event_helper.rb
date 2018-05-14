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

    def method_missing(method_name, *args, &block)
      if method_name.to_s =~ /^fetch_(.*)/
        method = Regexp.last_match(1)
        handler = configured_handler.new
        handler.send(method, payload) if handler.respond_to?(method)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_name.to_s.start_with?('fetch_') || super
    end
  end
end
