require 'spec_helper'
require 'securerandom'
require 'json'

RSpec.describe PhobosDBCheckpoint::Handler, type: :db do
  class TestPhobosDbCheckpointHander
    include PhobosDBCheckpoint::Handler
  end

  let(:handler) { TestPhobosDbCheckpointHander.new }
  let(:entity_id) { SecureRandom.uuid }
  let(:event_time) { Time.now.utc }
  let(:event_type) { 'event-type' }
  let(:event_version) { 'v1' }

  it 'exposes Phobos::Handler.start' do
    expect(TestPhobosDbCheckpointHander).to respond_to :start
  end

  it 'exposes Phobos::Handler.stop' do
    expect(TestPhobosDbCheckpointHander).to respond_to :stop
  end

  describe '#consume' do
    let(:topic) { 'test' }
    let(:group_id) { 'group1' }

    let(:ack) do
      PhobosDBCheckpoint::Ack.new(
        entity_id,
        event_time,
        event_type,
        event_version
      )
    end

    let(:payload) { Hash(key: 'value').to_json }
    let(:metadata) { Hash(topic: topic, group_id: group_id) }

    def run_handler
      TestPhobosDbCheckpointHander.around_consume(payload, metadata) do
        handler.consume(payload, metadata)
      end
    end

    describe 'when returning ack' do
      before do
        expect(handler).to receive(:consume).and_return(ack)
      end

      it 'persists the event with ack data' do
        expect(PhobosDBCheckpoint::Event.count).to eql 0
        run_handler
        event = PhobosDBCheckpoint::Event.last
        expect(event).to_not be_nil
        expect(event.entity_id).to eql entity_id
        expect(event.event_time.strftime('%F %T')).to eql event_time.strftime('%F %T')
        expect(event.event_type).to eql event_type
        expect(event.event_version).to eql event_version

        expect(event.topic).to eql topic
        expect(event.group_id).to eql group_id
      end

      it 'publish "db_checkpoint.event_acknowledged" with the checksum' do
        expect(TestPhobosDbCheckpointHander)
          .to receive(:instrument)
          .with('db_checkpoint.event_acknowledged', hash_including(:checksum))

        run_handler
      end
    end

    describe 'when the event already exists' do
      before do
        expect(handler)
          .to receive(:consume)
          .once
          .and_return(ack)
      end

      it 'skips consume' do
        2.times {
          run_handler
          expect(PhobosDBCheckpoint::Event.count).to eql 1
        }
      end

      it 'publish "db_checkpoint.event_already_consumed" with the checksum' do
        run_handler

        expect(TestPhobosDbCheckpointHander)
          .to receive(:instrument)
          .with('db_checkpoint.event_already_consumed', hash_including(:checksum))

        run_handler
      end
    end

    describe 'when returning something different' do
      before do
        expect(handler).to receive(:consume).and_return(:skip)
      end

      it 'does not save' do
        expect(PhobosDBCheckpoint::Event.count).to eql 0
        run_handler
        expect(PhobosDBCheckpoint::Event.count).to eql 0
      end

      it 'publish "db_checkpoint.event_skipped"' do
        expect(TestPhobosDbCheckpointHander)
          .to receive(:instrument)
          .with('db_checkpoint.event_skipped', anything)

        run_handler
      end
    end

    it 'returns db connections back to the connection pool' do
      expect(ActiveRecord::Base).to receive(:clear_active_connections!)
      expect(handler).to receive(:consume).and_return(ack)
      run_handler
    end
  end

  describe '#ack' do
    it 'returns a new instance of PhobosDBCheckpoint::Ack' do
      ack = handler.ack(entity_id, event_time, event_type, event_version)
      expect(ack).to be_an_instance_of(PhobosDBCheckpoint::Ack)
      expect(ack.entity_id).to eql entity_id
      expect(ack.event_time).to eql event_time
      expect(ack.event_type).to eql event_type
      expect(ack.event_version).to eql event_version
    end
  end
end
