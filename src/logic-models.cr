require "./resource"

module Edraj
  class Logic < MetaFile
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
