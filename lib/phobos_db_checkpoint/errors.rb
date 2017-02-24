module PhobosDBCheckpoint
  class PhobosDBCheckpointError < StandardError; end
  class ListenerNotFoundError < PhobosDBCheckpointError
    def initialize(group_id)
      super("Phobos Listener not found for group id '#{group_id}'")
    end
  end
end
