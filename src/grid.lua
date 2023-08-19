require "props.gridprops"

require "tile"
require "wall"

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
	self.props.grid_data[z][x] = Tile.allocateTile(props)
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

	local x1,y1,z1 = (x+0)*TILE_SIZE , tprops.tile_height1*TILE_HEIGHT, -(z+1)*TILE_SIZE
	local x2,y2,z2 = (x+1)*TILE_SIZE , tprops.tile_height2*TILE_HEIGHT, -(z+1)*TILE_SIZE
	local x3,y3,z3 = (x+1)*TILE_SIZE , tprops.tile_height3*TILE_HEIGHT, -(z+0)*TILE_SIZE
	local x4,y4,z4 = (x+0)*TILE_SIZE , tprops.tile_height4*TILE_HEIGHT, -(z+0)*TILE_SIZE

	return x1,y1,z1, x2,y2,z2,
	       x3,y3,z3, x4,y4,z4
end

function Grid:generateMesh()
	local props = self.props
	for x = 1,props.grid_w do
		for z = 1,props.grid_h do
			local tile = self:queryTile(x,z)
			local mesh = tile.props.tile_mesh

			if mesh then
				local x1,y1,z1,x2,y2,z2,x3,y3,z3,x4,y4,z4 =
					self:getWorldCoords(x,z)
	
				local u = {0,1,1,0}
				local v = {0,0,1,1}
	
				mesh:setVertex(1, x1,y1,z1, u[1], v[1])
				mesh:setVertex(2, x2,y2,z2, u[2], v[2])
				mesh:setVertex(3, x3,y3,z3, u[3], v[3])
				mesh:setVertex(4, x4,y4,z4, u[4], v[4])
			end
			
		end
	end
end

-- horizontal flat stretches of tiles with the same texture
-- can be turned into a single mesh
function Grid:optimizeMesh()
	local props = self.props
	local w,h = props.grid_w, props.grid_h

	local testRow = function(z,x)
		local tile = self:queryTile(x,z)
		local flat,height = tile:isFlat()
		if not flat or not tile:isLand() then
			return nil, x+1
		end

		local texture = tile.props.tile_texture

		for testx = x+1,w do
			local tile2 = self:queryTile(testx, z)

			local flat2,height2 = tile2:isFlat()
			if not flat2 or height~=height2 or not tile2:isLand() or texture ~= tile2:getTexture() then
				return testx-1, testx
			end
		end

		return w, w+1
	end

	for z = 1,h do
		local x = 1
		while x <= w do

			local upto, iter = testRow(z,x)
			
			if not upto or upto == x then
				x = iter

			else
				--print(x, "up to", upto, "can be optimized at row", z)

				local count = upto - x + 1

				-- stretch tile at (x,z) to cover tiles (x+1,z) ... (upto,z)
				local u = {0,count, count, 0}
				local v = {0,     0, 1, 1}

				local mesh = self:queryTile(x,z).props.tile_mesh

				local X,Y,Z = {},{},{}
				X[1],Y[1],Z[1],X[2],Y[2],Z[2],X[3],Y[3],Z[3],X[4],Y[4],Z[4] =
					self:getWorldCoords(x,z)

				X[2] = X[1] + count * TILE_SIZE
				X[3] = X[1] + count * TILE_SIZE

				for i=1,4 do
					mesh:setVertex(i, X[i], Y[i], Z[i], u[i], v[i])
				end

				for i = x+1, upto do
					local tilep = self:queryTile(i,z).props
					tilep.tile_mesh = nil
					tilep.tile_mesh_optimized = true
				end

				x = iter
			end
		end
	end
end

