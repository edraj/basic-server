require "json"
require "uuid"
require "uuid/json"

alias AnyBasic = String | Int64 | Float64 | Bool

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
		def self.from_json( path : Path , storename)
			from_json File.read path / storename
		end
	end
end
