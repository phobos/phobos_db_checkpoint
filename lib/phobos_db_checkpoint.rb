# frozen_string_literal: true

require 'yaml'
require 'digest'
require 'active_record'
require 'phobos'

require 'phobos_db_checkpoint/event_helper'
require 'phobos_db_checkpoint/version'
require 'phobos_db_checkpoint/errors'
require 'phobos_db_checkpoint/event_actions'
require 'phobos_db_checkpoint/event'
require 'phobos_db_checkpoint/failure'
require 'phobos_db_checkpoint/handler'
require 'phobos_db_checkpoint/actions/retry_failure'

module PhobosDBCheckpoint
  DEFAULT_DB_DIR = 'db'
  DEFAULT_MIGRATION_PATH = File.join(DEFAULT_DB_DIR, 'migrate').freeze
  DEFAULT_DB_CONFIG_PATH = 'config/database.yml'
  DEFAULT_POOL_SIZE = 5

  class << self
    attr_reader :db_config
    attr_accessor :db_config_path, :db_dir, :migration_path

    # :nodoc:
    # ActiveRecord hook
    def table_name_prefix
      :phobos_db_checkpoint_
    end

    def configure(options = {})
      deprecate('options are deprecated, use configuration files instead') if options.keys.any?

      load_db_config
      at_exit { PhobosDBCheckpoint.close_db_connection }
      PhobosDBCheckpoint.establish_db_connection
    end

    def env
      ENV['RAILS_ENV'] ||= ENV['RACK_ENV'] ||= 'development'
    end

    def load_db_config(options = {})
      deprecate('options are deprecated, use configuration files instead') if options.keys.any?

      @db_config_path ||= ENV['DB_CONFIG'] || DEFAULT_DB_CONFIG_PATH

      @db_config = configs[env]

      @db_config.merge!('pool' => pool_size || DEFAULT_POOL_SIZE)
    end

    def pool_size
      pool = @db_config['pool']
      pool = number_of_concurrent_listeners + DEFAULT_POOL_SIZE if pool.nil? && Phobos.config
      pool
    end

    def configs
      conf = File.read(File.expand_path(@db_config_path))
      erb = ERB.new(conf).result

      YAML.safe_load(erb, [], [], true)
    end

    def establish_db_connection
      ActiveRecord::Base.establish_connection(db_config)
    end

    # rubocop:disable Lint/HandleExceptions
    def close_db_connection
      ActiveRecord::Base.connection_pool.disconnect!
    rescue ActiveRecord::ConnectionNotEstablished
    end
    # rubocop:enable Lint/HandleExceptions

    def load_tasks
      @db_dir ||= DEFAULT_DB_DIR
      @migration_path ||= DEFAULT_MIGRATION_PATH

      ActiveRecord::Tasks::DatabaseTasks.send(:define_method, :db_dir) do
        PhobosDBCheckpoint.db_dir
      end

      ActiveRecord::Tasks::DatabaseTasks.send(:define_method, :migrations_paths) do
        [PhobosDBCheckpoint.migration_path]
      end

      ActiveRecord::Tasks::DatabaseTasks.send(:define_method, :env) do
        PhobosDBCheckpoint.env
      end

      require 'phobos_db_checkpoint/tasks'
    end

    def number_of_concurrent_listeners
      Phobos.config.listeners.map { |listener| listener.max_concurrency || 1 }.inject(&:+) || 0
    end

    def deprecate(message)
      warn "DEPRECATION WARNING: #{message} #{Kernel.caller.first}"
    end
  end
end
