require "./models"
require "colorize"

space = "maqola"

index = "#{space}Idx"

begin
	Ohm.redis.call "FT.DROP", index
rescue ex
	puts ex.message.colorize.red
end
Ohm.redis.call "FT.CREATE", index, "SCHEMA",
  "subpath", "TEXT", "NOSTEM", "SORTABLE",
  "resource_type", "TEXT", "NOSTEM", "SORTABLE",
  "title", "TEXT", "WEIGHT", "5.0", "SORTABLE",
  "body", "TEXT",
  "author", "TEXT", "NOSTEM", "SORTABLE",
  "timestamp", "NUMERIC",
  "description", "TEXT",
  "owner", "TEXT", "NOSTEM", "SORTABLE",
  "tags", "TAG", "SEPARATOR", "|"

# locator = Edraj::Locator.from_json({
#	uuid: "71988093-1f51-451b-8981-83cb382285e8",
#	space: "maqola",
#	subpath: "messages/teams/core/general",
#	resource_type: Edraj::ResourceType::Message
# }.to_json)

space = "maqola"
list = Edraj::Entry.resources space, "messages/teams/core/general", [Edraj::ResourceType::Message]

# entry = Edraj::Entry.new locator
# puts entry.to_pretty_json2

list.each do |locator|
  entry = Edraj::Entry.new locator
  entry.index
end

entries = Edraj::Entry.search space, "he*"
puts "Returned #{entries.size} results"
entries.each do |entry|
	puts "Found #{entry.locator.path}/#{entry.locator.json_name}"
end

# ret = Ohm.redis.call "FT.SEARCH", "#{space}Idx", "hey", "language", "english"
# if ret.is_a? Array(Resp::Reply)
#  puts "Got #{ret[0]} results".colorize.red
#  ret.skip(1).each_slice(2) do |slice|
#    puts "Doc id #{slice[0]}".colorize.green
#    props = slice[1]
#    if props.is_a? Array(Resp::Reply)
#      props.each_slice(2) do |property|
#        print "#{property[0]} => ".colorize.blue
#        val = property[1]
#        if val.is_a? String
#          case property[0]
#          when "timestamp"
#            puts Time.unix(val.to_i).to_rfc3339
#          when "tags"
#            puts val.split("|")
#          when "resource_type"
#            puts Edraj::ResourceType.parse(val)
#          else
#            puts "#{val}".colorize.yellow
#          end
#        end
#      end
#    end
#  end
# end

# Ohm.redis.flushall
# Ohm.redis.set "Foo", "Bar"
# res = Ohm.redis.get "Foo"
# puts "Get Foo #{res}"

# ret = Ohm.redis.keys("*")
# puts typeof(ret)
# puts ret.class

# if ret.is_a?(Array(Resp::Reply))
#  ret.each do |key|
#    type = Ohm.redis.type key
#    print "#{key} => #{type} "
#    rprint key, type.to_s
#  end
# end

def rprint(key : Array(Resp::Reply) | String | Int64 | Nil, type : String)
  # val : Array(Resp::Reply) | Int64 | String | Nil )
  # type = Ohm.redis.type key
  # print " #{type} / #{key.class} "
  case type
  when "string"
    val = Ohm.redis.get key
    # print " #{typeof(val)} / #{val.class} = #{val}"
    print " #{val} "
  when "set"
    val = Ohm.redis.smembers key
    # print " #{typeof(val)} / #{val.class} "
    if val.is_a? Array(Resp::Reply)
      print " {#{val.size}} "
      val.each do |v|
        if !v.is_a? String
          print " NON-string value! #{v.class} "
        end
        print " #{v}, "
      end
    end
  when "hash"
    val = Ohm.redis.hgetall key
    if val.is_a? Array(Resp::Reply)
      val.each_slice(2) do |slice|
        print " #{slice[0]} => #{slice[1]}, "
      end
    else
      print " NON-Array value! #{val.class} "
    end
  end
  puts ""
end
