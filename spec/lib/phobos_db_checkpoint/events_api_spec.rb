# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'phobos_db_checkpoint/events_api'

describe PhobosDBCheckpoint::EventsAPI, type: :db do
  include Rack::Test::Methods

  def app
    PhobosDBCheckpoint::EventsAPI
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def create_event(opts = {})
    PhobosDBCheckpoint::Event.create(
      topic: opts[:topic] || 'test',
      group_id: opts[:group_id] || 'test-checkpoint',
      entity_id: opts[:entity_id] || SecureRandom.uuid,
      event_type: opts[:event_type] || 'event-type',
      event_time: opts[:event_time] || Time.now,
      created_at: opts[:created_at],
      payload: { data: SecureRandom.uuid }.merge(opts[:payload] || {}).to_json
    )
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def create_failure(created_at:, payload:, metadata:, exception: nil)
    PhobosDBCheckpoint::Failure.create(
      created_at: created_at,
      payload: payload,
      metadata: metadata,
      error_class: exception&.class&.name,
      error_message: exception&.class&.message,
      error_backtrace: exception&.class&.backtrace
    )
  end

  let!(:event) { create_event }

  describe 'GET /ping' do
    it 'returns pong' do
      get '/ping'
      expect(last_response.body).to eql 'PONG'
    end
  end

  describe 'GET /v1/events/:id' do
    it 'returns event json' do
      get "/v1/events/#{event.id}"
      expect(last_response.body).to eql event.to_json
    end

    context 'when the event does not exist' do
      it 'returns 404' do
        get '/v1/events/not-found'
        expect(last_response.status).to eql 404
        expect(last_response.body).to eql Hash(error: true, message: 'event not found').to_json
      end
    end
  end

  describe 'GET /v1/events' do
    before do
      event.delete
      create_event(entity_id: '1', payload: { mark: '|A|' }, created_at: Time.now - 300, event_time: nil, topic: 'test2', event_type: 'special')
      create_event(entity_id: '2', payload: { mark: '|B|' }, created_at: Time.now - 200, event_time: Time.now + 1000)
      create_event(entity_id: '3', payload: { mark: '|C|' }, created_at: Time.now - 100, event_time: Time.now + 2000)
      create_event(entity_id: '4', payload: { mark: '|D|' }, created_at: Time.now - 0,   event_time: nil, topic: 'test2', event_type: 'special')
    end

    context 'when called with limit' do
      it 'returns the X most recent events' do
        get '/v1/events?limit=2'
        body = JSON.parse(last_response.body)
        expect(body.pluck('entity_id')).to eq %w[3 2]
      end
    end

    context 'when called with "offset"' do
      it 'returns the X most recent events in the correct offset' do
        get '/v1/events?limit=2&offset=2'
        body = JSON.parse(last_response.body)
        expect(body.pluck('entity_id')).to eq %w[4 1]
      end
    end

    context 'when called with "entity_id"' do
      it 'returns the X most recent events filtered by entity_id' do
        get '/v1/events?limit=100&entity_id=1'
        body = JSON.parse(last_response.body)
        expect(body.pluck('entity_id')).to eq ['1']
      end
    end

    context 'when called with "topic"' do
      it 'returns the X most recent events filtered by topic' do
        get '/v1/events?limit=100&topic=test2'
        body = JSON.parse(last_response.body)
        expect(body.pluck('entity_id')).to eq %w[4 1]
      end
    end

    context 'when called with "group_id"' do
      it 'returns the X most recent events filtered by group_id' do
        get '/v1/events?limit=100&group_id=test-checkpoint'
        body = JSON.parse(last_response.body)
        expect(body.pluck('entity_id')).to eq %w[3 2 4 1]
      end
    end

    context 'when called with "event_type"' do
      it 'returns the X most recent events filtered by event_type' do
        get '/v1/events?limit=100&event_type=special'
        body = JSON.parse(last_response.body)
        expect(body.pluck('entity_id')).to eq %w[4 1]
      end
    end
  end

  describe 'GET /v1/failures/count' do
    let(:now) { Time.parse(Date.today.beginning_of_day.to_s) }

    before do
      3.times do |i|
        PhobosDBCheckpoint::Failure.create do |record|
          record.topic         = "topic-#{i + 1}"
          record.group_id      = "group_id-#{i + 1}"
          record.entity_id     = "entity_id-#{i + 1}"
          record.event_time    = now + i * 3600
          record.event_type    = "event_type-#{i + 1}"
          record.event_version = "event_version-#{i + 1}"
          record.checksum      = "checksum-#{i + 1}"
          record.payload       = Hash('payload' => 'payload')
          record.metadata      = Hash('metadata' => 'metadata')
        end
      end
    end

    it 'returns the number of failures' do
      get '/v1/failures/count'
      body = JSON.parse(last_response.body)
      expect(body).to eq('count' => 3)
    end
  end

  describe 'GET /v1/failures' do
    let(:now) { Time.parse(Date.today.beginning_of_day.to_s) }

    before do
      3.times do |i|
        PhobosDBCheckpoint::Failure.create do |record|
          record.topic         = "topic-#{i + 1}"
          record.group_id      = "group_id-#{i + 1}"
          record.entity_id     = "entity_id-#{i + 1}"
          record.event_time    = now + i * 3600
          record.event_type    = "event_type-#{i + 1}"
          record.event_version = "event_version-#{i + 1}"
          record.checksum      = "checksum-#{i + 1}"
          record.payload       = Hash('payload' => 'payload')
          record.metadata      = Hash('metadata' => 'metadata')
        end
      end
    end

    context 'when called with limit' do
      it 'returns the X most recent failures' do
        get '/v1/failures?limit=2'
        body = JSON.parse(last_response.body)
        expect(body.pluck('topic')).to eq ['topic-3', 'topic-2']
      end
    end

    context 'when called with "offset"' do
      it 'returns the X most recent failures in the correct offset' do
        get '/v1/failures?limit=2&offset=2'
        body = JSON.parse(last_response.body)
        expect(body.pluck('topic')).to eq ['topic-1']
      end
    end

    context 'when called with "topic"' do
      it 'returns the X most recent failures filtered by topic' do
        get '/v1/failures?limit=100&topic=topic-2'
        body = JSON.parse(last_response.body)
        expect(body.pluck('topic')).to eq ['topic-2']
      end
    end

    context 'when called with "group_id"' do
      it 'returns the X most recent failures filtered by group_id' do
        get '/v1/failures?limit=100&group_id=group_id-3'
        body = JSON.parse(last_response.body)
        expect(body.pluck('group_id')).to eq ['group_id-3']
      end
    end

    context 'when called with "entity_id"' do
      it 'returns the X most recent failures filtered by entity_id' do
        get '/v1/failures?limit=100&entity_id=entity_id-3'
        body = JSON.parse(last_response.body)
        expect(body.pluck('entity_id')).to eq ['entity_id-3']
      end
    end

    context 'when called with "event_type"' do
      it 'returns the X most recent failures filtered by event_type' do
        get '/v1/failures?limit=100&event_type=event_type-3'
        body = JSON.parse(last_response.body)
        expect(body.pluck('event_type')).to eq ['event_type-3']
      end
    end
  end

  describe 'GET /v1/failures/:id' do
    let!(:failure) do
      create_failure(
        created_at: 1.hour.ago,
        payload: {
          'data' => 'data'
        },
        metadata: {
          'meta' => 'meta',
          'group_id' => 'test-checkpoint'
        }
      )
    end

    it 'returns event json' do
      get "/v1/failures/#{failure.id}"
      expect(last_response.body).to eql failure.to_json
    end

    context 'when the failure does not exist' do
      it 'returns 404' do
        get '/v1/failures/not-found'
        expect(last_response.status).to eql 404
        expect(last_response.body).to eql Hash(error: true, message: 'failure not found').to_json
      end
    end
  end

  describe 'POST /v1/failures/:id/retry' do
    let(:handler) { Phobos::EchoHandler.new }
    let(:retry_failure_instance) { PhobosDBCheckpoint::RetryFailure.new(failure) }
    let(:group_id) { 'test-checkpoint' }
    let(:failure) do
      create_failure(
        created_at: 1.hour.ago,
        payload: {
          'data' => 'data'
        },
        metadata: {
          'meta' => 'meta',
          'group_id' => group_id
        }
      )
    end

    context 'when handler is configured' do
      before do
        allow(Phobos::EchoHandler).to receive(:new).and_return(handler)
        allow(handler)
          .to receive(:consume)
          .and_return(PhobosDBCheckpoint::Ack.new('aggregate_id', 'creation_time', 'event_type', 'event_version'))
      end

      it 'calls the configured handler with event payload' do
        expect(PhobosDBCheckpoint::RetryFailure)
          .to receive(:new)
          .with(failure)
          .and_return(retry_failure_instance)

        expect(retry_failure_instance)
          .to receive(:perform)
          .and_call_original

        post "/v1/failures/#{failure.id}/retry"
        expect(last_response.body).to eql Hash(acknowledged: true).to_json
      end
    end

    context 'when handler returns something different than PhobosDBCheckpoint::Ack' do
      before do
        allow(Phobos::EchoHandler).to receive(:new).and_return(handler)
      end

      it 'returns acknowledged false' do
        expect(handler)
          .to receive(:consume)
          .and_return('not-ack')

        post "/v1/failures/#{failure.id}/retry"
        expect(last_response.body).to eql Hash(acknowledged: false).to_json
      end
    end

    context 'when handler is not configured anymore' do
      let(:group_id) { 'another-group' }
      it 'returns 422' do
        post "/v1/failures/#{failure.id}/retry"
        expect(last_response.status).to eql 422
        expect(last_response.body).to eql Hash(error: true, message: "Phobos Listener not found for group id 'another-group'").to_json
      end
    end

    context 'when the event does not exist' do
      it 'returns 404' do
        post '/v1/failures/not-found/retry'
        expect(last_response.status).to eql 404
        expect(last_response.body).to eql Hash(error: true, message: 'failure not found').to_json
      end
    end
  end

  describe 'DELETE /v1/failures/:id' do
    let(:failure) do
      create_failure(
        created_at: 1.hour.ago,
        payload: { 'data' => 'data' },
        metadata: { 'meta' => 'meta' }
      )
    end

    it 'returns acknowledged: true' do
      delete "/v1/failures/#{failure.id}"
      expect(last_response.body).to eql Hash(acknowledged: true).to_json
    end

    it 'deletes the failure' do
      delete "/v1/failures/#{failure.id}"
      expect do
        failure.reload
      end.to raise_error ActiveRecord::RecordNotFound
    end
  end

  context 'with not found' do
    it 'returns 404' do
      get '/v1/not-found'
      expect(last_response.status).to eql 404
      expect(last_response.body).to eql Hash(error: true, message: 'not found').to_json
    end
  end

  context 'with errors' do
    it 'returns 500' do
      expect(PhobosDBCheckpoint::Event)
        .to receive(:find)
        .and_raise(StandardError, 'generic error')

      get 'v1/events/1'
      expect(last_response.status).to eql 500
      expect(last_response.body).to eql Hash(error: true, message: 'generic error').to_json
    end
  end
end
