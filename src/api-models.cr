module Edraj
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
    property properties : Hash(String, ::JSON::Any)
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
    Partial
    Failure
  end

  class Result
    include JSON::Serializable
    property status : ResultType
    property code : Int64?
    # property message : String?
    property properties : Hash(String, JSON::Any)

    def initialize(@status, @properties = Hash(String, JSON::Any).new)
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
