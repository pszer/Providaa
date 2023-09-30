--
-- grid selection gui object, used for selecting textures,models etc. from a list
--

local guiscrollb  = require 'mapedit.scrollbar'

local MapEditGUIGridSelection = {
	grid_w = 32,
	grid_h = 32
}
MapEditGUIGridSelection.__index = MapEditGUIGridSelection

-- each entry in img_table is a table {name,image_data}
function MapEditGUIGridSelection:new(img_table)
	local this = {
		x=0,
		y=0,
		w=0,
		h=0,

		table = img_table,
		grid_w = 1,
		grid_h = 1,
		grid_h_offset = 0,
		curr_selection = nil,

		scrollbar = guiscrollb:new(100),
		scroll_r = 0.0,

		hover = false
	}

	local grid_pix_w = MapEditGUIGridSelection.grid_w
	local grid_pix_h = MapEditGUIGridSelection.grid_h

	function this:update()
		self.scroll_r = self.scrollbar.ratio

		local count = #self.table
		if count==0 then
			self.grid_w = 0
			self.grid_h = 0
		else
			self.grid_w = math.min(count, math.floor(self.w / grid_pix_w))
			self.grid_h = math.ceil(count/self.grid_w)
		end

		if self.grid_h * grid_pix_h <= self.h then
			self.grid_h_offset = 0
		else
			local diff = self.h - (self.grid_h * grid_pix_h)
			self.grid_h_offset = diff * self.scroll_r
		end

		self:generateText()
	end

	function this:generateText()
		for i,v in ipairs(self.table) do
			if not v.__text then
				local str = v[1]
				if str and str ~= "" then
					local draw_text = guirender:createDrawableText(str)
					v.__text = draw_text
				end
			end
		end
	end

	function this:draw()
		local x,y,w,h = self.x,self.y,self.w,self.h
		love.graphics.setScissor(x,y,w,h)
		love.graphics.setColor(0,0,0,1)
		love.graphics.rectangle(x,y,w,h)

		local h_offset = self.grid_h_offset
		local t = self.table
		local count = #t

		for i=1,count do
			local X,Y = i % self.grid_w,
			            math.floor(i / self.grid_w)

			local _x,_y = X*grid_pix_w,
			              Y*grid_pix_h - grid_h_offset

			local bg_col = nil
			local border_col = nil
			if self.curr_selection == t[i] then
				bg_col = {0.3,0.3,0.3,1}
				border_col = {1,1,1,1}
			end
			guirender:drawTile(_x,_y,grid_pix_w,grid_pix_h,bg_col,border_col)

			local img = t[i]
			if img then
				local img_w,img_h = img:getDimensions()
				local Sx,Sy = 1/(img_w/(grid_pix_w-2)),
				              1/(img_h/(grid_pix_h-2))

				love.graphics.draw(img, _x+1, _y+1, Sx,Sy)
			end
			if t[i].__text then
				local txt = t[i].__text
				love.graphics.draw(txt, _x+1, _y+1)
			end
		end

		love.graphics.setScissor()
	end

	function this:updateHoverInfo()
		local scrlb = self.scrollbar
		scrlb:setX(self.x + self.w)
		scrlb:setY(self.y)
		scrlb:setH(self.h)

		local scrlb_w,scrlb_h = scrlb.w,scrlb.h
		local mx,my = love.mouse.getPosition()

		local hover = scrlb:updateHoverInfo()
		if hover then
			self.hover = true
			return scrlb
		end

		local x,y,w,h = self.x, self.y, self.w, self.h
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
		if self.scrollbar.hover then return self.scrollbar end
		if self.hover then return self end
		return nil
	end

	function this:click()
		local mx,my = love.mouse.getPosition()
	end

	function this.setX(self,x)
		self.x = x end
	function this.setY(self,y)
		self.y = y end
	function this.setW(self,w)
		w = math.floor(w/grid_w)*grid_w
		if w == 0 then w = grid_w end
		self.w = w
		end
	function this.setH(self,h)
		self.scrollbar.h = h
		self.h = h end
end

return MapEditGUIGridSelection
