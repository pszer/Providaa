--
-- map edit context menu
--

local MapEditContext = {

	-- this is a function that generates the drawable
	-- text
	text_drawable_generator = nil

}
MapEditContext.__index = MapEditContext

--
-- prototype is a prop table prototype for the interal properties
-- each instance of this context menu can have, these then can
-- be dynamically filled out on instance creation
--
-- each argument after that is the definition for an option in this context menu
-- each option has the following format:
-- 1. {name, action = function, disable = bool}
-- 2. {name, suboptions = function}
--
-- in format (1), action is a function(self.props) that gets called when the option is clicked
-- if disable is set to true, the option is disabled from being clicked and is greyed out
--
-- in format (2), suboptions is a function(self.props) that when called returns
-- a table of options, these options are then displayed alongside the original context
-- menu. 
--
-- the name argument for each option can either be a string or a table. a string argument
-- behaves as you'd expect. if it's a table the string to display is formatted using string.format,
-- the first argument in the table is the string format, arguments after that are the names for
-- properties found in this context menu's property table to feed into string.format OR a
-- function(self.props) that returns the desired datum. note that these strings are made upon
-- instanciation, so they cannot be dynamically changed.
--

function MapEditContext:define(prototype, ...)
	local options = {...}

	local p = Props:prototype(prototype)
	local obj = {
		new = function(self, props, X, Y)
			local this = {
				props  = p(props),
				options = {},
				x = X,
				y = Y
			}

			return this
		end
	}

	return obj
end

function MapEditContext:setup()

end
