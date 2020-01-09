require "json"
require "uuid"
require "uuid/json"

# alias AnyBasic = String | Int64 | Float64 | Bool
# alias AnyComplex = AnyBasic | Array(AnyBasic) | Hash(String, AnyBasic)

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

module JSON::Serializable
  macro included
		def self.from_json( path : Path , filename)
			from_json File.read path / filename
		end
	end
end

# Needed to be able to persist UUID as Hash key in json
struct UUID
  def to_json_object_key
    to_s
  end

  def self.from_json_object_key?(key : String)
    UUID.new key
  end
end
