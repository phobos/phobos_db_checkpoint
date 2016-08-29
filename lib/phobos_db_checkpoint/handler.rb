module PhobosDBCheckpoint
  module Handler
    include Phobos::Handler

    def self.included(base)
      base.extend(ClassMethods)
    end

    def ack(entity_id, event_time, event_type = nil, event_version = nil)
      PhobosDBCheckpoint::Ack.new(entity_id, event_time, event_type, event_version)
    end

    module ClassMethods
      include Phobos::Instrumentation

      def around_consume(payload, metadata)
        event = PhobosDBCheckpoint::Event.new(
          topic: metadata[:topic],
          group_id: metadata[:group_id],
          payload: payload
        )

        event_metadata = {checksum: event.checksum}.merge(metadata)
        if event.exists?
          instrument('db_checkpoint.event_already_consumed', event_metadata)
          return
        end

        event_action = yield
        case event_action
        when PhobosDBCheckpoint::Ack
          instrument('db_checkpoint.event_acknowledged', event_metadata) do
            event.acknowledge!(event_action)
          end
        else
          instrument('db_checkpoint.event_skipped', event_metadata)
        end
      end
    end
  end
end
