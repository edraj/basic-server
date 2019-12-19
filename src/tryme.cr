require "json"
require "uuid"
require "uuid/json"
require "colorize"
require "./exts"
require "./config"
require "./models"

raw = %(
{
	"a": 1
}
)

request = Edraj::Request.from_json Path.new("./tests/"), "create-media.json"

puts request.to_pretty_json2
