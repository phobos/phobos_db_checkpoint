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

  describe 'attributes' do
    let(:time) { Time.now.to_s }
    let(:event_payload) {
      Hash(
        'time' => time
      )
    }

    let(:event_metadata) {
      Hash(
        metadata: 'metadata',
        checksum: checksum,
        group_id: 'test-checkpoint'
      )
    }
    class DummyHandler
      include PhobosDBCheckpoint::Handler
      def event_time(payload)
        payload['time']
      end
    end

    describe '#payload' do
      let(:event_payload) { Hash(a: 1, b: 2) }

      it 'has a getter for payload' do
        expect(subject.payload).to be_a(Hash)
        expect(subject.payload).to eq(JSON(event_payload.to_json).deep_symbolize_keys)
      end
    end

    it 'has a getter override for payload returning symbolic keys' do
      expect(subject.payload).to eql({ time: time })
    end

    it 'has a getter override for metadata returning symbolic keys' do
      expect(subject.metadata).to eql(event_metadata)
    end

    it 'has a group_id getter for pulling metadata[:group_id]' do
      expect(subject.group_id).to eql(event_metadata[:group_id])
    end

    it 'has created_at' do
      expect(subject.created_at).to_not be_nil
      expect(subject.created_at).to be_an_instance_of(Time)
    end

    it 'has event_time' do
      expect(Phobos::EchoHandler)
        .to receive(:new)
        .at_least(:once)
        .and_return(DummyHandler.new)

      expect(subject.event_time).to_not be_nil
      expect(subject.event_time).to be_an_instance_of(Time)
    end

    describe 'attributes yielded from handler' do
      let(:handler_instance) { double(:handler_instance) }
      before do
        expect(Phobos::EchoHandler)
          .to receive(:new)
          .at_least(:once)
          .and_return(DummyHandler.new)
      end

      describe '#entity_id' do
        let(:event_payload) { Hash('entity_id' => 'entity_id') }

        it 'by default does not set entity_id' do
          expect(subject.entity_id).to be_nil
        end

        context 'when entity_id is implemented on handler' do
          before do
            DummyHandler.class_eval do
              def entity_id(payload)
                payload['entity_id']
              end
            end
          end

          after { DummyHandler.class_eval { remove_method :entity_id } }

          it 'sets entity_id' do
            expect(subject.entity_id).to eql('entity_id')
          end
        end
      end

      describe '#event_time' do
        let(:event_time) { Time.parse(Time.now.to_s) }
        let(:event_payload) { Hash('event_time' => event_time) }

        it 'by default does not set entity_id' do
          expect(subject.event_time).to be_nil
        end

        context 'when event_time is implemented on handler' do
          before do
            DummyHandler.class_eval do
              def event_time(payload)
                payload['event_time']
              end
            end
          end

          after { DummyHandler.class_eval { remove_method :event_time } }

          it 'sets event_time' do
            expect(subject.event_time).to eql(event_time)
          end
        end
      end

      describe '#event_type' do
        let(:event_payload) { Hash('event_type' => 'event_type') }

        it 'by default does not set event_type' do
          expect(subject.event_type).to be_nil
        end

        context 'when event_type is implemented on handler' do
          before do
            DummyHandler.class_eval do
              def event_type(payload)
                payload['event_type']
              end
            end
          end

          after { DummyHandler.class_eval { remove_method :event_type } }

          it 'sets event_type' do
            expect(subject.event_type).to eql('event_type')
          end
        end
      end

      describe '#event_version' do
        let(:event_payload) { Hash('event_version' => 'event_version') }

        it 'by default does not set event_version' do
          expect(subject.event_version).to be_nil
        end

        context 'when event_version is implemented on handler' do
          before do
            DummyHandler.class_eval do
              def event_version(payload)
                payload['event_version']
              end
            end
          end

          after { DummyHandler.class_eval { remove_method :event_version } }

          it 'sets event_version' do
            expect(subject.event_version).to eql('event_version')
          end
        end
      end
    end
  end

  describe '.order_by_event_time_and_created_at' do
    before do
      PhobosDBCheckpoint::Failure.delete_all
      PhobosDBCheckpoint::Failure.create(id: '1', entity_id: '1', event_time: nil, created_at: Time.now-100)
      PhobosDBCheckpoint::Failure.create(id: '2', entity_id: '2', event_time: nil, created_at: Time.now-200)
      PhobosDBCheckpoint::Failure.create(id: '3', entity_id: '3', event_time: Time.now-300, created_at: Time.now-300)
      PhobosDBCheckpoint::Failure.create(id: '4', entity_id: '4', event_time: nil).tap { |r| r.created_at=nil; r.save! }
      PhobosDBCheckpoint::Failure.create(id: '5', entity_id: '5', event_time: Time.now-400).tap { |r| r.created_at=nil; r.save! }
      PhobosDBCheckpoint::Failure.create(id: '6', entity_id: '6', event_time: Time.now-500).tap { |r| r.created_at=nil; r.save! }
    end

    it 'sorts it in descending order leaving null timestamp records trailing at the end' do
      expect(
        PhobosDBCheckpoint::Failure
          .order_by_event_time_and_created_at
          .pluck('entity_id')
      ).to eq ['3', '5', '6', '1', '2', '4']
    end
  end
end
