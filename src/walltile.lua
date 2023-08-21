require "props.walltileprops"

WallTile = {__type = "walltile",
		atypes = {
			{"TextureScale",    "float", 2},
			{"TextureOffset",   "float", 2}
		},
}
WallTile.__index = WallTile

function WallTile:new(props)
	local this = {
		props = WallTilePropPrototype(props)
	}

	setmetatable(this,WallTile)

	return this
end

function WallTile:getTexture()
	return self.props.wtile_texture
end

function WallTile:getMaxHeight()
	local coords = self.props.wtile_coords
	return math.max(coords[1][2], coords[2][2])
end

function WallTile.applyAttributes(walltiles,w,h)
	for z = 1, w do
		for x = 1, h do
			if walltiles[z][x] then
				WallTile.applyWallAttribute(walltiles[z][x][1],x,z)
				WallTile.applyWallAttribute(walltiles[z][x][2],x,z)
				WallTile.applyWallAttribute(walltiles[z][x][3],x,z)
				WallTile.applyWallAttribute(walltiles[z][x][4],x,z)
			end
		end
	end
end

function WallTile.applyWallAttribute(walltile, x,z)
	if not walltile then return end

	local wtprops = walltile.props

	local starti,endi = wtprops.wtile_mesh_vstart_index, wtprops.wtile_mesh_vend_index
	local mesh = wtprops.wtile_mesh

	local texscale = WallTile.getAttributeIndex("TextureScale")
	local texoffset = WallTile.getAttributeIndex("TextureOffset")

	local texture = wtprops.wtile_texture
	local texw,texh = texture:getWidth(), texture:getHeight()
	local scalex = (texw / TILE_SIZE) * wtprops.wtile_texture_scalex
	local scaley = (texh / -TILE_HEIGHT) * wtprops.wtile_texture_scaley

	local offx = wtprops.wtile_texture_offx
	local offy = walltile:getMaxHeight() + wtprops.wtile_texture_offy

	for i=starti,endi do
		mesh:setVertexAttribute(i,texscale, scalex, scaley)
		mesh:setVertexAttribute(i,texoffset, offx, offy)
	end
end

function WallTile.getAttributeIndex(name)
	for i,v in ipairs(WallTile.atypes) do
		if v[1] == name then return i end
	end
	return nil
end
