require 'spec_helper'

describe PhobosDBCheckpoint::Failure, type: :db do
  let(:event_payload) { Hash(payload: 'payload') }
  let(:checksum) { 'checksum' }
  let(:event_metadata) { Hash(metadata: 'metadata', checksum: checksum, group_id: 'test-checkpoint') }
  let(:event) do
    PhobosDBCheckpoint::Event.new(
      topic: event_metadata[:topic],
      group_id: event_metadata[:group_id],
      payload: event_payload
    )
  end
  let(:attributes_for_create) { Hash(event: event, event_metadata: event_metadata) }
  subject { described_class.record(attributes_for_create).reload }

  before do
    Phobos.silence_log = true
    Phobos.configure('spec/phobos.test.yml')
  end

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
        Hash(event: event, event_metadata: event_metadata, exception: exception)
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
          event: event,
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
    let(:event_metadata) { Hash(metadata: 'metadata', checksum: checksum, group_id: 'test-checkpoint') }


    describe '#payload' do
      let(:event_payload) { Hash(a: 1, b: 2) }

      it 'has a getter for payload' do
        expect(subject.payload).to be_a(Hash)
        expect(subject.payload).to eq(JSON(event_payload.to_json).deep_symbolize_keys)
      end
    end

    it 'has a getter override for payload returning symbolic keys' do
      expect(subject.payload).to eql({ payload: 'payload' })
    end

    it 'has a getter override for metadata returning symbolic keys' do
      expect(subject.metadata).to eql(event_metadata)
    end

    it 'has a group_id getter for pulling metadata[:group_id]' do
      expect(subject.group_id).to eql(event_metadata[:group_id])
    end

    describe 'attributes yielded from handler' do
      let(:handler_instance) { double(:handler_instance) }
      before do
        expect(Phobos::EchoHandler)
          .to receive(:new)
          .at_least(:once)
          .and_return(handler_instance)
      end

      describe '#entity_id' do
        let(:entity_id) { 'foo' }

        it 'does not set entity_id' do
          expect(subject.entity_id).to be_nil
        end

        it 'sets entity_id' do
          expect(handler_instance).to receive(:entity_id).and_return(entity_id)
          expect(subject.entity_id).to eql(entity_id)
        end
      end

      describe '#event_time' do
        let(:event_time) { Time.now }

        it 'does not set event_time' do
          expect(subject.event_time).to be_nil
        end

        it 'sets event_time' do
          expect(handler_instance).to receive(:event_time).and_return(event_time)
          expect(subject.event_time).to eql(event_time)
        end
      end

      describe '#event_type' do
        let(:event_type) { 'event_type' }

        it 'does not set event_type' do
          expect(subject.event_type).to be_nil
        end

        it 'sets event_type' do
          expect(handler_instance).to receive(:event_type).and_return(event_type)
          expect(subject.event_type).to eql(event_type)
        end
      end

      describe '#event_version' do
        let(:event_version) { 'event_version' }

        it 'does not set event_version' do
          expect(subject.event_version).to be_nil
        end

        it 'sets event_version' do
          expect(handler_instance).to receive(:event_version).and_return(event_version)
          expect(subject.event_version).to eql(event_version)
        end
      end
    end
  end
end
