# frozen_string_literal: true

require 'spec_helper'
require 'phobos_db_checkpoint/middleware/logger'

describe PhobosDBCheckpoint::Middleware::Logger do
  class TestPhobosDbCheckpointLoggerMiddlewareApp
    def call(request_env); end
  end

  let(:app) { TestPhobosDbCheckpointLoggerMiddlewareApp.new }
  let(:status) { 200 }
  let(:headers) { Hash('Content-Length' => 10) }
  let(:body) { [Hash(message: 'lorem ipsum').to_json] }
  let(:app_response) { [status, headers, body] }
  let(:options) { Hash(config: 'spec/phobos.test.yml', log_file: 'spec/log/api.log') }

  subject { PhobosDBCheckpoint::Middleware::Logger.new(app, options) }

  before do
    Phobos.silence_log = false
    FileUtils.rm_rf('spec/log')
    allow(app).to receive(:call).and_return(app_response)
  end

  after do
    FileUtils.rm_rf('spec/log')
  end

  let :request_env do
    {
      'REMOTE_ADDR': '127.0.0.1',
      'HTTP_VERSION' => '1.1',
      'PATH_INFO' => '/path',
      'REQUEST_METHOD' => 'GET',
      'QUERY_STRING' => 'attr1=val&attr2=val',
      'CONTENT_LENGTH' => 10
    }
  end

  let :last_log_line do
    File.read(options[:log_file])
        .split("\n")
        .last
  end

  it 'writes the request log to the logger file' do
    subject.call(request_env).last.close
    log = JSON.parse(last_log_line)['message']

    expect(log['remote_address']).to eql request_env['REMOTE_ADDR']
    expect(log['remote_user']).to eql request_env['REMOTE_USER']
    expect(log['request_method']).to eql request_env['REQUEST_METHOD']
    expect(log['path']).to eql '/path?attr1=val&attr2=val 1.1'
    expect(log['status']).to eql '200'
    expect(log['content_length']).to eql request_env['CONTENT_LENGTH']
    expect(log['request_time']).to_not be_nil
  end

  it 'sets "rack.logger" to Phobos.logger' do
    expect(request_env['rack.logger']).to be_nil
    subject.call(request_env)
    expect(request_env['rack.logger']).to eql Phobos.logger
  end

  context 'when request_env has HTTP_X_FORWARDED_FOR instead of REMOTE_ADDR' do
    it 'writes remote_address as HTTP_X_FORWARDED_FOR' do
      subject.call(request_env.merge('HTTP_X_FORWARDED_FOR' => '10.10.10.10')).last.close
      log = JSON.parse(last_log_line)['message']
      expect(log['remote_address']).to eql '10.10.10.10'
    end
  end

  context 'when "sinatra.error" is defined' do
    let(:status) { 500 }

    it 'writes the exception' do
      error = StandardError.new('some error!')
      subject.call(request_env.merge('sinatra.error' => error)).last.close
      log = JSON.parse(last_log_line)['message']

      expect(log['status']).to eql '500'
      expect(log['exception_class']).to eql StandardError.to_s
      expect(log['exception_message']).to eql error.message
      expect(log['backtrace']).to eql error.backtrace
    end
  end
end
