--]]
-- map format
--
-- tiles are stored row by row, e.g. grid[z][x] is tile at position (x,z)
--
-- map = {
--
--
--     name of the map
--     name = "example map name"
--
--     number of tiles, width goes in the +x direction, height in the -z direction
--     width = 64,
--     height = 64,
--
--
--
--     each tiles has four 4 y values for each of its corners, given in a table
--     if a number is given instead of a table, then that number is used as the y
--     value for each corner
--
--     height_map = {
--      {{y1,y2,y3,y4}  ,{y1,y2,y3,y4}, ...},
--      {{y1,y2,y3,y4}  ,{y1,y2,y3,y4}, ...},
--      { Y  , Y, ...},
--      ...                         ...
--      {{y1,y2,y3,y4}  ,{y1,y2,y3,y4}, ...}
--     },
--
--
--
--
--     each entry in the tile_set is a list of properties for a Tile object
--     tile_set = {
--       [0] = {tile_type="void"},
--       [1] = {tile_type="land",tile_texture="dirt.png",tile_walkable=true}
--     },
--
--     each entry in the wall_set is a texture to use when generating walls 
--     wall_set = {
--       [0] = nil
--       [1] = "wall.png"
--       [2] = "wall2.png"
--     },
--
--
--
--
--     maps each tile to a tile defined in tile_set
--     tile_map = {
--		{0,0,0,0,0,0,0,0,...}--
--		{0,0,1,1,1,1,1,0,...}
--		{0,0,0,0,0,0,0,0,...}
--		...
--		{0,0,0,0,0,0,0,0,...}
--     },
--     
--     maps each tile to table of 4 wall textures defined in wall_set to use when generating walls, entries
--     can be set to nil
--     the entries go in order of west,south,east,north walls (north should be left as nil unless special
--     camera angles are used to actually see it)
--     a 5th entry in the table can be specified to give an offset to the texture (number between 0.0-1.0)
--
--     if the entry is a single number instead of a table, the corresponding wall in the wall_set is used
--     for all faces except north
--	   wall_map =
--     {
--		{0,0,0,0,0,0,0,0,...}--
--		{0,0,1,1,{1,2,2,nil,0.5},1,1,0,...}
--		{0,0,0,0,0,0,0,0,...}
--		...
--		{0,0,0,0,0,0,0,0,...}
--     }
--
-- }

require "texture"
require "grid"
require "wall"

Map = {}
Map.__index = Map

local testmap = require "maps.test"

-- verifies if map format is correct
-- returns nil if fine, otherwise returns an error string
function Map.malformedCheck(map)
	local name = map.name or "UNNAMED"

	local w,h = map.width, map.height
	if not w or not h then
		return string.format("Map %s is missing a width/height number", name)
	end

	local tile_set = map.tile_set
	if not tile_set then
		return string.format("Map %s is missing a tile set", name) end

	local wall_set = map.wall_set
	if not wall_set then
		return string.format("Map %s is missing a wall set", name) end

	local height_map = map.height_map
	if not height_map then
		return string.format("Map %s is missing a height map", name) end

	local wall_map = map.wall_map
	if not wall_map then
		return string.format("Map %s is missing a wall map", name) end

	local tile_map = map.tile_map
	if not tile_map then
		return string.format("Map %s is missing a tile map", name) end

	if #height_map ~= h then
		return string.format("Map %s has mismatching height and height_map array size (height=%d, #height_map=%d)", name, h, #height_map) end
	if #tile_map ~= h then
		return string.format("Map %s has mismatching height and tile_map array size (height=%d, #tile_map=%d)", name, h, #tile_map) end

	for z = 1,h do
		if #(height_map[z]) ~= w then
			return string.format("Map %s has mismatching width and height_map array size (width=%d, #height_map[%d]=%d)", name, h,z,#height_map[z])
		end
		if #(tile_map[z]) ~= w then
			return string.format("Map %s has mismatching width and tile_map array size (width=%d, #tile_map[%d]=%d)", name, h,z,#height_map[z])
		end
		if #(wall_map[z]) ~= w then
			return string.format("Map %s has mismatching width and wall_map array size (width=%d, #wall_map[%d]=%d)", name, h,z,#height_map[z])
		end
	
		for x=1,w do
			local tile = tile_map[z][x]
			local wall = wall_map[z][x]
			if not tile_set[tile] then
				return string.format("Map %s: tile (z=%d,x=%d) uses undefined tile [%s]", name, z,x, tostring(tile))
			end
		end
	end

	return nil
end

-- returns grid, walls. makes sure textures in tileset are loaded
function Map.loadMap(map)
	local maperror = Map.malformedCheck(map)
	if maperror then
		error(maperror)
		return
	end

	local width, height = map.width, map.height

	local grid = Grid.allocateGrid(width, height)
	local walls = {}
	for z=1,height do walls[z]={} end

	local textures = {}
	local walltextures = {}

	-- load all the textures in the tileset and wallset
	for i,t in pairs(map.tile_set) do
		local tex = t.tile_texture

		if tex then
			Textures.loadTexture(tex)
			textures[i] = Textures.queryTexture(tex)
		end
	end

	for i,t in pairs(map.wall_set) do
		if t then
			Textures.loadTexture(t)
			walltextures[i] = Textures.queryTexture(t)
		end
	end

	for z = 1,height do
		for x=1,width do
			local y1,y2,y3,y4

			--local tileh = map.height_map[z][x]
			local tileh = Map.getHeights(map, x,z)
			local tileid = map.tile_map[z][x]
			local tilewalls = Map.getWalls(map, x,z)

			local tileprops = map.tile_set[tileid]
			tileprops.tile_height1 = tileh[1]
			tileprops.tile_height2 = tileh[2]
			tileprops.tile_height3 = tileh[3]
			tileprops.tile_height4 = tileh[4]

			if tilewalls then
				local textures = {}
				for i = 1,4 do 
					local wallid = tilewalls[i]
					if wallid then
						textures[i] = walltextures[wallid]
					end
				end

				walls[z][x] = Wall:generateWall(textures,
					tileh, -- current tile
					Map.getHeights( map , x-1, z  ), -- west tile
					Map.getHeights( map , x  , z+1), -- south tile
					Map.getHeights( map , x+1, z  ), -- east tile
					Map.getHeights( map , x  , z-1)  -- north tile
					)

			end

			t = Tile.allocateTile(tileprops, textures[tileid])

			local realz = height - z + 1
			grid:swapTile(x,realz, t)
		end
	end

	return grid, walls
end

function Map.getHeights(map, x,z)
	if x < 1 or x > map.width or z < 1 or z > map.height then
		return nil
	end

	local y = {}
	local tileh = map.height_map[z][x]
	if type(tileh) == "table" then
		y[1],y[2],y[3],y[4] = tileh[1],tileh[2],tileh[3],tileh[4]
	else
		y[1],y[2],y[3],y[4] = tileh,tileh,tileh,tileh
	end
	return y
end

function Map.getWalls(map, x,z)
	local w = {}
	local walls = map.wall_map[z][x]

	if not walls then return nil end

	if type(walls) == "table" then
		w[1],w[2],w[3],w[4],w[5] = walls[1],walls[2],walls[3],walls[4],walls[5]
	else
		--w[1],w[2],w[3],w[4],w[5] = walls,walls,walls,nil,nil
		w[1],w[2],w[3],w[4],w[5] = walls,walls,walls,nil,nil
	end
	return w
end
