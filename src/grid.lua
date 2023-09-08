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

	--local x1,y1,z1 = (x+0)*TILE_SIZE , tprops.tile_height1*TILE_HEIGHT, -(z+1)*TILE_SIZE
	--local x2,y2,z2 = (x+1)*TILE_SIZE , tprops.tile_height2*TILE_HEIGHT, -(z+1)*TILE_SIZE
	--local x3,y3,z3 = (x+1)*TILE_SIZE , tprops.tile_height3*TILE_HEIGHT, -(z+0)*TILE_SIZE
	--local x4,y4,z4 = (x+0)*TILE_SIZE , tprops.tile_height4*TILE_HEIGHT, -(z+0)*TILE_SIZE

	local x1,y1,z1 = Tile.tileCoordToWorld( x , tprops.tile_height1, (z+1) )
	local x2,y2,z2 = Tile.tileCoordToWorld( x+1, tprops.tile_height2, (z+1) )
	local x3,y3,z3 = Tile.tileCoordToWorld( x+1, tprops.tile_height3, (z+0) )
	local x4,y4,z4 = Tile.tileCoordToWorld( x+0, tprops.tile_height4, (z+0) )

	return x1,y1,z1, x2,y2,z2,
	       x3,y3,z3, x4,y4,z4
end

function Grid:applyAttributes()
	for z = 1, self:getHeight() do
		for x = 1, self:getWidth() do
			self:applyTileAttribute(x,z)
		end
	end
end

function Grid:applyTileAttribute(x,z)
	local tile = self.props.grid_data[z][x]
	local tileprops = tile.props
	local starti,endi = tileprops.tile_mesh_vstart_index, tileprops.tile_mesh_vend_index
	local mesh = tileprops.tile_mesh

	if not mesh then return end

	--local animationoffset = Tile.getAttributeIndex("AnimationOffset")
	local texscale = Tile.getAttributeIndex("TextureScale")
	local texoffset = Tile.getAttributeIndex("TextureOffset")

	local texture = Textures.queryTexture(tile:getTexture())
	local texw,texh = texture:getWidth(), texture:getHeight()
	local scalex = tileprops.tile_texture_scalex * (texw / TILE_SIZE)
	local scaley = tileprops.tile_texture_scaley * (texh / TILE_SIZE)

	local offx = x + tileprops.tile_texture_offx/TILE_SIZE
	local offy = z + tileprops.tile_texture_offy/TILE_SIZE

	for i=starti,endi do
		mesh:setVertexAttribute(i,texscale, scalex, scaley)
		--mesh:setVertexAttribute(i,animationoffset, tileprops.tile_texture_animation_offset)
		mesh:setVertexAttribute(i,texoffset, offx, offy)
	end
end
