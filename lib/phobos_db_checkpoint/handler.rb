module PhobosDBCheckpoint
  module Handler
    include Phobos::Handler
    DEFAULT_MAX_RETRIES = 3

    def self.included(base)
      base.extend(ClassMethods)
    end

    def ack(entity_id, event_time, event_type = nil, event_version = nil)
      PhobosDBCheckpoint::Ack.new(entity_id, event_time, event_type, event_version)
    end

    module ClassMethods
      include Phobos::Instrumentation
      include Phobos::Handler::ClassMethods

      # Name...
      # => retry_consume?
      # => back_off?
      # => consume_again?
      # => fail_consume?
      # => fail_permanently?
      # => give_up?
      # => stop_message?
      # => consume_failure_condition_met?
      def retry_consume?(event, event_metadata, exception)
        event_metadata[:retry_count] < DEFAULT_MAX_RETRIES
      end

      def around_consume(payload, metadata)
        event = PhobosDBCheckpoint::Event.new(
          topic: metadata[:topic],
          group_id: metadata[:group_id],
          payload: payload
        )

        event_metadata = { checksum: event.checksum }.merge(metadata)

        instrument('db_checkpoint.around_consume', event_metadata) do
          event_exists = instrument('db_checkpoint.event_already_exists_check', event_metadata) { event.exists? }
          if event_exists
            instrument('db_checkpoint.event_already_consumed', event_metadata)
            return
          end

          event_action = instrument('db_checkpoint.event_action', event_metadata) do
            begin
              yield
            rescue => e
              if retry_consume?(event, event_metadata, e)
                raise e
              else
                Failure.record(event_payload: payload, event_metadata: event_metadata, exception: e)
              end
            end
          end

          case event_action
          when PhobosDBCheckpoint::Ack
            instrument('db_checkpoint.event_acknowledged', event_metadata) do
              event.acknowledge!(event_action)
            end
          else
            instrument('db_checkpoint.event_skipped', event_metadata)
          end
        end
      ensure
        # Returns any connections in use by the current thread back to the pool, and also returns
        # connections to the pool cached by threads that are no longer alive.
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end
end
