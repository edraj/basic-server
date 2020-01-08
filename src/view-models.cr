require "./resource"

module Edraj

	class View < MetaFile
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

