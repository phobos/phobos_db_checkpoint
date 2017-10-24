require 'spec_helper'
require 'phobos_db_checkpoint/middleware/database'

describe PhobosDBCheckpoint::Middleware::Database, type: :db do
  class TestPhobosDbCheckpointDatabaseMiddlewareApp
    def call(request_env); end
  end

  let(:app) { TestPhobosDbCheckpointDatabaseMiddlewareApp.new }
  let(:request_env) { Hash(PATH_INFO: '/path') }
  subject { PhobosDBCheckpoint::Middleware::Database.new(app) }

  it 'calls app.call with request_env' do
    expect(app).to receive(:call).with(request_env)
    subject.call(request_env)
  end

  it 'gives access to a connection from the connection pool' do
    ActiveRecord::Base.clear_active_connections!
    expect(ActiveRecord::Base.connection_pool.active_connection?).to be_nil
    expect(app).to receive(:call) do
      expect(ActiveRecord::Base.connection_pool.active_connection?)
        .to be_a(ActiveRecord::ConnectionAdapters::AbstractAdapter)
    end
    subject.call(request_env)
  end

  it 'returns db connections back to the connection pool' do
    expect(ActiveRecord::Base).to receive(:clear_active_connections!)
    subject.call(request_env)
  end

  it 'does not emit a deprecation warning' do
    expect {
      PhobosDBCheckpoint::Middleware::Database.new(app)
    }.to_not output.to_stderr
  end

  it 'emits a deprecation warning if using any option' do
    expect {
      PhobosDBCheckpoint::Middleware::Database.new(app, { foo: :bar })
    }.to output(/DEPRECATION WARNING: options are deprecated, use configuration files instead/).to_stderr
  end
end
