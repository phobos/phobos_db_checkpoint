require 'bundler/setup'
require 'phobos_db_checkpoint'
require 'phobos_db_checkpoint/events_api'
require_relative './phobos_boot.rb'

logger_config = {
  # config: 'config/phobos.yml'
  # log_file: 'log/api.log'
}

database_config = {
  # pool_size: PhobosDBCheckpoint::DEFAULT_POOL_SIZE # 5
}

use PhobosDBCheckpoint::Middleware::Logger, logger_config
use PhobosDBCheckpoint::Middleware::Database, database_config
run PhobosDBCheckpoint::EventsAPI
