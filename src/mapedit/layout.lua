--
-- map edit gui layout formatting object
--

require "prop"

local guirender = require 'mapedit.guidraw'

local MapEditGUILayout = {
}
MapEditGUILayout.__index = MapEditGUILayout

--
-- layout holds gui objects as a parent and positions them
-- according to a specified layout.
--
-- the layout argument specifies the layout by regions.
-- its format is as follows
--
-- 1. { id = string, split_type = "+x"/"+y"/"-x"/"-y", split_ratio = (0,1), sub = {...} }
-- 2. { id = string, split_type = "+x"/"+y"/"-x"/"-y", split_dist = [0,...), sub = {...} }
-- 3. { id = string, split_type = nil }
--
-- the split_type determines the way the region is split, "x" creates two regions
-- side by side horizontally and "y" vertically, id is the identifier string
-- for the left/top region created by a +x/+y split or the right/bottom region created
-- by a -x/-y split.
--
-- split_ratio/split_dist determines the way in which the region is split, split_ratio is number from
-- 0 to 1, increasing in the positive x/y direction, split_ratio=0.5 would split the regions equally in half.
-- split_dist is a fixed number in pixels.
--
-- sub specifies the layout of the subregion created by the split, which in turn can create furhter splits.
--
--
-- each argument after that is a table containing {string, function}
-- the string is the name for a region in this layout, function is a function(region) that returns x,y,w,h
-- the region argument it takes in will be filled in with the x,y,w,h of the previously specified layout
--

function MapEditGUILayout:define(layout, ...)
	local elements_def = { ... }

	local obj = {
		new = function(self, props, X, Y, w, h, elements)
			assert(X and Y)
			local this = {
				__type = "guilayout",
				layout = layout,
				layout_map = {},
				elements = elements,
				x = Y,
				y = X,
				w = w,
				h = h,
			}

			function this:update()
				local function update_xywh(layout, x,y,w,h, recur)
					local stype = layout.split_type
					if stype == nil then
						layout.x,layout.y,layout.w,layout.h = x,y,w,h
					end

					local xoffset,yoffset
					if layout.split_ratio then
						xoffset = layout.split_ratio*w
						yoffset = layout.split_ratio*h
					elseif layout.split_dist then
						xoffset = layout.split_dist
						yoffset = layout.split_dist
					end

					if stype == "+x" then

					elseif stype == "-x" then

					elseif stype == "+y" then

					elseif stype == "-y" then
					
					end
				end

				for i,v in ipairs(self.elements) do
					local def = elements_def[i]
				end
			end

			local function map_out(layout, map_out)
				if not layout then return end
				local id = layout.id
				assert(id, "MapEditGUILayout:define(): region has no id")
				local v = this.layout_map[id]
				if v then
					assert(id, "MapEditGUILayout:define(): duplicate region id") end
				this.layout_map[id] = layout
				map_out(layout.sub, map_out)
			end
			map_out(this.layout, map_out)

			for i,v in ipairs(elements_def) do
				assert(v[1] and v[2], "MapEditGUILayout:define(): malformed element definition")
				assert(this.layout_map[v[1]],string.format("MapEditGUILayout:define(): %s undefined region", v[1]))
				assert(type(v[2])=="function",string.format("MapEditGUILayout:define(): expected function", v[2]))
			end

			return this
		end
	}
end
