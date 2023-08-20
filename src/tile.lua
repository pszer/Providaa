require "props.tileprops"

require "texture"
require "mesh"

love.graphics.setDefaultFilter("nearest", "nearest")
DIRT = love.graphics.newImage("dirt.jpg")
DIRT:setWrap("repeat", "repeat")

TILE_SIZE = 32
TILE_HEIGHT = -24

Tile = {__type = "tile"}
Tile.__index = Tile

function Tile:new(props)
	local this = {
		props = TilePropPrototype(props),

		-- used for caching purposes
		--texture = nil
	}

	setmetatable(this,Tile)
	--this:allocateMesh()

	return this
end

function Tile.tileCoordToWorld(x,y,z)
	return x * TILE_SIZE, y*TILE_HEIGHT, -z*TILE_SIZE
end

function Tile.worldCoordToTile(x,y,z)
	return x / TILE_SIZE, y/TILE_HEIGHT, -z/TILE_SIZE
end


function Tile.voidTile()
	return Tile:new{tile_type="void"}
end

function Tile.newLandTile(h1,h2,h3,h4, texture)
	return Tile:new{
		tile_type="land",
		tile_height1 = h1,
		tile_height2 = h2,
		tile_height3 = h3,
		tile_height4 = h4,
		tile_texture = texture }
end

function Tile.allocateTile(props, texture)
	local T = Tile:new(props)
	T:allocateMesh(texture)
	return T
end

function Tile:allocateMesh(texture)
	if self.props.tile_type == "void" then
		return
	elseif self.props.tile_type == "land" then

		--local atypes = {
		--  {"VertexPosition", "float", 3},
		--  {"VertexTexCoord", "float", 2},
		--}

		local t = texture or Textures.queryTexture(self.props.tile_texture)
		local mesh = Mesh:new(t, 6, "triangles", "dynamic")
		--local mesh = love.graphics.newMesh(atypes, 4, "triangles", "dynamic")
		--local vmap = {1,2,3, 3,4,1}

		mesh.mesh:setVertexMap(vmap)
		mesh.mesh:setDrawRange(1,3000)

		self.props.tile_mesh = mesh
		self:updateMeshTexture()

	elseif self.props.tile_type == "model" then
		--implement
	end
end

function Tile:updateMeshTexture()
	local mesh = self.props.tile_mesh
	if mesh then
		mesh:updateTexture()
	end
end

-- returns true, height if flat
-- otherwise nil nil
function Tile:isFlat()
	local props = self.props
	local flat = (props.tile_height1 == props.tile_height2) and
	       (props.tile_height2 == props.tile_height3) and
		   (props.tile_height3 == props.tile_height4)
	if flat then
		return true, props.tile_height1
	else
		return nil, nil
	end
end

function Tile:isLand()
	return self.props.tile_type == "land"
end

function Tile:getTexture()
	return self.props.tile_texture
end
