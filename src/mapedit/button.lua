--
-- button gui element
--
--

local guirender = require 'mapedit.guidraw'

local MapEditGUIButton = {
	__type = "mapeditbutton",
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
MapEditGUIButton.__index = MapEditGUIButton

function MapEditGUIButton:new(str,icon,x,y,action)
	assert((str or icon) and action)

	local this = {
		x=x,
		y=y,
		w=0,
		h=0,
		text = str or "",
		bg = nil,
		icon = icon or nil,
		action = action,
		hover = false,
		disable = false,
	}

	if this.text ~= "" then
		this.text = guirender:createDrawableText(str)
	end

	local text_drawable = this.text
	local icon = this.icon
	local buffer_info = MapEditGUIButton.buffer_info
	local w,h = text_drawable:getDimensions()
	if icon then
		w = w + buffer_info.l + buffer_info.r
	else
		w = w + buffer_info.l_no_icon + buffer_info.r
	end
	h = h + buffer_info.t + buffer_info.b
	this.w = w
	this.h = h

	self.bg = guirender:createContextMenuBackground(this.w,this.h)

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
		local state = "normal"

		if self.hover and not self.disable then
			state="hover"
		elseif self.disable then
			state="disable"
		else
			state="normal"
		end
		--guidraw:drawOption(self.x,self.y,self.w,self.h,self.text,self.icon,nil,state,MapEditGUIButton.buffer_info)
		guirender:drawGenericOption(self.x,self.y,self.w,self.h, self.bg,self.text,self.icon,nil,state,MapEditGUIButton.buffer_info)
	end

	function this.setX(self,x)
		self.x = x - self.w*0.5 end
	function this.setY(self,y)
		self.y = y - self.h*0.5 end
	function this.setW(self,w)
		end
	function this.setH(self,h) 
		end

	setmetatable(this, MapEditGUIButton)
	return this
end

return MapEditGUIButton
