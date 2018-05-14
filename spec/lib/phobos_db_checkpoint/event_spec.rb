# frozen_string_literal: true

require 'spec_helper'

describe PhobosDBCheckpoint::Event, type: :db do
  describe '#payload' do
    let(:payload) { Hash(a: 1, b: 2) }
    subject { PhobosDBCheckpoint::Event.create(payload: payload).reload }

    it 'stores payload as serialized json' do
      expect(subject.payload).to be_a(Hash)
      expect(subject.payload).to eq(JSON(payload.to_json))
    end
  end

  describe '#checksum' do
    it 'is created based on the payload' do
      expect(PhobosDBCheckpoint::Event.new.checksum).to be_nil
      expect(PhobosDBCheckpoint::Event.new(payload: { data: 'A' }.to_json).checksum).to eql 'c1a837e058f7aa037afdf142c013af05'
    end
  end

  describe '#exists?' do
    let(:event) { PhobosDBCheckpoint::Event.new topic: 'A', group_id: 'B', payload: 'data' }

    it 'checks if the event exists' do
      expect(event.exists?).to eql false
      PhobosDBCheckpoint::Event.create topic: 'A', group_id: 'B', payload: 'data'
      expect(event.exists?).to eql true
    end
  end

  describe '#acknowledge!' do
    let(:ack) { PhobosDBCheckpoint::Ack.new('A1B', Time.now, 'event-type', 'v1') }
    let(:event) { PhobosDBCheckpoint::Event.new topic: 'A', group_id: 'B', payload: 'data' }

    it 'assigns data from ack and save' do
      expect(event.exists?).to eql false
      event.acknowledge!(ack)
      expect(event.entity_id).to eql ack.entity_id
      expect(event.event_time).to eql ack.event_time
      expect(event.event_type).to eql ack.event_type
      expect(event.event_version).to eql ack.event_version
      expect(event.exists?).to eql true
    end
  end

  describe '#configured_handler' do
    it 'returns the name of the configured handler for this event' do
      event = PhobosDBCheckpoint::Event.new(group_id: 'test-checkpoint')
      expect(event.configured_handler).to eql Phobos::EchoHandler
    end
  end

  describe '#created_at' do
    let!(:frozen_time) { Time.new(2017, 12, 12, 23, 40, 0o2) }

    it 'sets created_at' do
      allow(Time).to receive(:now).and_return(frozen_time)
      event = PhobosDBCheckpoint::Event.create!
      expect(event.reload.created_at).to eq(frozen_time)
    end
  end

  describe '.order_by_event_time_and_created_at' do
    before do
      PhobosDBCheckpoint::Event.delete_all
      PhobosDBCheckpoint::Event.create(id: '1', entity_id: '1', event_time: nil, created_at: Time.now - 100)
      PhobosDBCheckpoint::Event.create(id: '2', entity_id: '2', event_time: nil, created_at: Time.now - 200)
      PhobosDBCheckpoint::Event.create(id: '3', entity_id: '3', event_time: Time.now - 300, created_at: Time.now - 300)
      PhobosDBCheckpoint::Event.create(id: '4', entity_id: '4', event_time: nil).tap { |r| r.created_at = nil; r.save! }
      PhobosDBCheckpoint::Event.create(id: '5', entity_id: '5', event_time: Time.now - 400).tap { |r| r.created_at = nil; r.save! }
      PhobosDBCheckpoint::Event.create(id: '6', entity_id: '6', event_time: Time.now - 500).tap { |r| r.created_at = nil; r.save! }
    end

    it 'sorts it in descending order leaving null timestamp records trailing at the end' do
      expect(
        PhobosDBCheckpoint::Event
          .order_by_event_time_and_created_at
          .pluck('entity_id')
      ).to eq %w[3 5 6 1 2 4]
    end
  end
end
