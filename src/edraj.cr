require "kemal"
require "http/web_socket"
require "json"
require "uuid"
require "uuid/json"
require "jwt"
require "colorize"
require "./exts"
require "./config"
require "./models"
require "file_utils"

#  logger.debug "#{settings.host}:#{settings.port}".colorize.yellow

include Edraj
static_headers do |response, filepath, filestat|
  if filepath =~ /\.html$/
    response.headers.add("Access-Control-Allow-Origin", "*")
  end
  response.headers.add("Content-Size", filestat.size.to_s)
end

before_all do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, POST, PUT, DELETE, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Accept, Origin, Authorization"
  env.response.headers["Access-Control-Max-Age"] = "86400"
end

options "/**" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, HEAD, POST, PUT, DELETE, OPTIONS"
end

def process_request(request : Request) : Response
  response = Response.new
  response.tracking_id = request.tracking_id if !request.tracking_id.nil?
  puts "Processing #{request.type} request"
  case request.type
  when RequestType::Create
    request.records.each do |record|
      begin
        puts "Creating record #{record.uuid}"
        record.uuid = UUID.random if record.uuid.nil?
        record.timestamp = Time.local if record.timestamp.nil?
        owner = Locator.new request.space, "members/core", ResourceType::Actor, UUID.random
        content = Content.new owner
        content.timestamp = record.timestamp
        content.title = record.properties.delete("title").to_s if record.properties.has_key? "title"
        content.location = "embedded"
        content.content_type = "text"
        content.payload = ::JSON.parse(record.properties.delete("body").to_json) if record.properties.has_key? "body"
        tags = record.properties.delete "tags"
        if tags
          tags.as_a.each { |tag| content.tags << tag.as_s }
        end

        # TBD check that record.properties is empty
        locator = Locator.new request.space, record.subpath, record.resource_type, record.uuid
        entry = Entry.new locator, content
        entry.save # "#{record.uuid.to_s}.json"
				response.results << Result.new ResultType::Success, {"message" => JSON::Any.new("#{request.type} #{entry.locator.path}/#{entry.locator.json_name}"), "uuid" => JSON::Any.new("#{record.uuid.to_s}")} of String => JSON::Any
      rescue ex
        puts "Exception"
        pp ex.backtrace?
				response.results << Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s)} of String => JSON::Any
      end
    end
  when RequestType::Update
    request.records.each do |record|
      begin
        locator = Locator.new(request.space, record.subpath, record.resource_type, record.uuid)
        entry = Entry.new locator
        entry.update record.properties
        entry.save # record.uuid.to_s
				response.results << Result.new ResultType::Success, {"message" => JSON::Any.new("#{request.type} #{request.space}/#{record.subpath}/#{record.uuid.to_s}")} of String => JSON::Any
      rescue ex
				response.results << Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s)} of String => JSON::Any
      end
    end
  when RequestType::Delete
    request.records.each do |record|
      begin
        locator = Locator.new(request.space, record.subpath, record.resource_type, record.uuid)
        Entry.delete locator
				response.results << Result.new ResultType::Success, {"message" => JSON::Any.new("#{request.type} #{request.space}/#{record.subpath}/#{record.uuid.to_s}")} of String => JSON::Any
      rescue ex
				response.results << Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s)} of String => JSON::Any end
    end
  when RequestType::Query
    actor = request.actor
    query = request.query
    raise "Actor UUID is missing" if actor.nil?
    raise "Query is missing" if query.nil?

    locator = Locator.new request.space, query.subpath, ResourceType::Folder
    entry = Entry.new locator
    resources = [] of Locator

    # case request.scope
    # when ScopeType::Base
    # when ScopeType::Onelevel
    resources.concat entry.resources query.resource_types
    # end

    count = 0
    resources.each do |one|
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
      response.records << record
      count += 1
    end
		response.results << Result.new ResultType::Success, {"returned" => JSON::Any.new(response.records.size.to_i64), "total" => JSON::Any.new(response.records.size.to_i64)} of String => JSON::Any
  when RequestType::Login
    response = Response.new
    actor = request.actor
    raise "Actor UUID is missing" if actor.nil?
    data = {"actor" => actor.to_s, "iat" => Time.local.to_unix.to_s}
    token = JWT.encode(data, Edraj.settings.jwt_secret, JWT::Algorithm::HS512)
    # record = Record.new(ResourceType::Token, actor, "/actors/kefah")
    result = Result.new ResultType::Success
		result.properties["token"] = JSON::Any.new token.to_s
    response.results << result
    return response
  when RequestType::Logout
  end
  response
end

APPLICATION_JSON = "application/json"
post "/api/" do |ctx|
  ctx.response.content_type = APPLICATION_JSON
  begin
    raise "Bad content-type" unless ctx.request.headers["Content-Type"] == APPLICATION_JSON
    puts "processing new api call ... #{ctx.request.body.to_s}"
    request = Request.from_json ctx.request.body.not_nil!
    process_request(request).to_pretty_json2
  rescue ex
		{records: [] of String, results: [Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s)} of String => JSON::Any]}.to_pretty_json2
  end
end

get "/media/:space/*subpathname" do |ctx|
  # TODO check access
  # TODO conent type
  # TODO support chunked / range download: Kemal "send_file" supports that already we just need to translate the way.
  # TODO check authtoken which should contain a signed request for granting access passed as a url param.
  # authz = ctx.params.url["authz"]
  # pp ctx.params.url
  path = Edraj.settings.data_path / "spaces" / ctx.params.url["space"] / ctx.params.url["subpathname"]
  # puts "Serving #{path}"
  send_file ctx, path.to_s
end

post "/media/*subpath" do |ctx|
  ctx.response.content_type = APPLICATION_JSON
  # subpath = ctx.params.url["subpath"]
  begin
    raw_request : String
    temp_file = File.tempfile(".edraj")
    # raw_filename = ""
    # raw_filesize = 0
    request : Request | Nil = nil
    HTTP::FormData.parse(ctx.request) do |part|
      case part.name
      when "request"
        request = Request.from_json part.body.gets_to_end
      when "file"
        # raise "No file name" unless part.filename.is_a?(String)
        temp_file = File.tempfile do |file|
          IO.copy(part.body, file)
        end
        # raw_filename = part.filename if part.filename.is_a?(String)
        # raw_filesize = part.size unless part.size.nil?
      end
    end
    # pp raw_filename.path
    # pp raw_filesize

    raise "Bad request" if request.nil?
    subpath = request.records[0].subpath
    filename = request.records[0].properties["filename"]

    raise "First record is missing subpath" if subpath.nil?
    raise "First record is missing filename" if filename.nil?

    path = Edraj.settings.data_path / "spaces" / request.space / subpath
    Dir.mkdir_p path.to_s
    puts "Copying file from #{temp_file.path} to #{path.to_s}"
    FileUtils.cp temp_file.path, "#{path.to_s}#{filename}"
    temp_file.delete

    process_request(request).to_pretty_json2
  rescue ex
    pp ex
    {records: [] of String, results: [Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s)} of String => JSON::Any]}.to_pretty_json2
  end
end

# sockets = {} of UUID => Set(HTTP::WebSocket)

ws "/websocket" do |socket, context|
  puts "Socket connected".colorize(:green)
  puts "Context #{context}".colorize(:yellow)

  ponged = true

  socket.on_message do |message|
    begin
      request = Request.from_json message.not_nil!
      socket.send process_request(request).to_pretty_json2
    rescue ex
			socket.send({records: [] of String, results: [Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s)} of String => JSON::Any]}.to_pretty_json2)
    end
  end

  socket.on_pong do
    ponged = true
  end

  socket.on_close do
  end
end

Kemal.run
