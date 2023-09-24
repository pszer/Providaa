--
-- map edit context menu
--

require "prop"

local guirender = require 'mapeditguidraw'

local MapEditContext = {
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
-- 3. {name}
--
-- in format (1), action is a function(self.props) that gets called when the option is clicked
-- if disable is set to true, the option is disabled from being clicked and is greyed out
--
-- in format (2), suboptions is a function(self.props) that when called returns
-- a table of options, these options are then displayed alongside the original context
-- menu. 
--
-- format (3) is simply text
--
-- the name argument for each option can either be a string or a table. a string argument
-- behaves as you'd expect. if it's a table the string to display is formatted using string.format,
-- the first argument in the table is the string format, arguments after that are the names for
-- properties found in this context menu's property table to feed into string.format OR a
-- function(self.props) that returns the desired datum. note that these strings are made upon
-- instanciation, so they cannot be dynamically changed.
-- look at mapeditguidraw.lua createDrawableText() for extra text formatting options
--

function MapEditContext:define(prototype, ...)
	local options = {args}

	local p = Props:prototype(prototype)
	local obj = {
		new = function(self, props, X, Y)
			local this = {
				props  = p(props),
				options = {},
				x = X,
				y = Y
			}

			for i,v in ipairs(options) do
				local name = v[1]
				local action  = v.action
				local disable = v.disable
				local subopt  = v.suboptions
				local text_drawable = nil

				assert(name, "MapEditContext:define(): no name given for an option")

				if action and subopt then
					error("MapEditContext:define(): option has both an action and suboption generator")
				end

				local str = nil
				if name == "string" then
				 	str = name
				else
					local str_f = name[1]
					local str_d = {}
					for i=2,#name do
						str_d = this.props[name[i]]
					end
					str = string.format(str_f, unpack(str_d))
				end
				text_drawable = guirender:createDrawableText(str)

				if subopt then
					subopt = subopt(this.props)
				end

				local o = {text=text_drawable, action=action, suboptions=subopt, disable=disable}
				this.options[i] = options
			end

			return this
		end
	}

	return obj
end

return MapEditContext
