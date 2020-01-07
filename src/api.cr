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
  start = Time.monotonic
  response = Response.new
  response.tracking_id = request.tracking_id if !request.tracking_id.nil?
  puts "Processing #{request.type} request"
  actor = request.actor
  # Impossible raise "Actor UUID is missing" if actor.nil?
  space = request.space
  raise "Space is bad not approved (#{space})" unless Edraj.settings.spaces.includes? space
  begin
    case request.type
    when RequestType::Create, RequestType::Update, RequestType::Delete
      request.records.each do |record|
        begin
          response.results << Entry.change request.type, space, record
        rescue ex
          response.results << Result.new ResultType::Failure, {"message" => JSON::Any.new(ex.to_s), "backtrace" => JSON::Any.new(ex.backtrace?.to_s)} of String => JSON::Any
        end
      end
    when RequestType::Query
      query = request.query
      raise "Query is missing" if query.nil?
      records, result = Entry.query space, query
      response.records = records
      response.results << result
    when RequestType::Login
      actor = request.actor
      raise "Actor UUID is missing" if actor.nil?
      data = {"actor" => actor.to_s, "iat" => Time.local.to_unix.to_s}
      token = JWT.encode(data, Edraj.settings.jwt_secret, JWT::Algorithm::HS512)
      # record = Record.new(ContentType::Token, actor, "/actors/kefah")
      result = Result.new ResultType::Success
      result.properties["token"] = JSON::Any.new token.to_s
      response.results << result
      # when RequestType::Logout
    end
  rescue ex
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
    request.records[0].properties["content_type"] = JSON::Any.new `file -Ebi #{path.to_s}#{filename}`.strip
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
