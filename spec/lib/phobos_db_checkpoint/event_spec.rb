require 'spec_helper'

describe PhobosDBCheckpoint::Event, type: :db do
  describe '#checksum' do
    it 'is created based on the payload' do
      expect(PhobosDBCheckpoint::Event.new.checksum).to be_nil
      expect(PhobosDBCheckpoint::Event.new(payload: {data: 'A'}.to_json).checksum).to eql 'c1a837e058f7aa037afdf142c013af05'
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
end
