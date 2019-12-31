require "json"
require "uuid"
require "uuid/json"
require "./exts"
require "./config"
require "./mime"
require "ohm"

module Edraj
  enum ResourceType
    # Respective classes and json-schema exist
    Actor
    Notification
    Invitation
    Reply
    Reaction
    Subscription
    Schema
    Token
    Locator
    Media
    Signature
    Relationship

    # No classes, only json-schema
    Folder  # Folder "only"
    Contact # Person or Organization
    Profile
    Post
    Message
    Task
    Term
    Biography
    Location # Aka Address
    Page
    Block
    # Other
  end

  # Empty UUID "00000000-0000-4000-0000-000000000000"

  class Locator
    include JSON::Serializable
    property uuid : UUID? # folder meta file is .meta.json
    property resource_type : ResourceType
    property space : String
    property subpath : String
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
  end

  class Relationship
    include JSON::Serializable
    property type : String
    property properties = {} of String => JSON::Any
    property related_to : Locator
  end

  class Signature
    include JSON::Serializable
    property fields : Array(String)
    property timestamp : Time
    property checksum : String
    property keyid : String
    property signatory : Locator
    property hash : String
  end

  # DUMMY_LOCATOR = {space: "", subpath: "", resource_type: Edraj::ResourceType::Message}.to_json

  # Primary serializable  type
  class Content
    include JSON::Serializable
    property location : String = "none" # file://filepathname, embedded, uri://server..., none
    property timestamp : Time = Time.local
    property tags = Array(String).new
    property title : String? # subject / displayname
    property description : String?
    property payload : ::JSON::Any = ::JSON::Any.new nil # aks Body/Payload
    property content_type : String = "none"              # json+schema, media+subtype, folder, ...
    property content_encoding : String?
    property actor : Locator?  # Actor who caused this payload to be created: user, app (iot) ...
    property owner : Locator   # Owner of the payload : user, group ...
    property author : Locator? # Original author of the content
    property response_to : Locator?
    property related_to : Array(Relationship)?
    property signatures : Array(Signature)?

    def json_payload : JSON::Any
      return @payload if @location.starts_with? "embedded"
      return ::JSON.parse File.read @location.lchop "file://" if @location.starts_with? "file://"
      JSON::Any.new nil
    end

    def string_payload
      return @payload.to_s if @location.starts_with? "embedded"
      return File.read @location.lchop "file://" if @location.starts_with? "file://"
    end

    def io_payload
      # TBD
    end

    def initialize(@owner)
    end

    def update(list : Hash(String, ::JSON::Any))
      @title = list["title"].as_s if list.has_key? "title"
      @payload = list["body"] if list.has_key? "body"
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
      list["body"] = json_payload

      if @tags.size > 0
        _tags = [] of JSON::Any
        @tags.each do |tag|
          _tags << JSON::Any.new tag
        end
        list["tags"] = JSON::Any.new _tags
      end

      {list, included}
    end
  end

  #  class EntryMeta # Each entry has one exact meta file
  #    property tags = Array(String).new
  #		property files = Array(Content).new
  #  end

  class Collection < Content
    property attachments = Array(Content).new
  end

  class Entry
    property locator : Locator
    property content : Collection | Content | Subscription | Message | Contact | Folder | Reaction | Reply

    # New / Empty
    def initialize(@locator, @content, *args)
			case @locator.resource_type
			when ResourceType::Media

			end
    end

    # Load existing
    def initialize(@locator)
      case @locator.resource_type
      when ResourceType::Message
        @content = Message.from_json @locator.path, @locator.json_name
      when ResourceType::Reply
        @content = Reply.from_json @locator.path, @locator.json_name
      else
        @content = Collection.from_json @locator.path, @locator.json_name
      end
    end

    def save
      path = locator.path
      Dir.mkdir_p path.to_s unless Dir.exists? path.to_s
      File.write path / locator.json_name, @content.to_pretty_json
    end

    # One-level subfolders
    def subfolders : Array(String)
      list = [] of String
      Dir.glob("#{@locator.path}/*/") do |one|
        list << File.basename one
      end
    end

    # One-level meta-json children resources of type resource_type
    def resources(resource_types : Array(ResourceType)) : Array(Locator)
      list = [] of Locator
      resource_types.each do |resource_type|
        extension = "#{resource_type.to_s.downcase}.json"
        Dir.glob("#{@locator.path}/*.#{extension}") do |one|
          list << Locator.new @locator.space, @locator.subpath, resource_type, UUID.new(File.basename(one, ".#{extension}"))
        end
      end

      list
    end

    def self.search(space : String, query : String, *_args)
      list = [] of Entry
      available = 0
      args = ["FT.SEARCH", "#{space}Idx", query, "language", "english"]
      _args.each do |arg|
        args << arg
      end
      ret = Ohm.redis.call args
      if ret.is_a? Array(Resp::Reply)
        available = ret[0]
        ret.skip(1).each_slice(2) do |slice|
          data = {} of String => String
          data["uuid"] = slice[0].to_s
          props = slice[1]
          if props.is_a? Array(Resp::Reply)
            props.each_slice(2) do |property|
              print "#{property[0]} => ".colorize.blue
              puts "#{property[1]}".colorize.red
              if property[1].is_a? String
                data[property[0].to_s] = property[1].to_s
              end
            end
            subpath = data.delete("subpath").to_s
            resource_type = ResourceType.parse(data.delete("resource_type").to_s)
            uuid = UUID.new(data.delete("uuid").to_s)
            # timestamp = Time.unix(data.delete("timestamp").to_s.to_i)
            # meta = Meta.from_json({timestamp: timestamp}.to_json)
            meta = Meta.from_json("{}")
            meta.tags = data.delete("tags").to_s.split("|") if data.has_key? "tags"
            meta.body = data.delete("body").to_s if data.has_key? "body"
            meta.title = data.delete("title").to_s if data.has_key? "title"
            raise "Unprocessed data #{data.to_json}" if data.size > 0
            list << Entry.new space, subpath, resource_type, uuid, meta
          end
        end
        # raise "Returned #{count} but parsed #{list.size}" if count != list.size
      end
      {available, list}
    end

    def index
      args = ["FT.ADD", "#{@locator.space}Idx", @locator.uuid, "1.0",
              "LANGUAGE", "english", "FIELDS",
              "subpath", @locator.subpath,
              "resource_type", @locator.resource_type.to_s.downcase,
              # "timestamp", @meta.timestamp.to_unix,
      ]
      args << "body" << @meta.body.to_s if !@meta.body.nil?
      args << "title" << @meta.title.to_s if !@meta.title.nil?
      args << "description" << @meta.description.to_s if !@meta.description.nil?
      args << "tags" << @meta.tags.join("|") if @meta.tags.size > 0
      Ohm.redis.call args
    end

    # Delete
    def self.delete(locator : Locator, recursive = false)
      # TBD implement recursive
      File.delete locator.path / locator.json_name
    end

    # Move
    def self.move(old_path : Path, new_path : Path)
      File.move old_path, new_path
    end

    # One-level meta-json children resources of type resource_type
    def self.resources(space : String, subpath : String, resource_types : Array(ResourceType)) : Array(Locator)
      list = [] of Locator
      path = Edraj.settings.data_path / "spaces" / space / subpath
      resource_types.each do |resource_type|
        extension = "#{resource_type.to_s.downcase}.json"
        Dir.glob("#{path}/*.#{extension}") do |one|
          list << Locator.new space, subpath, resource_type, UUID.new(File.basename(one, ".#{extension}"))
        end
      end

      list
    end

    # def verify_signature : Bool
    # end

    forward_missing_to @content
  end

  # class Contributer < Entry
  #  property about : String
  # end

  class Subscription < Content
    property filter : String

    def initialize(@owner, @location, @content_type, @body, @timestamp, @filter)
    end
  end

  enum ReactionType
    Agreed
    Seen
    Like
    Love
    Dislike
    Laugh
    Angry
    Sad
    Report # aka Inappropriate
  end

  class Reaction < Content
    property reaction_type : ReactionType

    def initialize(@owner, @location, @content_type, @body, @timestamp, @reaction_type)
    end
  end

  class Reply < Content
    #	property
  end

  class Message < Collection
    property from : UUID
    property to : Array(UUID)
    property thread_id : UUID

    def initialize(@owner, @location, @content_type, @body, @timestamp, @from, @to, @thread_id)
    end

    def properties(fields = {} of String => Bool, includes = [] of ResourceType)
      list, included = super(fields, includes)
      list["from"] = JSON::Any.new @from.to_s
      list["to"] = JSON.parse @to.to_json

      {list, included}
    end
  end

  class Contact < Collection
  end

  class Folder < Collection
  end

  enum EncodingType
    None
    ASCII
    UTF8
    UTF16
    Base64
  end

  class Address
  end

  enum ContactType
    Mobile
    Email
    Landphone
    SocialMedia
  end

  class ContactDetail
    include JSON::Serializable
    property type : ContactType
    property handler : String # for social media full handler e.g. fb.com/kefahi or linkedin/in/kefahi
  end

  enum IdentityType
    Device
    Application
    Browser
    Bot
    Human
  end

  @[Flags]
  enum IdentityUsage
    Sign
    Issue
    Encrypt
    Authenticate
    Certify
  end

  class Identity
    include JSON::Serializable
    property type : IdentityType
    property privileges : IdentityUsage
    property public_key : String
  end

  class Actor < Content
    property shortname : String
    property dob : String?
    property displayname : String
    property contact_details = [] of ContactDetail
    property about : String?
    property identities = [] of Identity

    def initialize(@owner, @shortname, @displayname)
    end
  end

  class Biography < Content
  end

  class Media < Content
    property bytesize : Int64
    property checksum : String
    property uri : String? # scheme:[//[user:pass@]host[:port]][/]path[?query][#fragment]
    property filename : String
    property content_type : String

    # property media_type : MediaType
    # property subtype : String
    # property encoding : EncodingType::None
    def media_type
      MEDIA_TYPE[@content_type]
    end

    def initialize(@owner, space, subpath, filename, uri = nil)
      path = Edraj.settings.data_path / "spaces" / space / subpath / filename
      raise "File doesn't exist #{subpath}/#{filename}" if (!File.exists?(path) || !File.readable?(path))
      @content_type = `file -Ebi #{path}`.strip
      @content_type.sub "; charset=us-ascii", "; charset=utf-8"
      @bytesize = `du --bytes #{path} | cut -f 1 `.to_i64
      @checksum = `sha512sum #{path} | cut -f 1 -d ' '`.strip
      # FIXME read timestamp from file
      @filename = filename
    end
  end
end
