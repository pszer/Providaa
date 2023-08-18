require "props.gridprops"

require "tile"

Grid = {__type = "grid"}
Grid.__index = Grid

function Grid:new(props)
	local this = {
		props = GridPropPrototype(props),
	}

	setmetatable(this,Grid)

	return this
end

function Grid.allocateGrid(w,h)
	local t = {}

	for z=1,h do
		local row = {}
		for x = 1,w do
			row[x] = Tile.voidTile()
		end

		t[z] = row
	end

	return Grid:new{
		grid_w = w,
		grid_h = h,
		grid_data = t
	}
end

function Grid:setTile(x,z, props)
	self.props.grid_data[z][x] = Tile:new(props)
end

function Grid:swapTile(x,z, tile)
	if provtype(tile) == "tile" then
		self.props.grid_data[z][x] = tile
	end
end

-- returns nil if tile is out of bounds
function Grid:queryTile(x,z)
	local props = self.props
	local w,h = props.grid_w, props.grid_h
	if x < 1 or x > w or z < 1 or z > h then
		return nil
	end

	return props.grid_data[z][x]
end

function Grid:getWidth()
	return self.props.grid_w end
function Grid:getHeight()
	return self.props.grid_h end

-- returns four (x,y,z) coordinates for
-- each of the corners of a tile
-- returns nil if arguments are out of bounds
function Grid:getWorldCoords(x,z)
	local tile = self:queryTile(x,z)
	if not tile then
		return nil,nil,nil,
		       nil,nil,nil,
			   nil,nil,nil,
			   nil,nil,nil
	end
	local tprops = tile.props

	local x1,y1,z1 = (x+0)*TILE_SIZE , tprops.tile_height1*TILE_HEIGHT, (z+1)*TILE_SIZE
	local x2,y2,z2 = (x+1)*TILE_SIZE , tprops.tile_height1*TILE_HEIGHT, (z+1)*TILE_SIZE
	local x3,y3,z3 = (x+1)*TILE_SIZE , tprops.tile_height1*TILE_HEIGHT, (z+0)*TILE_SIZE
	local x4,y4,z4 = (x+0)*TILE_SIZE , tprops.tile_height1*TILE_HEIGHT, (z+0)*TILE_SIZE

	return x1,y1,z1, x2,y2,z2,
	       x3,y3,z3, x4,y4,z4
end

TESTGRID = Grid.allocateGrid(20,60)

for x=1,TESTGRID:getWidth() do
	for z=1,TESTGRID:getHeight() do
		TESTGRID:setTile(x,z,{tile_type="land",
		                      tile_height1=0,
		                      tile_height2=0,
		                      tile_height3=0,
		                      tile_height4=0,
							  })
	end
end
