require 'spec_helper'

RSpec.describe PhobosDBCheckpoint do
  before do
    PhobosDBCheckpoint.db_config_path = 'spec/fixtures/database.test.yml'
  end

  describe '.configure' do
    it 'loads db config and establish the connection' do
      expect(PhobosDBCheckpoint)
        .to receive(:load_db_config)
        .and_call_original

      expect(ActiveRecord::Base)
        .to receive(:establish_connection)
        .with(PhobosDBCheckpoint.db_config)

      PhobosDBCheckpoint.configure
    end
  end

  describe '.load_db_config' do
    it 'loads db config for the configured environment' do
      PhobosDBCheckpoint.load_db_config
      expect(PhobosDBCheckpoint.db_config).to_not be_nil
      expect(PhobosDBCheckpoint.db_config).to include('database' => 'phobos-db-checkpoint-test')
    end
  end

  describe '.env' do
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
    describe 'when db is connected and active' do
      it 'calls disconnect!' do
        connection = double('DBConnection', disconnect!: true, disable_referential_integrity: true)
        expect(ActiveRecord::Base).to receive(:connection).and_return(connection)
        expect { PhobosDBCheckpoint.close_db_connection }.to_not raise_error
      end
    end

    describe 'when db is connected and not active' do
      it "doesn't raise any errors" do
        expect(ActiveRecord::Base).to receive(:connection).and_return(nil)
        expect { PhobosDBCheckpoint.close_db_connection }.to_not raise_error
      end
    end

    describe 'when the pool automatically closes the connection' do
      it "doesn't raise any errors" do
        expect(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)
        expect { PhobosDBCheckpoint.close_db_connection }.to_not raise_error
      end
    end
  end

end
