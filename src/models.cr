require "json"
require "uuid"
require "uuid/json"
require "./exts"
require "./config"

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

  EMPTY_UUID = UUID.new "00000000-0000-4000-0000-000000000000"

  class Locator
    include JSON::Serializable
		property uuid : UUID #  # Default means uuid is not specified
    property resource_type : ResourceType
    property space : String
    property subpath : String
    property uri : String? # Remote reference of the resource

		def initialize(@space, @subpath, @resource_type, @uuid = EMPTY_UUID)
		end

    def json_name
      #".#{resource_type}/#{uuid.to_s}.json"
			"#{uuid.to_s}.#{resource_type.to_s.downcase}.json"
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

  #class Signature
  #  include JSON::Serializable
  #  property fields : Array(String)
  #  property timestamp : Time
  #  property checksum : String
  #  property keyid : String
  #  property actor : UUID
  #  property hash : String
  #end

	DUMMY_LOCATOR={space: "", subpath: "", resource_type: Edraj::ResourceType::Message}.to_json

  # Primary serializable  type

	class Meta
    include JSON::Serializable
    property timestamp : Time
		property displayname : String?
		property description : String?
		property tags = Array(String).new
		property properties = Hash(String, AnyComplex).new
    property response_to : Locator?
    property related_to : Array(Relationship)?
    #property signature : Signature?
    #property author : Locator
    #property comitter : Locator  
    
	end

  class Entry
		property locator : Locator
		property meta : Meta

		# New / Empty
		def initialize(space : String, subpath : String, resource_type : ResourceType, uuid = UUID.random, @meta = Meta.from_json({timestamp: Time.local}.to_json))
			@locator = Locator.from_json({uuid: uuid, space: space, subpath: subpath, resource_type: resource_type}.to_json)
		end
    
    # forward_missing_to @meta

		# Load existing
		def initialize(@locator)
			@meta = Meta.from_json @locator.path, @locator.json_name
		end

    def save()
      path = locator.path
      Dir.mkdir_p path.to_s unless Dir.exists? path.to_s
			File.write path / locator.json_name, @meta.to_pretty_json
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

    # Delete
    def self.delete(locator : Locator, recursive = false)
			# TBD implement recursive
      File.delete locator.path / locator.json_name
    end

    # Move
    def self.move(old : Path, new : Path)
      File.move old, new
    end


    #def verify_signature : Bool
    #end

  end

  #class Contributer < Entry
  #  property about : String
  #end

  class Subscription < Meta
    property filter : String
  end

  enum ReactionType
    Like
    Love
    Dislike
    Laugh
    Angry
    Sad
  end

  class Reaction < Meta
    property reaction_type : ReactionType
  end

  class Reply < Meta
    property body : String
  end

  #  class Message < Base
  #    property subject : String?
  #		property body : String
  #    property from : UUID
  #    property to : Array(UUID)
  #    property thread_id : UUID
  #  end

  #  class Contact < Base
  #  end

  #  class Folder < Entry
  #  end

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

  class Media < Meta
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
    property type : ResourceType
    property uuid : UUID
    property timestamp : Time?
    property subpath : String
    property properties = Hash(String, AnyComplex).new
    property relationships : Hash(String, Record)?
    property op_id : String?

    def initialize(@type, @uuid, @subpath)
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
		property resource_types : Array(ResourceType)
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
