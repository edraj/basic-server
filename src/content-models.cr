require "./resource"
require "./attachment-models"

module Edraj
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
    Correspondance # Subject, Rich-text body with attachments.
  end

  enum ContentType
    Contact     # Person or Organization
    Biography   # Person or Organization
    Collection  # Aka Collection
    Post        # aka article
    Message     # Short/plain message, Email correspondance
    Task        # aka Todo item with basic workflow (status)
    Term        # Term definition: Word, sub-phrase, translation ...etc
    Publication # Journal, Magazine, book, e-book/e-publication (can be present in various forms : document, chm, har, pdf ...etc)
    # Product

    # Page
    # Block
    # Folder  # Folder "only"
    # Schema
    # Other
    # Profile
  end

  class Content < MetaFile
    property location : String = "none"               # file://filepathname, embedded, uri://server..., none
    property title : String?                          # subject / displayname
    property body : ::JSON::Any = ::JSON::Any.new nil # aka Body/Payload
    property content_type : String = "none"           # json+schema, media+subtype, folder, ...
    property content_encoding : String?
    property actor : Locator?  # Actor who created this content : user, app (iot) ...
    property owner : Locator   # Owner of the content (including body and attachments) : user, group ...
    property author : Locator? # Original author of the content
    property response_to : UUID?

    # property relationships = [] of Relationship
    # property signatures = [] of Signature
    # property media = [] of Media
    # property replies = [] of Reply
    # property reactions = [] of Reaction
    # property alterations = [] of Alteration
    # property shares = [] of Share
    # property votes = [] of Vote

    # property attachments = {} of AttachmentType => Attachment # This is presented in the filesystem directly

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

    def logs(query) # Returns log entries for this content
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

    def properties(fields = {} of String => Bool, includes = [] of ResourceType)
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

    # def append_attachment(attachment : Media | Reply | Reaction | Share | Relationship | Signature | Alteration | Vote)
    #  case attachment
    #  when Media
    #    @media << attachment
    #  when Reply
    #    @replies << attachment
    #  when Reaction
    #    @reactions << attachment
    #  when Share
    #    @shares << attachment
    #  when Relatiohship
    #    @relationships << attachment
    #  when Signatures
    #    @signatures << signature
    #  when SuggestedModification
    #    @suggested_modifications << attachment
    #  when Votes
    #    @votes << attachment
    #  else
    #    raise "Unsupported attachment type #{attachment.class}"
    #  end
    # end

    def update_attachment(media)
    end

    def remove_attachment(id)
    end
  end

  class Collection < Content
  end

  class Post < Content
  end

  class Message < Content
    property from : UUID
    property to : Array(UUID)
    property thread_id : UUID
    property delivery_updates = [] of MessageDelivery

    def initialize(@owner, @location, @from, @to, @thread_id)
    end

    def properties(fields = {} of String => Bool, includes = [] of ResourceType)
      list, included = super(fields, includes)
      list["from"] = JSON::Any.new @from.to_s
      list["to"] = JSON.parse @to.to_json

      {list, included}
    end
  end

  class Biography < Content
    property shortname : String
    property dob : Time?
    property dod : Time?
    property displayname : String?
    property about : String?
    property accomplishments = [] of Accomplishment
    property pictures = [] of Media

    def initialize(@owner, @shortname)
    end
  end

  class Publication < Content
  end

  class Task < Content
    # tbd lifecyrle (status flow)
  end

  class Term < Content
  end

  class OtherSpaces < Content # A database of Locator's to other spaces along some basic indexed data.
  end

  class Contact < Biography
    property contact_details = [] of ContactDetail
    property identities = [] of Identity
  end

  # A speical type of content that contains arbitrary JSON structured data accoriding to a schema
  class StructuredJson < Content
    property schema : String

    def initialize(@owner, @schema)
    end
  end

  abstract class Logic < MetaFile
    def update(list : Hash(String, ::JSON::Any))
    end

    def properties(fields = {} of String => Bool, includes = [] of ResourceType)
      list = {} of String => JSON::Any
      included = [] of Locator
      {list, included}
    end
  end

  # Libarry logic that can be invoked from elsewhere
  class Library < Logic
  end

  # Triggerable by Time or Event
  class Triggerable < Logic
    # condition indicates what type / parameters for event listening
    def set(condition)
    end

    # Check if the trigger condition is true if so invoke exec
    def check_event(event)
    end

    # Execute action
    def execute
    end
  end
end
