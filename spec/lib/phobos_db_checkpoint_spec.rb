require 'spec_helper'

RSpec.describe PhobosDBCheckpoint do
  describe '.configure' do
    it 'loads db config and establish the connection' do
      expect(PhobosDBCheckpoint)
        .to receive(:load_db_config)
        .and_call_original

      expect(ActiveRecord::Base)
        .to receive(:establish_connection)
        .with(hash_including('database' => 'phobos-db-checkpoint-test'))

      PhobosDBCheckpoint.configure
    end
  end

  describe '.load_db_config' do
    it 'loads db config for the configured environment' do
      PhobosDBCheckpoint.load_db_config
      expect(PhobosDBCheckpoint.db_config).to_not be_nil
      expect(PhobosDBCheckpoint.db_config).to include('database' => 'phobos-db-checkpoint-test')
      PhobosDBCheckpoint.db_config.delete('pool')
    end

    it 'configure pool size based on max_concurrency' do
      allow(Phobos)
        .to receive(:config)
        .and_return(Phobos::DeepStruct.new(
          listeners: [
            { max_concurrency: 2 },
            { }, # default 1
            { max_concurrency: 12 }
          ]
        ))

      PhobosDBCheckpoint.load_db_config
      # 2 + 1 + 12 + 5 (add 5 extra connections to the 15 from listeners)
      expect(PhobosDBCheckpoint.db_config['pool']).to eql 20
    end

    context 'when using erb syntax in configuration file' do
      before do
        @previous_conf = PhobosDBCheckpoint.instance_variable_get(:@db_config)
        @previous_path = PhobosDBCheckpoint.instance_variable_get(:@db_config_path)
        PhobosDBCheckpoint.instance_variable_set(:@db_config_path, 'spec/fixtures/database.yml.erb')
      end

      after do
        PhobosDBCheckpoint.instance_variable_set(:@db_config, @previous_conf)
        PhobosDBCheckpoint.instance_variable_set(:@db_config_path, @previous_path)
      end

      it 'parses it correctly' do
        PhobosDBCheckpoint.load_db_config
        expect(PhobosDBCheckpoint.db_config['database']).to eq('InjectedThroughERB')
      end
    end
  end

  describe '.env' do
    after { ENV['RAILS_ENV'] = ENV['RACK_ENV'] = 'test' }

    it 'returns "development" by default' do
      ENV['RAILS_ENV'] = ENV['RACK_ENV'] = nil
      expect(PhobosDBCheckpoint.env).to eql 'development'
    end

    it 'when RACK_ENV is defined and RAILS_ENV undefined' do
      ENV['RAILS_ENV'] = nil
      ENV['RACK_ENV'] = 'test1'
      expect(PhobosDBCheckpoint.env).to eql 'test1'
    end

    it 'when RAILS_ENV is defined' do
      ENV['RAILS_ENV'] = 'test2'
      expect(PhobosDBCheckpoint.env).to eql 'test2'
    end
  end

  describe '.close_db_connection!' do
    let(:connection_pool) { double('ConnectionPool', disconnect!: true) }
    before { expect(ActiveRecord::Base).to receive(:connection_pool).and_return(connection_pool) }

    describe 'when db is connected' do
      it 'calls disconnect!' do
        expect(connection_pool).to receive(:disconnect!)
        expect { PhobosDBCheckpoint.close_db_connection }.to_not raise_error
      end
    end

    describe 'when the pool automatically closes the connection' do
      it "doesn't raise any errors" do
        expect(connection_pool).to receive(:disconnect!).and_raise(ActiveRecord::ConnectionNotEstablished)
        expect { PhobosDBCheckpoint.close_db_connection }.to_not raise_error
      end
    end
  end

  describe '.load_tasks' do
    after do
      PhobosDBCheckpoint.db_dir = nil
      PhobosDBCheckpoint.migration_path = nil
    end

    it 'sets db_dir to DEFAULT_DB_DIR if not set' do
      PhobosDBCheckpoint.db_dir = nil
      PhobosDBCheckpoint.load_tasks
      expect(PhobosDBCheckpoint.db_dir).to eql PhobosDBCheckpoint::DEFAULT_DB_DIR

      PhobosDBCheckpoint.db_dir = 'other'
      PhobosDBCheckpoint.load_tasks
      expect(PhobosDBCheckpoint.db_dir).to eql 'other'
    end

    it 'sets migration_path to DEFAULT_MIGRATION_PATH if not set' do
      PhobosDBCheckpoint.migration_path = nil
      PhobosDBCheckpoint.load_tasks
      expect(PhobosDBCheckpoint.migration_path).to eql PhobosDBCheckpoint::DEFAULT_MIGRATION_PATH

      PhobosDBCheckpoint.migration_path = 'other'
      PhobosDBCheckpoint.load_tasks
      expect(PhobosDBCheckpoint.migration_path).to eql 'other'
    end

    it 'redefines ActiveRecord::Tasks::DatabaseTasks to return db_dir' do
      PhobosDBCheckpoint.db_dir = 'phobos_db_checkpoint'
      PhobosDBCheckpoint.load_tasks
      expect(ActiveRecord::Tasks::DatabaseTasks.db_dir).to eql 'phobos_db_checkpoint'
    end

    it 'redefines ActiveRecord::Tasks::DatabaseTasks to return migrations_path' do
      PhobosDBCheckpoint.migration_path = 'phobos_migration_path'
      PhobosDBCheckpoint.load_tasks
      expect(ActiveRecord::Tasks::DatabaseTasks.migrations_paths).to eql ['phobos_migration_path']
    end

    it 'redefines ActiveRecord::Tasks::DatabaseTasks to return env' do
      PhobosDBCheckpoint.load_tasks
      expect(ActiveRecord::Tasks::DatabaseTasks.env).to eql PhobosDBCheckpoint.env
    end
  end
end
