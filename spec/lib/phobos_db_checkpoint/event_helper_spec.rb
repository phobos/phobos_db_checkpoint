require 'spec_helper'

RSpec.describe PhobosDBCheckpoint::EventHelper, type: :db do
  class TestEvent
    include PhobosDBCheckpoint::EventHelper
    attr_accessor :group_id
  end
  subject { TestEvent.new.tap { |e| e.group_id = group_id } }

  describe '#configured_listener' do
    before do
      Phobos.silence_log = true
      Phobos.configure('spec/phobos.test.yml')
    end

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
      let(:group_id) { 'test-checkpoint' }

      it 'returns the name of the configured listener for this event' do
        expect(subject.configured_listener).to eql Phobos.config.listeners.first
      end
    end
  end

  describe '#configured_handler' do
    let(:group_id) { 'test-checkpoint' }
    before do
      Phobos.silence_log = true
      Phobos.configure('spec/phobos.test.yml')
    end

    it 'returns the name of the configured handler for this event' do
      expect(subject.configured_handler).to eql Phobos::EchoHandler
    end
  end
end
