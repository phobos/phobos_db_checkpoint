require 'rake'

module PhobosDBCheckpoint
  module Tasks
    extend Rake::DSL if defined? Rake::DSL

    namespace :db do
      task :environment do
        PhobosDBCheckpoint.configure
      end

      task :load_config do
        PhobosDBCheckpoint.load_db_config
        task_db_config = Hash[PhobosDBCheckpoint.env, PhobosDBCheckpoint.db_config.merge('pool' => 1)]
        ActiveRecord::Tasks::DatabaseTasks.database_configuration = task_db_config
      end
    end

    load 'active_record/railties/databases.rake'
  end
end
