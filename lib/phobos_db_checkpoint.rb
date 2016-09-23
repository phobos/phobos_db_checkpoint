require 'yaml'
require 'digest'
require 'active_record'
require 'phobos'

require 'phobos_db_checkpoint/version'
require 'phobos_db_checkpoint/event_actions'
require 'phobos_db_checkpoint/event'
require 'phobos_db_checkpoint/handler'

module PhobosDBCheckpoint
  DEFAULT_DB_DIR = 'db'.freeze
  DEFAULT_MIGRATION_PATH = File.join(DEFAULT_DB_DIR, 'migrate').freeze
  DEFAULT_DB_CONFIG_PATH = 'config/database.yml'.freeze
  DEFAULT_POOL_SIZE = 5.freeze

  class << self
    attr_reader :db_config
    attr_accessor :db_config_path, :db_dir, :migration_path

    def configure(pool_size: nil)
      load_db_config(pool_size: pool_size)
      at_exit { PhobosDBCheckpoint.close_db_connection }
      ActiveRecord::Base.establish_connection(db_config)
    end

    def env
      ENV['RAILS_ENV'] ||= ENV['RACK_ENV'] ||= 'development'
    end

    def load_db_config(pool_size: nil)
      @db_config_path ||= DEFAULT_DB_CONFIG_PATH
      configs = YAML.load_file(File.expand_path(@db_config_path))
      @db_config = configs[env]

      if pool_size.nil? && Phobos.config
        pool_size = Phobos.config.listeners.map { |listener| listener.max_concurrency || 1 }.inject(&:+)
      end

      @db_config.merge!('pool' => pool_size || DEFAULT_POOL_SIZE)
    end

    def close_db_connection
      ActiveRecord::Base.connection_pool.disconnect!
    rescue ActiveRecord::ConnectionNotEstablished
    end

    def load_tasks
      @db_dir ||= DEFAULT_DB_DIR
      @migration_path ||= DEFAULT_MIGRATION_PATH
      ActiveRecord::Tasks::DatabaseTasks.send(:define_method, :db_dir) { PhobosDBCheckpoint.db_dir }
      ActiveRecord::Tasks::DatabaseTasks.send(:define_method, :migrations_paths) { [PhobosDBCheckpoint.migration_path] }
      ActiveRecord::Tasks::DatabaseTasks.send(:define_method, :env) { PhobosDBCheckpoint.env }
      require 'phobos_db_checkpoint/tasks'
    end
  end
end
