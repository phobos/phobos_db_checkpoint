require 'spec_helper'

describe PhobosDBCheckpoint::Failure, type: :db do
  let(:event_payload) { Hash(payload: 'payload') }
  let(:checksum) { 'checksum' }
  let(:event_metadata) { Hash(metadata: 'metadata', checksum: checksum) }
  let(:record_payload) { Hash(event_payload: event_payload, event_metadata: event_metadata) }
  subject { described_class.record(record_payload) }

  describe '.record' do
    it 'creates a failure' do
      expect {
        subject
      }.to change(described_class, :count).by(1)
    end

    it 'stores payload as json' do
      expect(subject.payload).to eql JSON(event_payload.to_json)
    end

    it 'stores metadata as json' do
      expect(subject.metadata).to eql JSON(event_metadata.to_json)
    end

    context 'with exception' do
      let(:exception) do
        e = nil
        begin
          0/0
        rescue => error
          e = error
        end
        e
      end

      let(:record_payload) {
        Hash(event_payload: event_payload, event_metadata: event_metadata, exception: exception)
      }

      it 'stores exception class' do
        expect(subject.error_class).to eql exception.class.name
      end

      it 'stores exception message' do
        expect(subject.error_message).to eql exception.message
      end

      it 'stores exception backtrace as json' do
        expect(subject.error_backtrace).to eql JSON(exception.backtrace.to_json)
      end
    end

    context 'with action' do
      let(:action) {
        PhobosDBCheckpoint::Nack.new('entity_id', Time.now)
      }
      let(:record_payload) {
        Hash(event_payload: event_payload, event_metadata: event_metadata, action: action)
      }

      it 'stores action entity_id' do
        expect(subject.entity_id).to eql action.entity_id
      end

      it 'stores action event_time' do
        expect(subject.event_time).to eql action.event_time
      end
    end
  end

  describe '.exists?' do
    it 'checks if the failure exists' do
      expect(described_class.exists?(checksum)).to eql false
      subject
      expect(described_class.exists?(checksum)).to eql true
    end
  end
end
