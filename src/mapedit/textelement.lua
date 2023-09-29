--
-- basic text element gui element
--

local guirender = require 'mapedit.guidraw'

local MapEditGUITextElement = {
	__type = "mapedittextelement"
}
MapEditGUITextElement.__index = MapEditGUITextElement

function MapEditGUITextElement:new(str,x,y,limit,align)
	assert(str and type(str)=="string")

	local this = {
		x=x,
		y=y,
		w=w,
		h=h,
		limit = limit or 500,
		align = align or "left",
		text = nil
	}

	--this.text = guirender:createDrawableText(str)
	this.text = guirender:createDrawableTextLimited(str, this.limit, this.align)
	this.w,this.h = this.text:getDimensions()

	function this:draw()
		love.graphics.draw(self.text, self.x, self.y)
	end

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

	function this.setX(self,x)
		self.x = x end
	function this.setY(self,y)
		self.y = y end
	function this.setW(self,w)
		end
	function this.setH(self,h) 
		end

	setmetatable(this, MapEditGUITextElement)
	return this
end

return MapEditGUITextElement
