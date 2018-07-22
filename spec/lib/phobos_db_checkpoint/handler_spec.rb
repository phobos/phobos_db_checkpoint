# frozen_string_literal: true

require 'spec_helper'
require 'securerandom'
require 'json'

RSpec.describe PhobosDBCheckpoint::Handler, type: :db do
  class TestPhobosDbCheckpointHandler
    include PhobosDBCheckpoint::Handler
  end

  let(:handler) { TestPhobosDbCheckpointHandler.new }
  let(:entity_id) { SecureRandom.uuid }
  let(:event_time) { Time.now.utc }
  let(:event_type) { 'event-type' }
  let(:event_version) { 'v1' }

  subject { handler }

  before do
    allow(TestPhobosDbCheckpointHandler).to receive(:new).and_return(handler)
  end

  it 'exposes Phobos::Handler.start' do
    expect(TestPhobosDbCheckpointHandler).to respond_to :start
  end

  it 'exposes Phobos::Handler.stop' do
    expect(TestPhobosDbCheckpointHandler).to respond_to :stop
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
      process_message(handler: TestPhobosDbCheckpointHandler, payload: payload, metadata: metadata)
    end

    describe 'when returning ack' do
      before do
        expect(subject).to receive(:consume).and_return(ack)
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

      it 'publishes the expected instrumentations, with outcome event_acknowledged' do
        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.around_consume', hash_including(:checksum))
          .and_call_original

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.event_already_exists_check', hash_including(:checksum))
          .and_call_original

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.event_action', hash_including(:checksum))
          .and_call_original

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.event_acknowledged', hash_including(:checksum))
          .and_call_original

        run_handler
      end
    end

    describe 'when the event already exists' do
      before do
        expect(subject)
          .to receive(:consume)
          .once
          .and_return(ack)
      end

      it 'skips consume' do
        2.times do
          run_handler
          expect(PhobosDBCheckpoint::Event.count).to eql 1
        end
      end

      it 'publishes the expected instrumentations, with outcome event_already_consumed' do
        run_handler

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.around_consume', hash_including(:checksum))
          .and_call_original

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.event_already_exists_check', hash_including(:checksum))
          .and_call_original

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.event_already_consumed', hash_including(:checksum))
          .and_call_original

        run_handler
      end
    end

    describe 'when returning something different' do
      before do
        expect(subject).to receive(:consume).and_return(:skip)
      end

      it 'does not save' do
        expect(PhobosDBCheckpoint::Event.count).to eql 0
        run_handler
        expect(PhobosDBCheckpoint::Event.count).to eql 0
      end

      it 'publishes the expected instrumentations, with outcome event_skipped' do
        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.around_consume', hash_including(:checksum))
          .and_call_original

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.event_already_exists_check', hash_including(:checksum))
          .and_call_original

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.event_action', hash_including(:checksum))
          .and_call_original

        expect(subject)
          .to receive(:instrument)
          .with('db_checkpoint.event_skipped', hash_including(:checksum))
          .and_call_original

        run_handler
      end
    end

    it 'returns db connections back to the connection pool' do
      expect(ActiveRecord::Base).to receive(:clear_active_connections!)
      expect(subject).to receive(:consume).and_return(ack)
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

  describe '.retry_consume?' do
    context 'when Phobos config specifies max_retries' do
      it 'will retry while retry count is less than configured max_retries' do
        expect(subject.retry_consume?('foo', { retry_count: 0 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 1 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 2 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 3 }, 'bar')).to be_falsey
      end
    end

    context 'when Phobos config has no max_retries' do
      before do
        allow(Phobos)
          .to receive_message_chain(:config, :db_checkpoint)
          .and_return(nil)
      end

      it 'will retry forever' do
        expect(subject.retry_consume?('foo', { retry_count: 0 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 1 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 2 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 3 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 9 }, 'bar')).to be_truthy
      end
    end

    context 'when Phobos config has max_retries set to null' do
      before do
        allow(Phobos)
          .to receive_message_chain(:config, :db_checkpoint, :max_retries)
          .and_return(nil)
      end

      it 'will retry forever' do
        expect(subject.retry_consume?('foo', { retry_count: 0 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 1 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 2 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 3 }, 'bar')).to be_truthy
        expect(subject.retry_consume?('foo', { retry_count: 9 }, 'bar')).to be_truthy
      end
    end
  end

  describe '.around_consume' do
    let(:event_payload) { Hash(payload: 'payload') }
    let(:event_metadata) { Hash(metadata: 'metadata', retry_count: 0) }

    it 'should yield control' do
      expect do |block|
        subject.around_consume(event_payload, event_metadata, &block)
      end.to yield_control.once
    end

    context 'when failure occurs' do
      let(:block) { proc { |_n| raise StandardError, 'foo' } }

      context 'and retry consume conditions are met' do
        it 'reraises the error' do
          expect do
            subject.around_consume(event_payload, event_metadata, &block)
          end.to raise_error StandardError, 'foo'
        end

        it 'does not create a Failure record' do
          expect do
            expect do
              subject.around_consume(event_payload, event_metadata, &block)
            end.to raise_error StandardError, 'foo'
          end.to_not change(PhobosDBCheckpoint::Failure, :count)
        end
      end

      context 'but retry consume conditions are not met' do
        let(:event_metadata) do
          Hash(metadata: 'metadata', retry_count: Phobos.config.db_checkpoint.max_retries, group_id: 'test-checkpoint')
        end

        it 'suppresses the error' do
          expect do
            subject.around_consume(event_payload, event_metadata, &block)
          end.to_not raise_error
        end

        it 'creates a Failure record' do
          expect do
            subject.around_consume(event_payload, event_metadata, &block)
          end.to change(PhobosDBCheckpoint::Failure, :count).by(1)
        end
      end
    end
  end
end
