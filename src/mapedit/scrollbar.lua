--
-- gui scrollbar object
--

local guirender = require 'mapedit.guidraw'

local MapEditGUIScrollbar = {}
MapEditGUIScrollbar.__index = MapEditGUIScrollbar

function MapEditGUIScrollbar:new(h)
	local this = {
		x=0,
		y=0,
		w=20,
		h=h,

		hover=false
	}

	function this:draw()
		love.graphics.draw(self.text, self.x, self.y)
	end

	function this.setX(self,x)
		self.x = x end
	function this.setY(self,y)
		self.y = y end
	function this.setW(self,w)
		end
	function this.setH(self,h) 
		self.h = h end

	setmetatable(this, MapEditGUIScrollbar)
	return this
end
