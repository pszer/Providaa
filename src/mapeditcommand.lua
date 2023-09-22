require "prop"

MapEditCom = {}
MapEditCom.__index = MapEditCom

function MapEditCom:define(action, undo, prototype)
	local p = Props:prototype(prototype)
	local obj = {
		new = function(self, props)
			local this = {
				props  = p(props),
				action = action,
				undo   = undo
			}

			return props
		end
	}

	return obj
end
