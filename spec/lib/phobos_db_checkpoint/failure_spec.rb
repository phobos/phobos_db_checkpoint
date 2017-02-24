require 'spec_helper'

describe PhobosDBCheckpoint::Failure, type: :db do
  let(:event_payload) { Hash(payload: 'payload') }
  let(:checksum) { 'checksum' }
  let(:event_metadata) { Hash(metadata: 'metadata', checksum: checksum) }
  let(:attributes_for_create) { Hash(event_payload: event_payload, event_metadata: event_metadata) }
  subject { described_class.record(attributes_for_create) }

  describe '.record' do
    it 'creates a failure record' do
      expect {
        subject
      }.to change(described_class, :count).by(1)
    end

    it 'stores payload as json' do
      expect(subject.attributes['payload']).to eql JSON(event_payload.to_json)
    end

    it 'stores metadata as json' do
      expect(subject.attributes['metadata']).to eql JSON(event_metadata.to_json)
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

      let(:attributes_for_create) {
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

    context 'when record already exists' do
      before do
        subject
      end

      it 'does not create a failure record' do
        expect {
          subject
        }.to_not change(described_class, :count)
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

  describe 'scopes' do
    before do
      3.times.with_index do |i|
        attributes_for_create = {
          event_payload: event_payload,
          event_metadata: {
            id: i+1,
            checksum: "checksum-#{i+1}",
            group_id: "group_id-#{i+1}",
            topic: "topic-#{i+1}"
          }
        }
        described_class.record(attributes_for_create)
      end
    end

    describe '.by_checksum' do
      it 'returns records with matching metadata checksum' do
        expect(described_class.by_checksum('checksum-2'))
          .to match_array described_class.where(id: 2)
      end
    end

    describe '.by_topic' do
      it 'returns records with matching metadata checksum' do
        expect(described_class.by_topic('topic-1'))
          .to match_array described_class.where(id: 1)
      end
    end

    describe '.by_group_id' do
      it 'returns records with matching metadata checksum' do
        expect(described_class.by_group_id('group_id-3'))
          .to match_array described_class.where(id: 3)
      end
    end
  end

  describe 'attributes' do
    let(:event_metadata) { Hash(metadata: 'metadata', checksum: checksum, group_id: 'group_id') }
    it 'has a getter override for payload returning symbolic keys' do
      expect(subject.payload).to eql({ payload: 'payload' })
    end

    it 'has a getter override for metadata returning symbolic keys' do
      expect(subject.metadata).to eql(event_metadata)
    end

    it 'has a group_id getter for pulling metadata[:group_id]' do
      expect(subject.group_id).to eql(event_metadata[:group_id])
    end
  end
end
