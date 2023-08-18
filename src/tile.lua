require "props.tileprops"

TILE_SIZE = 32
TILE_HEIGHT = 16

Tile = {__type = "tile"}
Tile.__index = Tile

function Tile:new(props)
	local this = {
		props = TilePropPrototype(props),
	}

	setmetatable(this,Tile)
	this:generateMesh()

	return this
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

function Tile:generateMesh()
	if self.props.tile_type == "void" then
		return
	elseif self.props.tile_type == "land" then

		local atypes = {
		  {"VertexPosition", "float", 3},
		  {"VertexTexCoord", "float", 2},
		}

		self.props.tile_mesh = love.graphics.newMesh(atypes, 4, "triangles", "dynamic")
	elseif self.props.tile_type == "model" then
		--implement
	end
end
