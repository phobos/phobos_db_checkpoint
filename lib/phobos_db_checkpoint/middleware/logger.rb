require 'rack'

module PhobosDBCheckpoint
  module Middleware
    class Logger
      RACK_LOGGER    = 'rack.logger'.freeze
      SINATRA_ERROR  = 'sinatra.error'.freeze
      HTTP_VERSION   = 'HTTP_VERSION'.freeze
      PATH_INFO      = 'PATH_INFO'.freeze
      REQUEST_METHOD = 'REQUEST_METHOD'.freeze
      QUERY_STRING   = 'QUERY_STRING'.freeze
      CONTENT_LENGTH = 'Content-Length'.freeze

      def initialize(app, options = {})
        @app = app
        Phobos.configure(options.fetch(:config, 'config/phobos.yml'))
        Phobos.config.logger.file = options.fetch(:log_file, 'log/api.log')
        Phobos.configure_logger
        ActiveRecord::Base.logger = Phobos.logger
      end

      def call(request_env)
        began_at = Time.now
        request_env[RACK_LOGGER] = Phobos.logger
        status, header, body = @app.call(request_env)
        header = Rack::Utils::HeaderHash.new(header)
        body = Rack::BodyProxy.new(body) do
          log(request_env, status, header, began_at)
        end
        [status, header, body]
      end

      private

      def log(request_env, status, header, began_at)
        error = request_env[SINATRA_ERROR]
        message = {
          remote_address: request_env['HTTP_X_FORWARDED_FOR'] || request_env['REMOTE_ADDR'],
          remote_user: request_env['REMOTE_USER'],
          request_method: request_env[REQUEST_METHOD],
          path: extract_path(request_env),
          status: status.to_s[0..3],
          content_length: extract_content_length(header),
          request_time: "#{Time.now - began_at}s"
        }

        if error
          Phobos.logger.error(message.merge(
            exception_class: error.class.to_s,
            exception_message: error.message,
            backtrace: error.backtrace
          ))
        else
          Phobos.logger.info(message)
        end
      end

      def extract_path(request_env)
        "#{request_env[PATH_INFO]}#{request_env[QUERY_STRING].empty? ? "" : "?#{request_env[QUERY_STRING]}"} #{request_env[HTTP_VERSION]}"
      end

      def extract_content_length(headers)
        value = headers[CONTENT_LENGTH] or return
        value.to_s == '0' ? nil : value
      end
    end
  end
end
