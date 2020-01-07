module Edraj

  class Entry
    property locator : Locator
    property meta_file : MetaFile

    # New / Empty
    def initialize(@locator, @meta_file, *args)
      # case @locator.resource_type
      # when ResourceType::Media
      # end
    end

    # Load existing
    def initialize(@locator)
      case @locator.resource_type
      when ResourceType::Message
        @meta_file = Message.from_json @locator.path, @locator.json_name
      when ResourceType::Post
        @meta_file = Post.from_json @locator.path, @locator.json_name
      when ResourceType::User
        @meta_file = User.from_json @locator.path, @locator.json_name
      else
        @meta_file = Content.from_json @locator.path, @locator.json_name
      end
    end

    def save
      path = locator.path
      Dir.mkdir_p path.to_s unless Dir.exists? path.to_s
      File.write path / locator.json_name, @meta_file.to_pretty_json
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
          data["id"] = slice[0].to_s
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
            id = UUID.new(data.delete("id").to_s)
            # timestamp = Time.unix(data.delete("timestamp").to_s.to_i)
            # meta = Meta.from_json({timestamp: timestamp}.to_json)
            meta = Meta.from_json("{}")
            meta.tags = data.delete("tags").to_s.split("|") if data.has_key? "tags"
            meta.body = data.delete("body").to_s if data.has_key? "body"
            meta.title = data.delete("title").to_s if data.has_key? "title"
            raise "Unprocessed data #{data.to_json}" if data.size > 0
            list << Entry.new space, subpath, resource_type, id, meta
          end
        end
        # raise "Returned #{count} but parsed #{list.size}" if count != list.size
      end
      {available, list}
    end

    def index
      args = ["FT.ADD", "#{@locator.space}Idx", @locator.id, "1.0",
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

    # forward_missing_to @meta_file

    def self.change(request_type : RequestType, space : String, record : Record) : Result
      case request_type
      when RequestType::Create
        puts "Creating record #{record.id}"
        record.id = UUID.random if record.id.nil?
        record.timestamp = Time.local if record.timestamp.nil?
        owner = Locator.new space, "members/core", ResourceType::User, UUID.random
        # owner = UUID.random
        meta_file : MetaFile
        case record.resource_type
        # when ResourceType::Media
        #  meta_file = Media.new owner, space, record.subpath, record.properties["filename"].as_s
        when ResourceType::Message
          from = UUID.new record.properties.delete("from").to_s           # if record.properties.has_key? "from"
          thread_id = UUID.new record.properties.delete("thread_id").to_s # if record.properties.has_key? "thread_id"
          _to = record.properties.delete "to"
          to = [] of UUID
          _to.as_a.each { |one| to << UUID.new one.as_s } if _to
          meta_file = Message.new owner, "embedded", from, to, thread_id
				when ResourceType::Post
					meta_file = Post.new owner
					meta_file.title = record.properties.delete("title").to_s if record.properties.has_key? "title"
					meta_file.location = "embedded"
					meta_file.content_type = record.properties.delete("content_type").to_s if record.properties.has_key? "content_type"
					meta_file.body = ::JSON.parse(record.properties.delete("body").to_json) if record.properties.has_key? "body"
					meta_file.response_to = UUID.new record.properties.delete("response_to").to_s if record.properties.has_key? "response_to"
				when ResourceType::User
					meta_file = User.new "fixme put shortname here"
				when ResourceType::Media
					meta_file = Post.new owner
        else
					raise "Unrecognized resource type #{record.resource_type}"
          #meta_file = Content.new owner
        end
        meta_file.timestamp = record.timestamp
        tags = record.properties.delete "tags"
        tags.as_a.each { |tag| meta_file.tags << tag.as_s } if tags

        pp record.properties if record.properties.size > 0

        # TBD check that record.properties is empty
				locator = Locator.new space, record.subpath, record.resource_type, record.id.to_s
        entry = Entry.new locator, meta_file
        entry.save # "#{record.id.to_s}.json"
      when RequestType::Update
				locator = Locator.new(space, record.subpath, record.resource_type, record.id.to_s)
        entry = Entry.new locator
        # FIXME entry.update record.properties
        entry.save # record.id.to_s
      when RequestType::Delete
				locator = Locator.new space, record.subpath, record.resource_type, record.id.to_s
        Entry.delete locator
      else
        raise "Invalid request type #{request_type}"
      end
      # Result.new ResultType::Success, {"message" => JSON::Any.new("#{request_type} #{entry.locator.path}/#{entry.locator.json_name}"), "id" => JSON::Any.new("#{record.id.to_s}")} of String => JSON::Any
      Result.new ResultType::Success, {"message" => JSON::Any.new("#{request_type} #{space}/#{record.subpath}/#{record.id.to_s}"), "id" => JSON::Any.new("#{record.id.to_s}")} of String => JSON::Any
    end

    def self.query(space, query)
      records = [] of Record
      # locator = Locator.new request.space, query.subpath, ResourceType::Folder
      # entry = Entry.new locator
      resources = [] of Locator

      # case request.scope
      # when ScopeType::Base
      # when ScopeType::Onelevel
      resources.concat Entry.resources space, query.subpath, query.resource_types
      # end

      count = 0
      resources.each do |one|
        puts "Retrieving meta_file #{one.id.to_s}"
        record = Record.new(one.resource_type, one.subpath, one.id)
        entry = Entry.new one
        # puts entry.meta.to_pretty_json2
        record.properties["id"] = ::JSON::Any.new entry.locator.id.to_s
        # list, _ = entry.meta_file.properties
        # ???? record.properties.merge list
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
