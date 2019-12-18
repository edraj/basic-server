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

#  logger.debug "#{settings.host}:#{settings.port}".colorize.yellow

include Edraj

class Record
  include JSON::Serializable
  property type : ResourceType
  property uuid : UUID
  property subpath : String
  property properties = Hash(String, AnyBasic).new
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
  property resources = Array(UUID).new
  property search = ""
  property from_date : Time?
  property to_date : Time?
  property subpath : String
  property excluded_fields = Array(String).new
  property included_fields : Array(String)?
  property sort = Array(String).new
  property order = OrderType::Natural
  property limit = 10
  property offset = 0
  property suggested = false
  property tags = Array(String).new
end

enum RequestType
  Create
  Update
  Query
  Delete
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

# class ErrorSource
#  include JSON::Serializable
#  property pointer : String?
#  property parameter : String?
# end

# class Error
#  include JSON::Serializable
#  property? id : String
#  property? code : String
#  property? title : String
#  property? detail : String
#  property? source : ErrorSource
# end

class Result
  include JSON::Serializable
  property result_type : ResultType
  property properties = Hash(String, AnyBasic).new

  def initialize(@result_type)
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
  case request.type
  when RequestType::Create
    request.records.each do |record|
      begin
        raw = {
          space:      request.space,
          subpath:    record.subpath,
          type:       record.type,
          properties: record.properties,
          uuid:       record.uuid,
        }
        entry = Entry.from_json(raw.to_json)
        entry.save record.uuid.to_s
        response.results << Result.new ResultType::Success
      rescue ex      
        result = Result.new ResultType::Failure
        result.properties["Message"] = ex.to_s
        response.results <<  result
      end
    end
  when RequestType::Update
    request.records.each do |record|
      entry = Entry.from_json Edraj.settings.data_path / request.space / record.subpath, record.uuid.to_s
      entry.properties.merge record.properties
      entry.save record.uuid.to_s
    end
  when RequestType::Delete
    request.records.each do |record|
      Entry.delete Edraj.settings.data_path / request.space / record.subpath, record.uuid.to_s
      response.results << Result.new ResultType::Success
      
    end
  when RequestType::Query
    actor = request.actor
    query = request.query
    raise "Actor UUID is missing" if actor.nil?
    raise "Query is missing" if query.nil?
    subpath = query.subpath

    resources = [] of UUID

    case request.scope
    when ScopeType::Base
      resources.concat query.resources if request.scope == ScopeType::Base
    when ScopeType::Onelevel
      resources.concat Entry.list Edraj.settings.data_path / subpath
    end

    count = 0
    resources.each do |one|
      record = Record.new(ResourceType::Message, actor, subpath)
      entry = Entry.from_json Edraj.settings.data_path / request.space / subpath, one.to_s
      record.properties["from"] = entry.properties["from"].to_s
      record.properties["to"] = entry.properties["to"]
      record.properties["body"] = entry.properties["body"]
      record.properties["timestamp"] = entry.timestamp.to_rfc3339
      record.properties["subpath"] = subpath
      response.records << record
      count += 1
    end
  when RequestType::Login
    response = Response.new
    actor = request.actor
    raise "Actor UUID is missing" if actor.nil?
    data = {"actor" => actor.to_s, "iat" => Time.local.to_unix.to_s}
    token = JWT.encode(data, Edraj.settings.jwt_secret, JWT::Algorithm::HS512)
    #record = Record.new(ResourceType::Token, actor, "/actors/kefah")
    result = Result.new ResultType::Success
    result.properties["token"] = token.to_s
    response.results << result
    return response
  when RequestType::Logout
  end
  response
end

APPLICATION_JSON = "application/json"
E415             = {data: [] of Int32, result: {type: "Failed", title: "Unsupported"}}.to_pretty_json2
E406             = {data: [] of Int32, result: {type: "Failed", title: "Unacceptable"}}.to_pretty_json2
post "/api/" do |ctx|
  ctx.response.content_type = APPLICATION_JSON
  halt ctx, status_code: 415, response: E415 if ctx.request.headers["Content-Type"]? != APPLICATION_JSON
  halt ctx, status_code: 406, response: E406 if ctx.request.headers["Accept"]? != APPLICATION_JSON
  begin
    request = Request.from_json ctx.request.body.not_nil!
    process_request(request).to_pretty_json2
  rescue ex
    {result: {type: "Failed", title: "Bad request", detail: "#{ex.message}"}}.to_pretty_json2
  end
end

get "/media" do |ctx|
  # TODO check access
  # TODO conent type
  # TODO support chunked / range download: Kemal "send_file" supports that already we just need to translate the way.
  send_file ctx, "/path/to/media/file"
end

post "/media" do |ctx|
  ctx.response.content_type = "application/json"
end

# sockets = {} of UUID => Set(HTTP::WebSocket)

ws "/websocket" do |socket|
  puts "Socket connected".colorize(:green)
  ponged = true

  socket.on_message do |message|
    begin
      request = Request.from_json message.not_nil!
      process_request request
    rescue ex
      {result: {type: "Failed", title: "Bad request", detail: "#{ex.message}"}}.to_pretty_json2
    end
  end

  socket.on_pong do
    ponged = true
  end

  socket.on_close do
  end
end

Kemal.run
