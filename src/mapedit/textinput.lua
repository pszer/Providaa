--
-- text input gui element
--

local guirender = require 'mapedit.guidraw'

local MapEditGUITextInput = {
	__type = "mapedittextinput",
	__maketextinputhook = nil,
	__deltextinputhook  = nil,

	int_validator = function(str)
		local extract = string.match(str,"^[-+]?%d+$")
		if not extract then return nil end
		local num = tonumber(extract)
		return num
	end,
	int_format_func = function(str)
		local result = nil
		local d = string.sub(str,2,-1)
		local s = string.sub(str,1,1)
		if not string.match(s,"[-+%d]") then
			result = string.format("~(red)%s~r",s)
		else
			result = s or ""
		end
		local red = false
		for char in string.gmatch(d,".") do
			if not string.match(char,"%d") then
				if not red then
					result = result .. "~(red)" .. char
				else
					result = result .. char
				end
				red = true
			else
				result = result .. char
			end
		end
		return result
	end,

	float_validator = function(str)
		local extract = string.match(str,"^[-+]?%d+%.?%d-$")
		if not extract then return nil end
		local num = tonumber(extract)
		return num
	end,
	float_format_func = function(str)
		local result = nil
		local d = string.sub(str,2,-1)
		local s = string.sub(str,1,1)
		if not string.match(s,"[-+%d]") then
			result = string.format("~(red)%s~r",s)
		else
			result = s or ""
		end
		local red = false
		local point_count=0
		for char in string.gmatch(d,".") do
			if not string.match(char,"[%d%.]") then
				if not red then
					result = result .. "~(red)"
				end
				result = result .. char
				red = true
			elseif char == "." then
				point_count=point_count+1
				if point_count==2 then
					if not red then
						result = result .. "~(red)"
					end
					red = true
				end
				result = result .. char
			else
				result = result .. char
			end
		end
		return result
	end,

	string_table_validator = function(str,table,access)
		local access = access or function(x) return x end
		return function(str)
			for i,v in ipairs(table) do
				local s = access(v)
				if str == s then return str end
			end
			return nil
		end
	end,
	string_table_format_func = function(str,table,access)
		local access = access or function(x) return x end
		return function(str)
			for i,v in ipairs(table) do
				local s = access(v)
				if str == s then return str end
			end
			return "~(red)"..str
		end
	end,
}
MapEditGUITextInput.__index = MapEditGUITextInput

function MapEditGUITextInput:setup(make,del)
	
end

function MapEditGUITextInput:new(str,x,y,w,h,init_str,validator,format_func,align_x,align_y)
	assert(str and type(str)=="string")

	assert(self.__maketextinputhook and self.__deltextinputhook,
		"MapEditGUITextInput:new(): text input hook make/delete function not set yet, please use MapEditGUITextInput:setup()")

	local this = {
		x=x,
		y=y,
		w=w or 16,
		h=h or 250,
		text = nil,

		hover=false,
		capture=false,
		validator = validator,

		align_x=align_x or "middle",
		align_y=align_y or "middle",
	}

	this.text = guirender:createDynamicTextObject(init_str,this.w,format_func)

	function this:draw()
		love.graphics.setScissor(self.x,self.y,self.w,self.h)
		love.graphics.setColor(0,0,0,1)
		love.graphics.rectangle("fill",self.x,self.y,self.w,self.h)
		love.graphics.setColor(1,1,1,1)
		self.text:draw(self.x,self.y,0,1,1)
		love.graphics.setScissor()
	end

	function this:textinput(t)
		if not self.capture then return end
		if t=="\b" then
			self.text:popchar()
		else
			self.text:concat(t)
		end
	end

	self.__maketextinputhook(self,this.textinput)
	function this:delete()
		self.__deltextinputhook(self)
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
		self.capture = false
		return nil
	end

	function this:getCurrentlyHoveredOption()
		if self.hover then return self end
		return nil
	end

	function this.setX(self,x)
		if self.align_x=="middle" then
			self.x = x - self.w*0.5
		elseif self.align_x=="left" then
			self.x = x
		elseif self.align_x=="right" then
			self.x = x - self.w
		else
			self.x = x
		end
		end
	function this.setY(self,y)
		if self.align_y=="middle" then
			self.y = y - self.h*0.5
		elseif self.align_y=="top" then
			self.y = y
		elseif self.align_y=="bottom" then
			self.y = y - self.h
		else
			self.y = y
		end
		end
	function this.setW(self,w)
		end
	function this.setH(self,h) 
		end

	function this:action()
		self.capture = not self.capture
	end

	function this:getText()
		return self.text.string
	end
	function this:get()
		local val = self.validator(self.text.string)
		return val
	end

	setmetatable(this, MapEditGUITextInput)
	return this
end

return MapEditGUITextInput
