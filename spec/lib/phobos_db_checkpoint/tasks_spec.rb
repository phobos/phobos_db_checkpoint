require 'spec_helper'
require 'phobos_db_checkpoint/tasks'

RSpec.describe PhobosDBCheckpoint::Tasks do

  it 'loads db tasks' do
    expect(Rake.application.tasks.map(&:name))
      .to include *%w(
        db:create
        db:drop
        db:environment:set
        db:fixtures:load
        db:migrate
        db:migrate:status
        db:rollback
        db:schema:cache:clear
        db:schema:cache:dump
        db:schema:dump
        db:schema:load
        db:seed
        db:setup
        db:structure:dump
        db:structure:load
        db:version
      )
  end

  describe 'db:load_config' do
    it 'configures ActiveRecord::Tasks::DatabaseTasks.database_configuration' do
      Rake.application['db:load_config'].invoke
      expect(ActiveRecord::Tasks::DatabaseTasks.database_configuration)
        .to eql('test' => PhobosDBCheckpoint.db_config.merge('pool' => 1))
    end
  end

end
