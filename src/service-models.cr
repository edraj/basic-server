require "json"
require "uuid"
require "uuid/json"
require "./exts"
require "./config"
require "./mime"
require "./attachment-models"
require "./content-models"
require "./actor-models"
require "ohm"

module Edraj


	#REQUEST_RESOURCE = { # {} of ReqeustType => [] of ResourceType
	#	ResourceType::Post 
	#}



  # DUMMY_LOCATOR = {space: "", subpath: "", resource_type: Edraj::ContentType::Message}.to_json

  #  class EntryMeta # Each entry has one exact meta file
  #    property tags = Array(String).new
  #		property files = Array(Content).new
  #  end

  enum RequestType
    Create
    Update
    Delete
		Send
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

  enum ScopeType
    Base
    Onelevel
    Subtree
  end


  class Record
    include JSON::Serializable
    property timestamp : Time = Time.local
    property resource_type : ResourceType
    property uuid : UUID?
    property subpath : String
    property properties = Hash(String, ::JSON::Any).new
    property relationships : Hash(String, Record)?
    property op_id : String?

    def initialize(@resource_type, @subpath, @uuid = nil)
    end
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

  # enum ResultType
  #  Success
  #  Inprogress # aka Processing
  #  Partial
  #  Failure
  # end

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

  class Entry
    property locator : Locator
    property content : Actor | Content | Message

    # New / Empty
    def initialize(@locator, @content, *args)
      # case @locator.resource_type
      # when ContentType::Media
      # end
    end

    # Load existing
    def initialize(@locator)
      case @locator.resource_type
      when ContentType::Message
        @content = Message.from_json @locator.path, @locator.json_name
      when ContentType::Post
        @content = Post.from_json @locator.path, @locator.json_name
      else
        @content = Content.from_json @locator.path, @locator.json_name
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
    def self.resources(space, subpath, resource_types : Array(ResourceType)) : Array(Locator)
      list = [] of Locator
      resource_types.each do |resource_type|
        extension = "#{resource_type.to_s.downcase}.json"
        Dir.glob("#{Edraj.settings.data_path / "spaces" / space / subpath}/*.#{extension}") do |one|
          list << Locator.new space, subpath, resource_type, UUID.new(File.basename(one, ".#{extension}"))
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
            resource_type = ContentType.parse(data.delete("resource_type").to_s)
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

    def self.change(request_type : RequestType, space : String, record : Record) : Result
      case request_type
      when RequestType::Create
        puts "Creating record #{record.uuid}"
        record.uuid = UUID.random if record.uuid.nil?
        record.timestamp = Time.local if record.timestamp.nil?
        owner = Locator.new space, "members/core", ResourceType::User, UUID.random
        # owner = UUID.random
        content : Content
        case record.resource_type
        # when ContentType::Media
        #  content = Media.new owner, space, record.subpath, record.properties["filename"].as_s
        when ContentType::Message
          from = UUID.new record.properties.delete("from").to_s           # if record.properties.has_key? "from"
          thread_id = UUID.new record.properties.delete("thread_id").to_s # if record.properties.has_key? "thread_id"
          _to = record.properties.delete "to"
          to = [] of UUID
          _to.as_a.each { |one| to << UUID.new one.as_s } if _to
          content = Message.new owner, "embedded", from, to, thread_id
        else
          content = Content.new owner
        end
        content.timestamp = record.timestamp
        content.title = record.properties.delete("title").to_s if record.properties.has_key? "title"
        content.location = "embedded"
        content.content_type = record.properties.delete("content_type").to_s if record.properties.has_key? "content_type"
        content.body = ::JSON.parse(record.properties.delete("body").to_json) if record.properties.has_key? "body"
        content.response_to = UUID.new record.properties.delete("response_to").to_s if record.properties.has_key? "response_to"
        tags = record.properties.delete "tags"
        tags.as_a.each { |tag| content.tags << tag.as_s } if tags

        pp record.properties if record.properties.size > 0

        # TBD check that record.properties is empty
        locator = Locator.new space, record.subpath, record.resource_type, record.uuid
        entry = Entry.new locator, content
        entry.save # "#{record.uuid.to_s}.json"
      when RequestType::Update
        locator = Locator.new(space, record.subpath, record.resource_type, record.uuid)
        entry = Entry.new locator
        entry.update record.properties
        entry.save # record.uuid.to_s
      when RequestType::Delete
        locator = Locator.new(space, record.subpath, record.resource_type, record.uuid)
        Entry.delete locator
      else
        raise "Invalid request type #{request_type}"
      end
      # Result.new ResultType::Success, {"message" => JSON::Any.new("#{request_type} #{entry.locator.path}/#{entry.locator.json_name}"), "uuid" => JSON::Any.new("#{record.uuid.to_s}")} of String => JSON::Any
      Result.new ResultType::Success, {"message" => JSON::Any.new("#{request_type} #{space}/#{record.subpath}/#{record.uuid.to_s}"), "uuid" => JSON::Any.new("#{record.uuid.to_s}")} of String => JSON::Any
    end

    def self.query(space, query)
      records = [] of Record
      # locator = Locator.new request.space, query.subpath, ContentType::Folder
      # entry = Entry.new locator
      resources = [] of Locator

      # case request.scope
      # when ScopeType::Base
      # when ScopeType::Onelevel
      resources.concat Entry.resources space, query.subpath, query.resource_types
      # end

      count = 0
      resources.each do |one|
        puts "Retrieving content #{one.uuid.to_s}"
        record = Record.new(one.resource_type, one.subpath, one.uuid)
        entry = Entry.new one
        # puts entry.meta.to_pretty_json2
        record.properties["uuid"] = ::JSON::Any.new entry.locator.uuid.to_s
        list, _ = entry.properties
        record.properties.merge list
        # record.properties["from"] = ::JSON::Any.new entry.from.to_s
        # record.properties["to"] = entry.to
        # record.properties["title"] = ::JSON::Any.new entry.title.to_s if !entry.title.nil?
        # record.properties["body"] = entry.json_payload

        # record.timestamp = entry.meta.timestamp
        # record.properties["subpath"] = subpath
        records << record
        count += 1
      end
      {records, Result.new ResultType::Success, {"returned" => JSON::Any.new(records.size.to_i64), "total" => JSON::Any.new(records.size.to_i64)} of String => JSON::Any}
    end
  end
end
