require "json"
require "uuid"
require "uuid/json"

alias ID = UUID | String

module Edraj
  enum ResourceCategory
    Basic      # of type Resource
    Content    # Content / Data that can be interacted with by other actors
    Attachment # Sub-data that belongs to a primary entry, and has its own actor, id and timestamp
    Actor
    View
    AuthItem
    Logic
  end

  # This is simply a compilation of all "terminal" child classes of Resource class.
  enum ResourceType
    Post            # Content
    Collection      # Content
    Biography       # Content
    Task            # Content
    Term            # Content
    Message         # Content
    StructuredJson  # Content
    Publication     # Content
    Contact         # Biography
    Media           # Attachment
    Reply           # Attachment aka comment
    Reaction        # Attachment
    Alteration      # Attachment
    Share           # Attachment
    Signature       # Attachment
    Organization    # Attachment
    Accomplishment  # Attachment
    MessageDelivery # Attachment
    Vote            # Attachment
    Relationship    # Attachment 
    Subscription    # Resource
		Identity        # Resource
    Invitation      # Resource
    Notification    # Resource
    Address         # Resource
    User            # Actor
    Group           # actor
    Page            # View
    Block           # View
    Library         # Logic
    Triggerable     # Logic
    Locator         # Resource
    Permission      # AuthItem
    Role            # AuthItem

    def category
      case value
      when Accomplishment, Media, MessageDelivery, Organization, Reaction, Relationship, Reply, Share, Signature, Alteration, Vote
        ResourceCategory::Attachment
      when Permission, Role
        ResourceCategory::AuthItem
      when Address, Identity, Invitation, Locator, Notification, Query, Record, Subscription
        ResourceCategory::Basic
      when User, Group, Bot
        ResourceCategory::Actor
      when Biography, Contact, Collection, Message, Post, StructuredJson | Task | Term | Publication
        ResourceCategory::Content
      when Library | Triggerable
        ResourceCategory::Logic
      when Block, Page
        ResourceCategory::View
      else
        raise "Uncategoried resource"
      end
    end
  end

  # صنف مجرد
  abstract class Resource
    include JSON::Serializable

    def class_type
      self.class
    end

    def to_s(io)
      io << to_pretty_json()
    end
		

		def save(locator : Locator)
		end
  end

  # محدد
  class Locator < Resource
    property id : ID
    property resource_type : ResourceType
    property space : String
    property subpath : String
    property parent_id : ID?  # This is required for Attachments only
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

  enum RequestType
    Create
    Update
    Delete
    Send # Message
    Query
    Login
  end

  enum ResultType
    Success
    Inprogress # aka Processing
    Partial
    Failure
  end

  class Result
    include JSON::Serializable
    property status : ResultType
    property code : Int64?
    property properties : Hash(String, JSON::Any)

    def initialize(@status, @properties = Hash(String, JSON::Any).new)
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

  # ملف فوقي
  abstract class MetaFile < Resource
    property timestamp = Time.local
    property description : String?
    property tags = [] of String

    # abstract def update
    abstract def update(list : Hash(String, ::JSON::Any))
    abstract def properties(fields = {} of String => Bool, includes = [] of ResourceType) : {Hash(String, JSON::Any), Array(Locator)}
  end

  enum IdentityType
    Device
    Application
    Browser
    Bot
    Human
    Group
  end

  @[Flags]
  enum IdentityUsage
    Sign
    Issue
    Encrypt
    Authenticate
    Certify

    def self.new(value : Int64)
      self.new value.to_i32
    end
  end

  class Identity < Resource
    property type : IdentityType
    property privileges : IdentityUsage
    property public_key : String
  end
end
