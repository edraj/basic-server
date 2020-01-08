require "json"
require "uuid"
require "uuid/json"

module Edraj
	# This is simply a compilation of all "terminal" child classes of Resource class.
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
    Reply # aka comment
    Reaction
    SuggestedModification
    Share
    Signature
    Relationship
    Subscription
    Invitation
    Address
    Organization
    StructuredJson
    # Token
    Locator
		MessageDelivery 
  end

	# صنف مجرد
  abstract class Resource
    include JSON::Serializable

    def class_type
      self.class
    end
  end

	# محدد
  class Locator < Resource
    include JSON::Serializable
    property id : ID
    property resource_type : ResourceType
    property space : String
    property subpath : String
    property anchor : String? # A pointer to a sub-content in the resource
    property host : String?
    property uri : String? # Remote reference of the resource

    def initialize(@space, @subpath, @resource_type, @id)
    end

    def json_name
      "#{@id.to_s}.#{@resource_type.to_s.downcase}.json"
    end

    def path # Absolute local path
      Edraj.settings.data_path / "spaces" / @space / @subpath
    end

    def update(list : Hash(String, ::JSON::Any))
    end

    def properties(fields = {} of String => Bool, includes = [] of ResourceType) : {Hash(String, JSON::Any), Array(Locator)}
      list = {} of String => JSON::Any
      included = [] of Locator
      {list, included}
    end
  end

	# إشعار
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

    def properties(fields = {} of String => Bool, includes = [] of ResourceType) : {Hash(String, JSON::Any), Array(Locator)}
      list = {} of String => JSON::Any
      included = [] of Locator
      {list, included}
    end
  end

	# اشتراك
  class Subscription < Resource
    property subpath = ""
    property resource_types = [] of ResourceType
    property tags = [] of String
  end

	# دعوة
  class Invitation < Resource
  end

	# عنوان
  class Address < Resource
    property line : String
    property zipcode : String
    property city : String
    property state : String
    property countery : String
    property geopoint : NamedTuple(long: Float64, lat: Float64)?
  end

	# علاقة
  class Relationship < Resource
    property type : String
    property properties = {} of String => JSON::Any
    property related_to : Locator
  end

	# ملف فوقي
  abstract class MetaFile < Resource
    property timestamp = Time.local
    property description : String?
    property tags = [] of String

    # abstract def update
    abstract def update(list : Hash(String, ::JSON::Any))
    abstract def properties(fields = {} of String => Bool, includes = [] of ResourceType) : {Hash(String, JSON::Any), Array(Locator)}
  end
end
