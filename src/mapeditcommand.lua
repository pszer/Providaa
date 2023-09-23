require "prop"

MapEditCom = {}
MapEditCom.__index = MapEditCom

function MapEditCom:define(prototype, action, undo)
	local p = Props:prototype(prototype)
	local obj = {
		new = function(self, props)
			local this = {
				props  = p(props),
				__action = action,
				__undo   = undo,

				commit = function(self)
					self.__action(props)
				end,

				undo = function(self)
					self.__undo(props)
				end
			}

			return this
		end
	}

	return obj
end
