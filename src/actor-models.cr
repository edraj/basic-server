require "./resource"

module Edraj

  enum ActorType
    User
    Group
    Bot
  end

  class Actor < Resource
    property displayname : String
    property shortname : String
    property identities = [] of Identity
    property invitations = [] of Invitation
    property subscriptions = [] of Subscription
		property contact : Locator? # Pointer to the contact details of this actor.
    def update(list : Hash(String, ::JSON::Any))
			#case @contact
			#when Contact
			#	@contact.update list
			#end
		end
    def properties(fields = {} of String => Bool, includes = [] of ResourceType) : { Hash(String, JSON::Any), Array(Locator)}
			list = {} of String => JSON::Any
			included = [] of Locator
			{list, included}
		end
		forward_missing_to @contact
  end

  class User < Actor
  end

  class Group < Actor
    property members = [] of Actor
  end

  class Bot < Actor
  end
end
