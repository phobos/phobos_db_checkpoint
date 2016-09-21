require 'spec_helper'
require 'rack/test'
require 'phobos_db_checkpoint/events_api'

describe PhobosDBCheckpoint::EventsAPI, type: :db do
  include Rack::Test::Methods

  def app
    PhobosDBCheckpoint::EventsAPI
  end

  def create_event(entity_id: SecureRandom.uuid, event_type: 'event-type', topic: 'test', group_id: 'test-checkpoint', event_time: Time.now, payload: {})
    PhobosDBCheckpoint::Event.create(
      topic: topic,
      group_id: group_id,
      entity_id: entity_id,
      event_type: event_type,
      event_time: event_time,
      payload: {data: SecureRandom.uuid}.merge(payload).to_json
    )
  end

  let!(:event) { create_event }

  before do
    Phobos.silence_log = true
    Phobos.configure('spec/phobos.test.yml')
  end

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
        get "/v1/events/not-found"
        expect(last_response.status).to eql 404
        expect(last_response.body).to eql Hash(error: true, message: 'event not found').to_json
      end
    end
  end

  describe 'POST /v1/events/:id/retry' do
    let(:handler) { Phobos::EchoHandler.new }
    let :ack do
      PhobosDBCheckpoint::Ack.new(SecureRandom.uuid, Time.now, nil, nil)
    end

    before do
      allow(Phobos::EchoHandler).to receive(:new).and_return(handler)
    end

    it 'calls the configured handler with event payload' do
      expect(handler)
        .to receive(:consume)
        .with(event.payload, hash_including(topic: event.topic, group_id: event.group_id, retry_count: 0))
        .and_return(ack)

      post "/v1/events/#{event.id}/retry"
      expect(last_response.body).to eql Hash(acknowledged: true).to_json
    end

    context 'when handler returns something different than PhobosDBCheckpoint::Ack' do
      it 'returns acknowledged false' do
        expect(handler)
          .to receive(:consume)
          .and_return('not-ack')

        post "/v1/events/#{event.id}/retry"
        expect(last_response.body).to eql Hash(acknowledged: false).to_json
      end
    end

    context 'when handler is configured anymore' do
      it 'returns 422' do
        event.group_id = 'another-group'
        event.save

        post "/v1/events/#{event.id}/retry"
        expect(last_response.status).to eql 422
        expect(last_response.body).to eql Hash(error: true, message: 'no handler configured for this event').to_json
      end
    end

    context 'when the event does not exist' do
      it 'returns 404' do
        post "/v1/events/not-found/retry"
        expect(last_response.status).to eql 404
        expect(last_response.body).to eql Hash(error: true, message: 'event not found').to_json
      end
    end
  end

  describe 'GET /v1/events' do
    before do
      event.delete
      create_event(entity_id: '1', payload: {mark: '|A|'}, topic: 'test2', event_type: 'special')
      create_event(entity_id: '1', payload: {mark: '|B|'}, event_time: Time.now + 1000)
      create_event(entity_id: '2', payload: {mark: '|C|'}, event_time: Time.now + 2000)
    end

    context 'when called without arguments' do
      it 'returns the X most recent events' do
        get '/v1/events?limit=2'
        body = last_response.body
        expect(JSON.parse(body).length).to eql 2
        expect(body).to include '|B|'
        expect(body).to include '|C|'
        expect(body).to_not include '|A|'
      end
    end

    context 'when called with "offset"' do
      it 'returns the X most recent events in the correct offset' do
        get '/v1/events?limit=2&offset=2'
        body = last_response.body
        expect(JSON.parse(body).length).to eql 1
        expect(body).to_not include '|B|'
        expect(body).to_not include '|C|'
        expect(body).to include '|A|'
      end
    end

    context 'when called with "entity_id"' do
      it 'returns the X most recent events filtered by entity_id' do
        get '/v1/events?limit=100&entity_id=1'
        body = last_response.body
        expect(JSON.parse(body).length).to eql 2
        expect(body).to include '|A|'
        expect(body).to include '|B|'
      end
    end

    context 'when called with "topic"' do
      it 'returns the X most recent events filtered by topic' do
        get '/v1/events?limit=100&topic=test2'
        body = last_response.body
        expect(JSON.parse(body).length).to eql 1
        expect(body).to include '|A|'
      end
    end

    context 'when called with "group_id"' do
      it 'returns the X most recent events filtered by group_id' do
        get '/v1/events?limit=100&group_id=test-checkpoint'
        body = last_response.body
        expect(JSON.parse(body).length).to eql 3
        expect(body).to include '|A|'
        expect(body).to include '|B|'
        expect(body).to include '|C|'
      end
    end

    context 'when called with "event_type"' do
      it 'returns the X most recent events filtered by event_type' do
        get '/v1/events?limit=100&event_type=special'
        body = last_response.body
        expect(JSON.parse(body).length).to eql 1
        expect(body).to include '|A|'
      end
    end
  end
end
