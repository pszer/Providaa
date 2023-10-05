require "props.tileprops"

TILE_SIZE   = CONSTS.TILE_SIZE
TILE_HEIGHT = CONSTS.TILE_HEIGHT

Tile = {__type = "tile",

	--[[atypes = {
		{"TextureScale",    "float", 2},
		{"TextureOffset",   "float", 2}
	}--]]

}
Tile.__index = Tile
--[[
function Tile:new(props)
	local this = {
		props = TilePropPrototype(props),
	}

	setmetatable(this,Tile)
	--this:allocateMesh()

	return this
end--]]

function Tile.tileCoordToWorld(x,y,z)
	return x * TILE_SIZE, y*TILE_HEIGHT, -z*TILE_SIZE
end

function Tile.worldCoordToTile(x,y,z)
	return x / TILE_SIZE, y/TILE_HEIGHT, -z/TILE_SIZE
end

--
-- can be safely removed
-- only the above two functions are used
--

--[[
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

function Tile.getAttributeIndex(name)
	for i,v in ipairs(Tile.atypes) do
		if v[1] == name then return i end
	end
	return nil
end

-- checks if this tile identical attributes to another tile
function Tile:attributeEquals(tile2)
	if not tile2 then return false end
	local t1,t2 = self.props, tile2.props

	local function mod1(a) return math.fmod(a,1.0) end
	local tex_eq    =      t1.tile_texture        ==      t2.tile_texture
	local scalex_eq =      t1.tile_texture_scalex ==      t2.tile_texture_scalex
	local scaley_eq =      t1.tile_texture_scaley ==      t2.tile_texture_scaley
	local offx_eq   = mod1(t1.tile_texture_offx)  == mod1(t2.tile_texture_offx)
	local offy_eq   = mod1(t1.tile_texture_offy)  == mod1(t2.tile_texture_offy)
	return scalex_eq and scaley_eq and offx_eq and offy_eq
end--]]
