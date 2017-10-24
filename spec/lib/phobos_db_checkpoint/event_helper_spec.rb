require 'spec_helper'

RSpec.describe PhobosDBCheckpoint::EventHelper, type: :db do
  let(:payload) { Hash('payload' => 'payload') }
  let(:group_id) { 'test-checkpoint' }

  class TestEvent
    include PhobosDBCheckpoint::EventHelper
    attr_accessor :group_id, :payload
  end

  subject do
    TestEvent.new.tap do |e|
      e.group_id = group_id
      e.payload = payload
    end
  end

  describe '#configured_listener' do
    context 'when group id is not found in Phobos configuration' do
      let(:group_id) { 'check-testpoint' }

      it 'fails with ListenerNotFoundError' do
        expect {
          subject.configured_listener
        }.to raise_error(
          PhobosDBCheckpoint::ListenerNotFoundError,
          "Phobos Listener not found for group id 'check-testpoint'"
        )
      end
    end

    context 'when group id is found in Phobos configuration' do
      it 'returns the name of the configured listener for this event' do
        expect(subject.configured_listener).to eql Phobos.config.listeners.first
      end
    end
  end

  describe '#configured_handler' do
    it 'returns the name of the configured handler for this event' do
      expect(subject.configured_handler).to eql Phobos::EchoHandler
    end
  end

  describe 'method missing' do
    let(:handler) { Phobos::EchoHandler.new }
    context 'when method is starting with "fetch_"' do
      context 'and handler implements the method' do
        class DummyHandler
          attr_accessor :payload
          def foo_bar(payload)
            'baz'
          end
        end
        let(:payload) { Hash('payload' => 'payload') }
        let(:handler) { DummyHandler.new.tap { |h| h.payload = payload } }

        before do
          allow(Phobos::EchoHandler).to receive(:new).and_return(handler)
          expect(handler).to receive(:foo_bar).with(payload).and_call_original
        end

        after { DummyHandler.class_eval { remove_method :foo_bar } }

        it 'delegates to the configured handler' do
          expect(subject.fetch_foo_bar).to eql 'baz'
        end
      end

      context 'when handler does not implement the method' do
        it 'returns nil' do
          expect(subject.fetch_foo_bar).to be_nil
        end
      end
    end

    context 'when method does not start with "fetch_"' do
      it 'raises NoMethodError' do
        expect { subject.gimme_foo_bar }.to raise_error NoMethodError
      end
    end
  end
end
