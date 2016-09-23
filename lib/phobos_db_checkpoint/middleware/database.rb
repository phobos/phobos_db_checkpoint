module PhobosDBCheckpoint
  module Middleware
    class Database

      def initialize(app, options = {})
        @app = app
        pool_size = options.fetch(:pool_size, PhobosDBCheckpoint::DEFAULT_POOL_SIZE)
        PhobosDBCheckpoint.configure(pool_size: pool_size)
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
