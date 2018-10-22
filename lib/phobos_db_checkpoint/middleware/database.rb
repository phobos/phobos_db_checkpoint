# frozen_string_literal: true

module PhobosDBCheckpoint
  module Middleware
    class Database
      def initialize(app, options = {})
        @app = app
        if options.keys.any?
          PhobosDBCheckpoint.deprecate('options are deprecated, use configuration files instead')
        end
        PhobosDBCheckpoint.configure
      end

      def call(request_env)
        ActiveRecord::Base.connection_pool.with_connection do
          @app.call(request_env)
        end
      ensure
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end
end
