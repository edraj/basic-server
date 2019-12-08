require "kemal"
require "http/web_socket"
require "json"
require "uuid"
require "uuid/json"
require "jwt"
require "colorize"
require "./config"
require "./models"

#  logger.debug "#{settings.host}:#{settings.port}".colorize.yellow

include Edraj

class Object
  def to_pretty_json2
    "#{to_pretty_json}\n"
  end
end

struct Enum
  def to_json(json : JSON::Builder)
    json.string(to_s)
  end
end

class Record
  include JSON::Serializable
  property type : ResourceType
  property uuid : UUID
  property parent_path : String
  property fields = Hash(String, String | Int64 | Float64 | Bool).new
  property relationships : Hash(String, Record)?

  def initialize(@type, @uuid, @parent_path)
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
  property parent_path : String
  property sub_path = ""
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
  property actor : UUID?
  property token : String
  property scope : ScopeType
  property tracking_id : String?
  property query : Query?
  property data : Array(Record)
end

enum ResultType
  Success
  Processing
  Failed
end

class ErrorSource
  include JSON::Serializable
  property pointer : String?
  property parameter : String?
end

class Error
  include JSON::Serializable
  property? id : String
  property? code : String
  property? title : String
  property? detail : String
  property? source : ErrorSource
end

class Result
  include JSON::Serializable
  property type : ResultType
  property errors : Array(Error)?
  property count : Int64 = 0

  def initialize(@type)
  end
end

class Response
  include JSON::Serializable
  property tracking_id : String?
  property uuid : UUID?
  property data = Array(Record).new
  property included : Array(Record)?
  property suggested : Array(Record)?
  property result : Result

  def initialize(@result)
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
  response = Response.new(Result.new ResultType::Success)
  case request.type
  when RequestType::Create
    request.data.each do |record|
      case record.type
      when ResourceType::Message
      end
    end
  when RequestType::Update
    request.data.each do |record|
      case record.type
      when ResourceType::Message
      end
    end
  when RequestType::Query
    actor = request.actor
    query = request.query
    raise "Actor UUID is missing" if actor.nil?
    raise "Query is missing" if query.nil?
    parent_path = query.parent_path
    sub_path = query.sub_path

    resources = [] of UUID

    case request.scope
    when ScopeType::Base
			resources.concat query.resources if request.scope == ScopeType::Base
		when ScopeType::Onelevel
			resources.concat Message.list parent_path, sub_path
    end

    resources.each do |one|
      record = Record.new(ResourceType::Message, actor, parent_path)
      message = Message.load(parent_path, sub_path, one)
      record.fields["from"] = message.from.to_s
      record.fields["to"] = message.to.join(",")
      record.fields["body"] = message.body
      record.fields["timestamp"] = message.timestamp.to_rfc3339
      record.fields["sub_path"] = sub_path
      response.data << record
			response.result.count += 1
    end
  when RequestType::Delete
    request.data.each do |record|
      case record.type
      when ResourceType::Message
      end
    end
  when RequestType::Login
    response = Response.new(Result.new ResultType::Success)
    actor = request.actor
    raise "Actor UUID is missing" if actor.nil?
    data = {"actor" => actor.to_s, "iat" => Time.local.to_unix.to_s}
    token = JWT.encode(data, Edraj.settings.jwt_secret, JWT::Algorithm::HS512)
    record = Record.new(ResourceType::Token, actor, "/actors/kefah")
    record.fields["token"] = token.to_s
    response.data << record
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

post "/media" do |ctx|
  ctx.response.content_type = "application/json"
end

sockets = {} of UUID => Set(HTTP::WebSocket)

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
