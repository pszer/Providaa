local guirender = require 'mapedit.guidraw'
local MapEditPopup = {
	lifetime = 1.5
}
MapEditPopup.__index = MapEditPopup

function MapEditPopup:throw(str, ...)
	local args = {...}
	local str = string.format(str, unpack(args))
	local txt_obj = guirender:createDrawableText(str)

	local this = {
		txt_obj = txt_obj,
		bg      = guirender:createContextMenuBackground(txt_obj:getWidth()+4, txt_obj:getHeight()+4),
		creation_time = love.timer.getTime(),

		draw = function(self)
			local x,y = love.mouse.getPosition()
			local w,h = self.bg:getDimensions()
			local ww,wh = love.graphics.getDimensions()

			if x+w > ww then
				x=ww-w end
			if y+h > wh then
				y=wh-h end

			love.graphics.draw(self.bg,x,y)
			love.graphics.draw(self.txt_obj,x+2,y+2)
		end,

		expire = function(self)
			return love.timer.getTime()-self.creation_time > MapEditPopup.lifetime
		end,

		release = function(self)
			self.bg:release()
			self.txt_obj:release()
		end
	}

	return this
end

return MapEditPopup
