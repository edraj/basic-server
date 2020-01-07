require "json"
require "uuid"
require "uuid/json"

module Edraj

  enum ResourceType
    Post
    Collection
    Biography
    Contact
    Task
    Term
    Message
    Notification
    User
    Group
    Media
    Page
    Block
    Logic
    Reply
    Reaction
    SuggestedModification
    Share
    Signature
    Relationship
    Subscription
    Invitation
    Address
    Organization
  end

	abstract class Resource
    include JSON::Serializable

    abstract def update(list : Hash(String, ::JSON::Any))
    abstract def properties(fields = {} of String => Bool, includes = [] of ResourceType) : { Hash(String, JSON::Any), Array(Locator)}

		def type
			self.class
		end
	end

  class Locator < Resource
    include JSON::Serializable
    property uuid : UUID?
    property resource_type : ResourceType
    property space : String
    property subpath : String
    property anchor : String?
    property host : String?
    property uri : String? # Remote reference of the resource

    def initialize(@space, @subpath, @resource_type, @uuid = nil)
    end

    def json_name
      "#{@uuid.to_s}.#{@resource_type.to_s.downcase}.json"
    end

    def path # Absolute local path
      Edraj.settings.data_path / "spaces" / @space / @subpath
    end
    def update(list : Hash(String, ::JSON::Any))
		end
    def properties(fields = {} of String => Bool, includes = [] of ResourceType) : { Hash(String, JSON::Any), Array(Locator)}
			list = {} of String => JSON::Any
			included = [] of Locator
			{list, included}
		end
  end

  class Notification < Resource
    property actor : Locator         # Who did it?
		property timestamp = Time.local  # When did it happen. starting-point
    property action : RequestType    # What was the nature of the action
		property resource : Locator      # Where was it applied. i.e. affected resource
    property duration : Int32        # How long did it take in milliseconds
    property commit : String         # Associated git commit hash
    property results : Array(Result) # How did it conclude?
    # body should be filled with any additional details pertaining to the specific notification (i.e. in an unstructured fashion).
		property body : ::JSON::Any = ::JSON::Any.new nil # aka Body/Payload

    def initialize(@actor, @action, @resource, @duration, @commit, @results)
    end
    def update(list : Hash(String, ::JSON::Any))
		end
    def properties(fields = {} of String => Bool, includes = [] of ResourceType) : { Hash(String, JSON::Any), Array(Locator)}
			list = {} of String => JSON::Any
			included = [] of Locator
			{list, included}
		end
  end

	abstract class MetaFile < Resource
		abstract def update
  end
end
