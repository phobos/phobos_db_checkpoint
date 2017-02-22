module PhobosDBCheckpoint
  class Error < StandardError; end
  class HandlerNotFoundError < StandardError
    def initialize(group_id)
      super("Phobos Handler not found for group id '#{group_id}'")
    end
  end
end
