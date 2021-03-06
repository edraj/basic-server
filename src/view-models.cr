require "./resource"

module Edraj
  class View < MetaFile
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

  class Page < View
    # title / description
    # How many coloumns
    # What blocks for each coloumns and the parameters to the blocks
  end

  class Block < View
    # Visual block (a section in a page) uses code to render zero or more logic models
    # css (visual rendering) elements
  end
end
