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
  end

  describe '.exists?' do
    it 'checks if the failure exists' do
      expect(described_class.exists?(checksum)).to eql false
      subject
      expect(described_class.exists?(checksum)).to eql true
    end
  end

  describe '#configured_handler' do
    before do
      Phobos.silence_log = true
      Phobos.configure('spec/phobos.test.yml')
    end

    context 'when group id is not found in Phobos configuration' do
      let(:event_metadata) { Hash(group_id: 'check-testpoint') }

      it 'fails with HandlerNotFoundError' do
        expect {
          subject.configured_handler
        }.to raise_error(
          PhobosDBCheckpoint::HandlerNotFoundError,
          "Phobos Handler not found for group id 'check-testpoint'"
        )
      end
    end

    context 'when group id is found in Phobos configuration' do
      let(:event_metadata) { Hash(group_id: 'test-checkpoint') }

      it 'returns the name of the configured handler for this event' do
        expect(subject.configured_handler).to eql Phobos::EchoHandler.to_s
      end
    end
  end
end
