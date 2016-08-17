require 'bundler/setup'
require 'phobos_db_checkpoint'
PhobosDBCheckpoint.configure
PhobosDBCheckpoint.load_tasks
Rake.application['db:migrate'].invoke
