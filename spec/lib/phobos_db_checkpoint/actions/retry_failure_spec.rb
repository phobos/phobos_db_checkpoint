# frozen_string_literal: true

require 'spec_helper'

describe PhobosDBCheckpoint::RetryFailure, type: :db do
  let(:event_payload) { Hash(payload: 'payload') }
  let(:event_metadata) { Hash(metadata: 'metadata', group_id: 'test-checkpoint') }
  let(:event) do
    PhobosDBCheckpoint::Event.new(
      topic: event_metadata[:topic],
      group_id: event_metadata[:group_id],
      payload: event_payload
    )
  end
  let(:attributes_for_create) { Hash(event: event, event_metadata: event_metadata) }
  let(:failure) { PhobosDBCheckpoint::Failure.record(attributes_for_create) }
  subject { described_class.new(failure) }

  describe '#perform' do
    let(:handler_class) { double(:handler_class) }
    let(:handler_instance) { double(:handler_instance) }

    it 'attempts to consume the event again' do
      expect(failure)
        .to receive(:configured_handler)
        .and_return(handler_class)

      expect(handler_class)
        .to receive(:new)
        .and_return(handler_instance)

      expect(handler_instance)
        .to receive(:consume)
        .with(event_payload.to_json, event_metadata.merge(retry_count: 0))

      subject.perform
    end

    context 'when consume is successful' do
      let(:event_metadata) { Hash(metadata: 'metadata', group_id: 'test-checkpoint') }
      before do
        failure
      end

      it 'destroys the failure' do
        expect do
          subject.perform
        end.to change(PhobosDBCheckpoint::Failure, :count).by(-1)

        expect do
          failure.reload
        end.to raise_error ActiveRecord::RecordNotFound
      end

      it 'does not persist the event' do
        expect do
          subject.perform
        end.to_not change(PhobosDBCheckpoint::Event, :count)
      end

      context 'when returning an ack' do
        let(:ack) { PhobosDBCheckpoint::Ack.new('A1B', Time.now, 'event-type', 'v1') }
        before do
          expect(failure)
            .to receive(:configured_handler)
            .and_return(handler_class)

          expect(handler_class)
            .to receive(:new)
            .and_return(handler_instance)

          expect(handler_instance)
            .to receive(:consume)
            .and_return(ack)
        end

        it 'persist the event' do
          expect do
            subject.perform
          end.to change(PhobosDBCheckpoint::Event, :count).by(1)
        end
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
        expect do
          expect do
            subject.perform
          end.to raise_error(RuntimeError, 'ConsumeError')
        end.to change(PhobosDBCheckpoint::Failure, :count).by(0)

        expect do
          failure.reload
        end.to_not raise_error
      end
    end
  end
end
