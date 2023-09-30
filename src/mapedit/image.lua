--
-- button gui element
--
--

local guirender = require 'mapedit.guidraw'
require "assetloader"

local MapEditGUIImage = {
	__type = "mapeditimage",
	buffer_info = {
		l  = 24,
		l_no_icon  = 4,
		r = 6,
		t = 5,
		b = 3,

		arrow_r = 20,
		arrow_t = 1,

		icon_l = 2,
		icon_t = 1,
	}
}
MapEditGUIImage.__index = MapEditGUIImage

function MapEditGUIImage:new(img,x,y,action)
	local this = {
		x=x,
		y=y,
		w=0,
		h=0,
		img = nil,
		action = action,
		hover = false,
		disable = false,
	}

	local img_ = Loader:getTextureReference(img)
	assert(img_)
	self.img = img_

	this.w,this.h = img_:getDimensions()

	function this:updateHoverInfo()
		local x,y,w,h = self.x, self.y, self.w, self.h
		local mx,my = love.mouse.getPosition()
		if x<=mx and mx<=x+w and
		   y<=my and my<=y+h
		then
			self.hover = true
			return self
		end
		self.hover = false
		return nil
	end

	function this:getCurrentlyHoveredOption()
		if self.hover then return self end
		return nil
	end

	function this:draw()
		love.graphics.origin()
		love.graphics.draw(self.img, self.x, self.y)
	end

	function this.setX(self,x)
		self.x = x - self.w*0.5 end
	function this.setY(self,y)
		self.y = y - self.h*0.5 end
	function this.setW(self,w)
		end
	function this.setH(self,h) 
		end

	setmetatable(this, MapEditGUIImage)
	return this
end

return MapEditGUIImage
