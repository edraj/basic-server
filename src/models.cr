require "json"
require "uuid"
require "uuid/json"
require "./exts"
require "./config"
require "ohm"

module Edraj
  enum ResourceType
    # Respective classes and json-schema exist
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

  enum ScopeType
    Base
    Onelevel
    Subtree
  end

  class Notification
    include JSON::Serializable
    property actor : Locator      # Who did it?
    property timestamp : Time     # When start?
    property action : RequestType # What was the nature of the action
    property resource : Locator   # Where was it applied
    property duration : Int32     # How long did it take in milliseconds
    property commit : String      # Git commit hash
    property result : String      # How did it conclude?
    property result_type : ResultType
    property properties : Hash(String, AnyComplex)
  end

  # Empty UUID "00000000-0000-4000-0000-000000000000"

  class Locator
    include JSON::Serializable
		property uuid : UUID? # folder meta file is .meta.json 
		property resource_type : ResourceType
    property space : String
    property subpath : String
    property uri : String? # Remote reference of the resource

    def initialize(@space, @subpath, @resource_type, @uuid = nil)
    end

    def json_name
      "#{uuid.to_s}.meta.json"
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

  #DUMMY_LOCATOR = {space: "", subpath: "", resource_type: Edraj::ResourceType::Message}.to_json

  # Primary serializable  type
	class Content # Each entry has one or more payload  
    include JSON::Serializable
		property location : String # file://filepathname, embedded://, uri://server...
		property timestamp : Time
    property tags = Array(String).new
    property title : String? # subject / displayname
    property description : String?
    property body : ::JSON::Any
		property content_type : String # json+schema, media+subtype, folder, ...
		property content_encoding : String?
		property actor : Locator? # Actor who caused this payload to be created: user, app (iot) ...
		property owner : Locator # Owner of the payload : user, group ...
    property author : Locator? # Original author of the content
    property response_to : Locator?
    property related_to : Array(Relationship)?
    property signatures : Array(Signature)?

		def json_content
			return @body if @location.starts_with? "embedded://"
			return ::JSON.parse File.read @location.lchop "file://" if @location.starts_with? "file://"
		end

		def string_conent
			return @body.to_s if @location.starts_with? "embedded://"
			return File.read @location.lchop "file://" if @location.starts_with? "file://"

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
    property collection  : Collection

    # New / Empty
		def initialize(@locator, @collection)
		end

    # Load existing
    def initialize(@locator)
      @collection = Collection.from_json @locator.path, @locator.json_name
    end

    def save
      path = locator.path
      Dir.mkdir_p path.to_s unless Dir.exists? path.to_s
      File.write path / locator.json_name, @collection.to_pretty_json
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
            #timestamp = Time.unix(data.delete("timestamp").to_s.to_i)
            #meta = Meta.from_json({timestamp: timestamp}.to_json)
            meta = Meta.from_json("{}")
            meta.tags = data.delete("tags").to_s.split("|") if data.has_key? "tags"
            meta.body = data.delete("body").to_s if data.has_key? "body"
            meta.title = data.delete("title").to_s if data.has_key? "title"
            raise "Unprocessed data #{data.to_json}" if data.size > 0
            list << Entry.new space, subpath, resource_type, uuid, meta
          end
        end
        #raise "Returned #{count} but parsed #{list.size}" if count != list.size
      end
			{available, list}
    end

    def index
      args = ["FT.ADD", "#{@locator.space}Idx", @locator.uuid, "1.0",
              "LANGUAGE", "english", "FIELDS",
              "subpath", @locator.subpath,
              "resource_type", @locator.resource_type.to_s.downcase,
              #"timestamp", @meta.timestamp.to_unix,
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

    forward_missing_to @meta
  end

  # class Contributer < Entry
  #  property about : String
  # end

  class Subscription < Content
    property filter : String
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
  end

  #class Reply 
	#	property 
  #end

  class Message < Collection
    property from : UUID
    property to : Array(UUID)
    property thread_id : UUID
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

  enum MediaType
    Audio
    Video
    Picture
    Document
    Database
    Data
  end

  MEDIA_SUBTYPES = {
    MediaType::Audio    => Set{"mp3", "ogg", "wav"},
    MediaType::Video    => Set{"mp4", "webm"},
    MediaType::Document => Set{"pdf", "word"},
    MediaType::Picture  => Set{"png", "jpeg", "gif"},
    MediaType::Data     => Set{"json", "yaml", "xml", "csv"},
    MediaType::Database => Set{"sqlite3"},
  }

  class Media < Content
    property bytesize : Int64
    property checksum : String
    property uri : String # scheme:[//[user:pass@]host[:port]][/]path[?query][#fragment]
    property filename : String
    property media_type : MediaType
    property subtype : String
    property encoding : EncodingType
  end

  class Record
    include JSON::Serializable
		property resource_type : ResourceType
    property uuid : UUID?
    property subpath : String
    property properties = Hash(String, AnyComplex).new
    property relationships : Hash(String, Record)?
    property op_id : String?

		def initialize(@resource_type, @subpath, @uuid = nil)
    end
  end

  enum OrderType
    Natural
    Random
  end

  class Query
    include JSON::Serializable
    property subpath : String
    property resources : Array(UUID)?
    property content_types : Array(String)
    property search : String?
    property from_date : Time?
    property to_date : Time?
    property excluded_fields : Array(String)?
    property included_fields : Array(String)?
    property sort = Array(String).new
    property order = Edraj::OrderType::Natural
    property limit = 10
    property offset = 0
    property suggested = false
    property tags = Array(String).new
  end

  enum RequestType
    Create
    Update
    Delete
    Query
    Login
    Logout
  end

  class Request
    include JSON::Serializable
    property type : RequestType
    property space : String
    property actor : UUID
    property token : String
    property scope : ScopeType
    property tracking_id : String?
    property query : Query?
    property records : Array(Record)
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
    # property message : String?
    property properties : Hash(String, AnyBasic)

    def initialize(@status, @properties = Hash(String, AnyBasic).new)
    end
  end

  class Response
    include JSON::Serializable
    property tracking_id : String?
    property records = Array(Record).new
    property included : Array(Record)?
    property suggested : Array(Record)?
    property results = Array(Result).new

    def initialize
    end
  end
end
