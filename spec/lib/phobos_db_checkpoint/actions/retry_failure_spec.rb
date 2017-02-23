require 'spec_helper'

describe PhobosDBCheckpoint::RetryFailure, type: :db do
  let(:event_payload) { Hash(payload: 'payload') }
  let(:event_metadata) { Hash(metadata: 'metadata') }
  let(:attributes_for_create) { Hash(event_payload: event_payload, event_metadata: event_metadata) }
  let(:failure) { PhobosDBCheckpoint::Failure.record(attributes_for_create) }
  subject { described_class.new(failure) }

  describe '#perform' do
    let(:handler_class) { double(:handler_class) }
    let(:handler_instance) { double(:handler_instance) }

    it 'synchronously attempts to consume the event again' do
      expect(failure)
        .to receive(:configured_handler)
        .and_return(handler_class)

      expect(handler_class)
        .to receive(:new)
        .and_return(handler_instance)

      expect(handler_instance)
        .to receive(:consume)
        .with(event_payload, event_metadata.merge(retry_count: 0))

      subject.perform
    end

    context 'when consume is successful' do
      let(:event_metadata) { Hash(metadata: 'metadata', group_id: 'test-checkpoint') }
      before do
        Phobos.silence_log = true
        Phobos.configure('spec/phobos.test.yml')
        failure
      end

      it 'destroys the failure' do
        expect {
          subject.perform
        }.to change(PhobosDBCheckpoint::Failure, :count).by(-1)

        expect {
          failure.reload
        }.to raise_error ActiveRecord::RecordNotFound
      end
    end

    context 'when consume is not successful' do
      let(:event_metadata) { Hash(metadata: 'metadata', group_id: 'test-checkpoint') }
      before do
        failure

        expect(failure)
          .to receive(:configured_handler)
          .and_return(handler_class)

        expect(handler_class)
          .to receive(:new)
          .and_return(handler_instance)

        expect(handler_instance)
          .to receive(:consume)
          .and_raise('ConsumeError')
      end

      it 'does not destroy the failure' do
        expect {
          expect {
            subject.perform
          }.to raise_error(RuntimeError, 'ConsumeError')
        }.to change(PhobosDBCheckpoint::Failure, :count).by(0)

        expect {
          failure.reload
        }.to_not raise_error
      end
    end
  end
end
