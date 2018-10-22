# frozen_string_literal: true

module PhobosDBCheckpoint
  module Handler
    include Phobos::Handler
    include Phobos::Instrumentation

    def self.included(base)
      base.extend(ClassMethods)
    end

    def ack(entity_id, event_time, event_type = nil, event_version = nil)
      PhobosDBCheckpoint::Ack.new(entity_id, event_time, event_type, event_version)
    end

    def retry_consume?(_event, event_metadata, _exception)
      return true unless Phobos.config&.db_checkpoint&.max_retries

      event_metadata[:retry_count] < Phobos.config&.db_checkpoint&.max_retries
    end

    def around_consume(payload, metadata)
      event, event_metadata = build_event_and_metadata(payload, metadata)

      instrument('db_checkpoint.around_consume', event_metadata) do
        return if event_exists?(event, event_metadata)

        event_action = instrument('db_checkpoint.event_action', event_metadata) do
          begin
            yield
          rescue StandardError => e
            raise e if retry_consume?(event, event_metadata, e)

            Failure.record(event: event, event_metadata: event_metadata, exception: e)
          end
        end

        record_action(event, event_metadata, event_action)
      end
    ensure
      # Returns any connections in use by the current thread back to the pool, and also returns
      # connections to the pool cached by threads that are no longer alive.
      ActiveRecord::Base.clear_active_connections!
    end

    def build_event_and_metadata(payload, metadata)
      event = PhobosDBCheckpoint::Event.new(
        topic: metadata[:topic],
        group_id: metadata[:group_id],
        payload: payload
      )

      event_metadata = { checksum: event.checksum }.merge(metadata)

      [event, event_metadata]
    end

    def event_exists?(event, event_metadata)
      event_exists = instrument('db_checkpoint.event_already_exists_check', event_metadata) do
        event.exists?
      end

      instrument('db_checkpoint.event_already_consumed', event_metadata) if event_exists

      event_exists
    end

    def record_action(event, event_metadata, event_action)
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
