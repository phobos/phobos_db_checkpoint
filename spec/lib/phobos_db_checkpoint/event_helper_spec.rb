require 'spec_helper'

RSpec.describe PhobosDBCheckpoint::EventHelper, type: :db do
  class TestEvent
    include PhobosDBCheckpoint::EventHelper
    attr_accessor :group_id
  end
  subject { TestEvent.new.tap { |e| e.group_id = group_id } }

  describe '#configured_handler' do
    before do
      Phobos.silence_log = true
      Phobos.configure('spec/phobos.test.yml')
    end

    context 'when group id is not found in Phobos configuration' do
      let(:group_id) { 'check-testpoint' }

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
      let(:group_id) { 'test-checkpoint' }

      it 'returns the name of the configured handler for this event' do
        expect(subject.configured_handler).to eql Phobos::EchoHandler
      end
    end
  end
end
