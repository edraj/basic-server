require "json"
require "uuid"
require "uuid/json"
require "colorize"
require "./exts"
require "./config"
require "./models"

# request = Edraj::Request.from_json Path.new("./tests/"), "create-media.json"
# puts request.to_pretty_json2

# locator = Edraj::Locator.from_json({
#	uuid: "71988093-1f51-451b-8981-83cb382285e8",
#	space: "maqola",
#	subpath: "messages/teams/core/general",
#	resource_type: Edraj::ResourceType::Message
# }.to_json)

# puts locator.to_pretty_json2

# entry = Edraj::Entry.new locator
# puts entry.meta.to_pretty_json2
# entry.save

#list = Edraj::Entry.resources "maqola", "messages/teams/core/general", [Edraj::ResourceType::Message]
#pp list
