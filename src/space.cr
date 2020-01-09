require "./actor-models"
require "./security-models"

module Edraj
  class Space
    property permissions = {} of String => Permission
    property roles = {} of String => Role
    property actors = {} of String => User | Group | Bot

    def initialize(space : String)
      path = Edraj.settings.data_path / "spaces" / space
      security = Security.from_json path, ".security.json"
      Dir.glob((path / "actors/*/*.user.json").to_s) do |userjson|
        user = User.from_json File.read userjson
        actors[user.id.to_s] = user
      end
      Dir.glob((path / "actors/*/*.group.json").to_s) do |groupjson|
        group = Group.from_json File.read groupjson
        actors[group.id.to_s] = group
      end
      # TODO load permissions and roles from secuirty
      security.permissions.each do |permission|
        @permissions[permission.shortname] = permission
      end
      security.roles.each do |role|
        @permissions[role.shortname] = role
      end
    end

    def check_access(actor_id : String, subpath : String, action : String)
    end
  end
end
