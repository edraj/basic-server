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
  # REQUEST_RESOURCE = { # {} of ReqeustType => [] of ResourceType
  #	ResourceType::Post
  # }

  # DUMMY_LOCATOR = {space: "", subpath: "", resource_type: Edraj::ResourceType::Message}.to_json

  #  class EntryMeta # Each entry has one exact meta file
  #    property tags = Array(String).new
  #		property files = Array(Content).new
  #  end

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
    property parent : NamedTuple(id: ID, resource_type: ResourceType, subpath: String)?
    property id : ID?
    property subpath : String
    property properties = Hash(String, ::JSON::Any).new
    # property relationships : Hash(String, Record)?
    property op_id : String?

    def initialize(@resource_type, @subpath, @id = nil)
    end
  end

  class Request
    include JSON::Serializable
    property type : RequestType
    property space : String
    property actor : String
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
end
