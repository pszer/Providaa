--
-- map edit gui window
--

require "prop"

local guirender = require 'mapedit.guidraw'

local MapEditGUIWindow = {
	__type = "mapeditwindow",

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
MapEditGUIWindow.__index = MapEditGUIWindow

--
-- layout holds gui objects as a parent and positions them
-- according to a specified layout.
--
--

local WindowProps = Props:prototype{
	{"win_min_w"    , "number", 100  , PropIntegerMin(100), "window maximum size (x direction)"},
	{"win_max_h"    , "number", 100  , PropIntegerMin(100), "window maximum size (x direction)"},
	{"win_min_w"    , "number", 5000  , PropIntegerMax(5000), "window maximum size (x direction)"},
	{"win_max_h"    , "number", 5000  , PropIntegerMax(5000), "window maximum size (x direction)"},
	{"win_focus"    , "boolean", false, nil, "flag to force-grab all inputs"},
}

function MapEditGUIWindow:define(default_props, layout_def)
	local obj = {
		new = function (self,props,x,y,w,h,elements)
			local this = {
				props = WindowProps(default_props),
				layout = nil,
				elements = {},

				x=x,
				y=y,
				w=w,
				h=h,

				hover = false,
				delete = false -- delete flag
			}
			for i,v in pairs(props) do
				this.props[i]=v end
			for i,v in ipairs(elements) do
				this.elements[i] = elements[i] end
			this.layout = layout_def:new(x,y,w,h,this.elements)

			function this:delete()
				self.delete = true
			end

			function this:setX(x)
				self.x=x end
			function this:setY(y)
				self.y=y end
			function this:setW(w)
				if w < self.props.win_min_w then w = self.props.win_min_w end
				if w < self.props.win_max_w then w = self.props.win_max_w end
				self.w=w
			end
			function this:setH(h)
				if h < self.props.win_min_h then h = self.props.win_min_h end
				if h < self.props.win_max_h then h = self.props.win_max_h end
				self.h=h
			end

			function this:update()
				self.layout.w=self.w
				self.layout.h=self.h

				if self.layout then
					self.layout:updateXywh()
				end
			end

			function this.getCurrentlyHoveredOption(self)
				for i,v in ipairs(self.menus) do
					if v.hover then
						return v
					end
				end
				if self.hover then return self.hover end
			end

			function this:updateHoverInfo()
				local hover = false
				local mx,my = love.mouse.getPosition()
				if x<=mx and mx<=x+w and
				   y<=my and my<=y+h
				then
					hover = self
				end

				for i,v in ipairs(self.elements) do
					local h_info = v:updateHoverInfo()
					if h_info then hover = h_info end
				end
				return hover
			end

			function this:draw()
				for i,v in ipairs(self.elements) do
					v:draw()
				end

				local x,y,w,h = self.x,self.y,self.w,self.h
				guirender:drawOption(x,y,w,h, nil, nil, nil, nil, MapEditGUIWindow.buffer_info)
			end

			function this:click()
				for i,v in ipairs(self.elements) do
					h_info = v:updateHoverInfo()
					if h_info then
						local e = h_info:action()
						local e_type = provtype(e)
						if e_type ~= "mapeditwindow" then
							self.throw_obj(e)
						end
					end
				end
			end

			setmetatable(this, MapEditGUIWindow)
			return this
		end
	}
	return obj
end

return MapEditGUIWindow
