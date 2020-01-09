require "./resource"

module Edraj
  # class Permission < Attachment
  # end

  # class Role < Attachment
  #	property permissions = [] of Permission
  # end

  # class Entitlement < Attachment
  #	property role : Locator
  #	property assigned_actors = [] of Locator
  # end

  abstract class AuthItem < Resource
    property shortname : String # Must be unique within space
    property description : String?
  end

  class Permission < AuthItem
    property subpath : String
    property resource_types = [] of ResourceType
    property actions = [] of String
  end

  class Role < AuthItem
    property permissions = [] of String #
    property entitled_actors = [] of String
  end

  class Security < MetaFile
    property permissions = [] of Permission
    property roles = [] of Role

    def update(list : Hash(String, ::JSON::Any))
      # case @contact
      # when Contact
      #	@contact.update list
      # end
    end

    def properties(fields = {} of String => Bool, includes = [] of ResourceType) : {Hash(String, JSON::Any), Array(Locator)}
      list = {} of String => JSON::Any
      included = [] of Locator
      {list, included}
    end
  end
end
