require "kemal"
require "http/web_socket"
require "json"
require "uuid"
require "uuid/json"
require "jwt"
require "colorize"
require "./exts"
require "./config"
require "./service-models"
require "./entry"
require "file_utils"

include Edraj

module Edraj

#  logger.debug "#{settings.host}:#{settings.port}".colorize.yellow
Log.debug { "Settings #{settings.host}:#{settings.port}" }

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
  start = Time.monotonic
  response = Response.new
  response.tracking_id = request.tracking_id if !request.tracking_id.nil?
  puts "Processing #{request.type} request"
  # Impossible raise "Actor UUID is missing" if actor.nil?
  space = request.space
  raise "Space is bad or not approved (#{space})" unless Edraj.settings.spaces.includes? space
  actor = Locator.new space, "actors", ResourceType::User, request.actor
  begin
    case request.type
    when RequestType::Create, RequestType::Update, RequestType::Delete
      request.records.each do |record|
        begin
          locator = Locator.new space, record.subpath, record.resource_type, record.id.to_s
					resource_category = locator.resource_type.category

          case resource_category
          when ResourceCategory::Content
            response.results << Entry.process_content actor, request.type, locator, record
          when ResourceCategory::Attachment
            parent_tuple = record.parent
            raise "Resource of Attachment category requires Parent fields to be provided, none found" if parent_tuple.nil?
            parent = Locator.new space, parent_tuple[:subpath], parent_tuple[:resource_type], parent_tuple[:id]
            response.results << Entry.process_attachment actor, request.type, parent, locator, record
          when ResourceCategory::Actor
          when ResourceCategory::AuthItem
          when ResourceCategory::Logic
          else
            raise "Unsupported resource type #{record.resource_type} category #{resource_category}"
          end
        rescue ex
					puts "Error: #{ex.to_s}"
					puts ex.backtrace?.to_pretty_json2
          response.results << Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s), "backtrace" => JSON::Any.new(ex.backtrace?.to_s)} of String => JSON::Any
        ensure
          # TBD build notification object and trigger to respective redis and sockets
          # through channels?
          # including updating json documents and index on redis
          puts "process record completed"
        end
      end
    when RequestType::Query
      query = request.query
      raise "Query is missing" if query.nil?
      records, result = Entry.query space, query
      response.records = records
      response.results << result
    when RequestType::Send
    when RequestType::Login
      actor = request.actor
      raise "Actor UUID is missing" if actor.nil?
      data = {"actor" => actor.to_s, "iat" => Time.local.to_unix.to_s}
      token = JWT.encode(data, Edraj.settings.jwt_secret, JWT::Algorithm::HS512)
      # record = Record.new(ResourceType::Token, actor, "/actors/kefah")
      result = Result.new ResultType::Success
      result.properties["token"] = JSON::Any.new token.to_s
      response.results << result
      # when RequestType::Logout
    end
  rescue ex
		puts "Error: #{ex.to_s}"
		puts ex.backtrace?.to_pretty_json2
    response.results << Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s), "backtrace" => JSON::Any.new(ex.backtrace?.to_s)} of String => JSON::Any
  ensure
    duration = Time.monotonic - start
    puts "Duration #{duration.total_nanoseconds} nanoseconds"
    # TBD build notification object and trigger to respective redis and sockets
    # through channels?
    # a log folder is maintained under the  content's folder.
  end
  response
end

APPLICATION_JSON = "application/json"
post "/api/" do |ctx|
  ctx.response.content_type = APPLICATION_JSON
  begin
    raise "Bad content-type" unless ctx.request.headers["Content-Type"] == APPLICATION_JSON
    request = Request.from_json ctx.request.body.not_nil!
    process_request(request).to_pretty_json2
  rescue ex
		puts "Error: #{ex.to_s}"
		puts ex.backtrace?.to_pretty_json2
    {records: [] of String, results: [Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s), "backtrace" => JSON::Any.new(ex.backtrace?.to_s)} of String => JSON::Any]}.to_pretty_json2
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
				raw_request = part.body.gets_to_end
				# puts "REQUEST: #{raw_request}"
        request = Request.from_json raw_request
      when "file"
        # raise "No file name" unless part.filename.is_a?(String)
        temp_file = File.tempfile do |file|
          IO.copy(part.body, file)
        end
        # raw_filename = part.filename if part.filename.is_a?(String)
        # raw_filesize = part.size unless part.size.nil?
      else
        # TBD
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
    request.records[0].properties["content_type"] = JSON::Any.new `file -Ebi #{path.to_s}#{filename}`.strip
    temp_file.delete

    process_request(request).to_pretty_json2
  rescue ex
		puts "Error: #{ex.to_s}"
		puts ex.backtrace?.to_pretty_json2
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

end
