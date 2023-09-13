-- quad trees are implemented with a fixed depth and fixed number of quadrants, with partioning
-- only along the xz plane
-- this means the space partioning isn't optimal, but these quadtree's are only used
-- as a first-pass in view culling and optimising queries such as queryEntitiesInRegion
--
-- we're not doing physics here, so it's good enough!

--[[BinNode = {}
BinNode.__index = BinNode

require "table"

function BinNode:new(x1,y1,x2,y2)
	local this = {
		x1=x1,
		y1=y1,
		x2=x2,
		y2=y2,

		children = {},

		has_children = false,
		empty = false
	}
	-- an alias, if has_children is true then the table is for
	-- child nodes, otherwise its for storing objects
	this.objects = children

	setmetatable(this, BinNode)
	return this
end

-- corner = 1   top left
--          2   top right
--          3   bottom left
--          4   bottom right
function BinNode:getQuadCoords(corner)
	local x1,y1,x2,y2 = self.x1, self.y1, self.x2, self.y2
	local midx = (x2-x1)*0.5
	local midy = (y2-y1)*0.5

	if corner == 1 then
		return x1 , y1 , midx , midy
	elseif corner == 2 then
		return midx , y1 , x2 , midy
	elseif corner == 3 then
		return x1 , midy , midx , y2
	elseif corner == 4 then
		return midx , midy , x2 , y2
	end

	return nil,nil,nil,nil
end

function BinNode:createChildren( depth )
	if depth == 0 then return end

	local x1,y1,x2,y2 = self.x1, self.y1, self.x2, self.y2
	local midx = (x2-x1)*0.5
	local midy = (y2-y1)*0.5

	local children = self.children
	self.has_children = true

	for i=1,4 do -- top left
		local a,b,c,d  = self:getQuadCoords(i)
		children[i] = BinNode:new(a,b,c,d)
		children[i]:createChildren( depth - 1)
	end
end

function BinNode:insert(obj, x1,y1,x2,y2)
	local sizex = x2-x1
	local sizey = y2-y1
end--]]

GridPartition = {}
GridPartition.__index = GridPartition

function GridPartition:new(w,h, countx, county)
	local this = {
		bins = {},
		objs = {},
		width = w,
		height = h,
		countx = countx,
		county = county,
		stepx = w/countx,
		stepy = h/county,

		index = function(x,y) return x + y*countx+1 end
	}

	for i=1,countx*county do
		this.bins[i] = {}
	end

	setmetatable(this, GridPartition)
	return this
end

function GridPartition:insert(obj, x,y,w,h)
	local floor = math.floor
	local max = math.max
	local min = math.min

	local index = self.index
	local bins = self.bins
	local tableinsert = table.insert

	local startxi = max(0, floor(x/self.stepx))
	local startyi = max(0, floor(y/self.stepy))
	local endxi = min(self.countx-1, floor((x+w)/self.stepx))
	local endyi = min(self.county-1, floor((y+h)/self.stepy))

	self.objs[obj] = {}
	local obj_cache = self.objs[obj]

	for i = startxi,endxi do
		for j = startyi,endyi do
			print("at",i,j)
			local bin_i = index(i,j)
			tableinsert(bins[bin_i], obj)
			tableinsert(obj_cache, bin_i)
		end
	end
end

function GridPartition:remove(obj)
	local bin_indices = self.objs[obj]
	if not bin_indices then return end

	local tableremove = table.remove

	for _,index in ipairs(bin_indices) do
		local bin = self.bins[index]

		for i,v in ipairs(bin) do
			if v == obj then
				tableremove(bin, i)
				break
			end
		end
	end

	self.objs[obj] = nil
end

function GridPartition:getInsideRectangle(x,y,w,h)
	local floor = math.floor
	local max = math.max
	local min = math.min

	local startxi = max(0, floor(x/self.stepx))
	local startyi = max(0, floor(y/self.stepy))
	local endxi = min(self.countx-1, floor((x+w)/self.stepx))
	local endyi = min(self.county-1, floor((y+h)/self.stepy))

	local index = self.index

	local tableinsert = table.insert
	local function add_to_set(set, x)
		for i,v in ipairs(set) do
			if x == v then return end
		end
		tableinsert(set, x)
	end
	local set = {}

	local bins = self.bins

	for i = startxi,endxi do
		for j = startyi,endyi do
			local bin_i = index(i,j)
			for _,obj in ipairs(bins[bin_i]) do
				add_to_set(set, obj)
			end
		end
	end

	return set
end
