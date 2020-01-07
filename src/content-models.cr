module Edraj

	class Resource

		property request_types = [] of RequestType

		def process(request : Request) 
			results = [] of Result
			records = [] of Records
			{results, records}
		end
	end

  enum MainType
    Actor
    Content
    Attachment
    Notification
    Message
    View
    Logic
  end

  enum MessageType
    SimpleMessage  # Pure text
    RichMessage    # Rich-text body with attachments
    Correspondance #
  end

  enum ActorType
    User
    Group
    Bot
  end

  enum ContentType
    Contact   # Person or Organization
    Biography # Person or Organization
    Album     # Aka Collection
    Post      # aka article
    Message
    Task
    Term # Term definition: Word, sub-phrase, translation ...etc
    Product

    Page
    # Block
    # Folder  # Folder "only"
    # Schema
    # Other
    # Profile
  end

  class Content
    include JSON::Serializable
    property location : String = "none" # file://filepathname, embedded, uri://server..., none
    property timestamp : Time = Time.local
    property tags = Array(String).new
    property title : String? # subject / displayname
    property description : String?
    property body : ::JSON::Any = ::JSON::Any.new nil # aka Body/Payload
    property content_type : String = "none"           # json+schema, media+subtype, folder, ...
    property content_encoding : String?
    property actor : Locator?  # Actor who created this content : user, app (iot) ...
    property owner : Locator   # Owner of the content (including body and attachments) : user, group ...
    property author : Locator? # Original author of the content
    property response_to : UUID?
    property relationships = [] of Relationship
    property signatures = [] of Signature
    property media = [] of Media
    property replies = [] of Reply
    property reactions = [] of Reaction
    property suggested_modifications = [] of SuggestedModification
    property shares = [] of Share

    def json_body : JSON::Any
      return @body if @location.starts_with? "embedded"
      return ::JSON.parse File.read @location.lchop "file://" if @location.starts_with? "file://"
      JSON::Any.new nil
    end

    def string_body
      return @body.to_s if @location.starts_with? "embedded"
      return File.read @location.lchop "file://" if @location.starts_with? "file://"
    end

    def initialize(@owner)
    end

    def update(list : Hash(String, ::JSON::Any))
      @title = list["title"].as_s if list.has_key? "title"
      @body = list["body"] if list.has_key? "body"
      if list.has_key? "tags"
        list["tags"].as_a.each do |tag|
          @tags << tag.as_s unless @tags.includes? tag.as_s
        end
      end
    end

    def properties(fields = {} of String => Bool, includes = [] of ContentType)
      list = {} of String => JSON::Any
      included = [] of Locator
      list["title"] = JSON::Any.new @title.to_s if @title && (!fields.has_key?("title") || fields.has_key?("title"))
      list["body"] = json_body

      if @tags.size > 0
        _tags = [] of JSON::Any
        @tags.each do |tag|
          _tags << JSON::Any.new tag
        end
        list["tags"] = JSON::Any.new _tags
      end

      {list, included}
    end

    def attachments(query)
    end

    def add_attachment(item) # returns id
    end

    def update_attachment(media)
    end

    def remove_attachment(id)
    end
  end

  # class Collection < Content
  # end

  # class Folder < Content
  # end

  class Album < Content
  end

  class Post < Content
  end

  class Message < Content
    property from : UUID
    property to : Array(UUID)
    property thread_id : UUID

    def initialize(@owner, @location, @from, @to, @thread_id)
    end

    def properties(fields = {} of String => Bool, includes = [] of ContentType)
      list, included = super(fields, includes)
      list["from"] = JSON::Any.new @from.to_s
      list["to"] = JSON.parse @to.to_json

      {list, included}
    end
  end

  class Notification
    # property actor : Locator      # Who did it?
    # property timestamp : Time     # When start?
    property action : RequestType    # What was the nature of the action
    property resource : Locator      # Where was it applied
    property duration : Int32        # How long did it take in milliseconds
    property commit : String         # Associated git commit hash
    property results : Array(Result) # How did it conclude?
    # Content.body /body should be filled with any additional details pertaining to the specific notification (i.e. in an unstructured fashion).

    def initialize(@owner, @action, @resource, @duration, @commit, @results)
    end
  end

  class Biography < Content
    property shortname : String
    property dob : Time?
    property dod : Time?
    property displayname : String
    property about : String?
    property accomplishments = [] of Accomplishment
    property pictures = [] of Media

    def initialize(@owner, @shortname, @displayname)
    end
  end

  class Contact < Biography
    property contact_details = [] of ContactDetail
    property identities = [] of Identity
  end

  class Actor < Contact
    property invitations = [] of Invitation
    property subscriptions = [] of Subscription
  end

  class User < Actor
  end

  class Group < Actor
    property members = [] of Actor
  end

  class Bot < Actor
  end
end