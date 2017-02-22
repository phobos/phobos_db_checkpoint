module PhobosDBCheckpoint
  class PhobosDBCheckpointError < StandardError; end
  class HandlerNotFoundError < PhobosDBCheckpointError
    def initialize(group_id)
      super("Phobos Handler not found for group id '#{group_id}'")
    end
  end
end
