--
-- map edit gui screen layer object
--
--

local MapEditGUIScreen = {
	__type = "mapeditscreen"
}
MapEditGUIScreen.__index = MapEditGUIScreen

function MapEditGUIScreen:new(layout, throw_obj, lock, win_lock)
	local this = {
		layout = layout,
		elements = {},
		element_status = {},

		window_stack  = {},
		stack_pointer = 0,

		control_lock = lock,
		win_control_lock = win_lock,

		throw_obj = throw_obj
	}

	for i,v in ipairs(layout.elements) do
		this.elements[i] = v
		this.element_status[i] = true
	end

	function this:addElement(element)
		if not element then return end
		local c = #self.elements
		self.elements[c+1]=element
		self.element_status[c+1]=true
	end
	function this:addElements(es)
		for i,v in ipairs(es) do
			self:addElement(v)
		end
	end

	function this:removeElement(element)
		for i,v in ipairs(es) do
			if v == element then
				table.remove(self.elements, i)
				table.remove(self.element_status, i)
			end
		end
	end

	function this:disableElement(element)
		for i,v in ipairs(self.elements) do
			if v==element then
				self.element_status[i]=false
			end
		end
	end

	function this:pushWindow(win)
		if not win then return end
		table.insert(self.window_stack, win)
		self.stack_pointer = #self.window_stack
	end
	function this:popWindow()
		local p = self.stack_pointer
		if p == 0 then return end
		self.window_stack[p] = nil
		self.stack_pointer = self.stack_pointer - 1
	end
	function this:switchToWindow(win)
		local found = nil
		for i,v in ipairs(self.window_stack) do
			if win == v then 
				found = i
				break
			end
		end
		table.remove(self.window_stack, found)
		self:pushWindow(win)
	end

	function this:windowOpen()
		return self.stack_pointer > 0
	end
	function this:topWindow()
		local s = self.stack_pointer
		if s==0 then return nil end
		return self.window_stack[s]
	end

	function this:update()
		local w,h = love.graphics.getDimensions()
		self.layout.w=w
		self.layout.h=h

		if self:windowOpen() then
			local hover = false
			local top_win = self:topWindow()
			local wins
			if top_win.props.win_focus then
				wins = {top_win}
			else
				wins = self.window_stack
			end

			for i,v in ipairs(wins) do
				local h_info = v:updateHoverInfo()
				if h_info then hover = true end
			end
			if hover then
				self.win_control_lock.open()
				return true
			else
				self.win_control_lock.close()
			end
		end

		if self.layout then
			self.layout:updateXywh()
		end

		local hover = false
		for i,v in ipairs(self.elements) do
			local h_info = v:updateHoverInfo()
			if h_info then hover = true end
		end

		if hover then
			self.control_lock.open()
		else
			self.control_lock.close()
		end
	end

	function this:draw()
		for i,v in ipairs(self.window_stack) do
			v:draw()
		end

		for i,v in ipairs(self.elements) do
			if self.element_status[i] then
				v:draw()
			end
		end
	end

	function this:click()
		if self:windowOpen() then
				local top_win = self:topWindow()
				local wins
				if top_win.props.win_focus then
					wins = {top_win}
				else
					wins = self.window_stack
				end

			for i,v in ipairs(wins) do
				local h_info = v:updateHoverInfo()
				if h_info then
					local e = h_info:action()
					local e_type = provtype(e)
					if e_type ~= "mapeditwindow" then
						self.throw_obj(e)
					end
				end
			end
		end

		for i,v in ipairs(self.elements) do
			local enable,h_info = self.element_status[i],nil
			if enable then
				h_info = v:updateHoverInfo()
			end

			if h_info then
				local e = h_info:action()
				print(e)
				local e_type = provtype(e)
				if e_type ~= "mapeditwindow" then
					self.throw_obj(e)
				else
					self:pushWindow(e)
				end
			end
		end
	end

	setmetatable(this, MapEditGUIScreen)
	return this
end

return MapEditGUIScreen
