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


-- returns grid, walls, gridmeshset, wallmeshset. makes sure textures in tileset are loaded
function Map.loadMap(map)
	local maperror = Map.malformedCheck(map)
	if maperror then
		error(maperror)
		return
	end

	local width, height = map.width, map.height

	local grid = Grid.allocateGrid(width, height)
	local walls = {}
	local walltiles = {}
	for z=1,height do
		walls[z]={}
		walltiles[z] = {}
	end

	local textures = {}
	local walltextures = {}

	local gridmeshset = {}
	local wallmeshset = {}
	local function setinsert(t,id,data)
		if not t[id] then t[id] = {} end
		table.insert(t[id],data)
	end

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
			tileprops.tile_height1 = math.floor(tileh[1])
			tileprops.tile_height2 = math.floor(tileh[2])
			tileprops.tile_height3 = math.floor(tileh[3])
			tileprops.tile_height4 = math.floor(tileh[4])

			local realz = height - z + 1

			--table.insert(gridmeshset[tileid], {realz,x})
			setinsert(gridmeshset, tileid, {realz,x})

			if tilewalls then
				local textures = {}
				for i = 1,4 do 
					local wallid = tilewalls[i]
					if wallid then
						textures[i] = walltextures[wallid]
						--table.insert(wallmeshset[wallid], {realz,x,i})
						--setinsert(wallmeshset, wallid, {realz,x,i})
					end
				end


				wall = Wall:generateWall(textures,
					tileh, -- current tile
					Map.getHeights( map , x-1, z  ), -- west tile
					Map.getHeights( map , x  , z+1), -- south tile
					Map.getHeights( map , x+1, z  ), -- east tile
					Map.getHeights( map , x  , z-1)  -- north tile
					)

				local dest = { "west", "south", "east", "north"}
				if wall then
					walls[realz][x] = wall
					walltiles[realz][x] = {}

					for i=1,4 do
						local wd = wall[dest[i]]
						if wd then
							local wallid = tilewalls[i]
							setinsert(wallmeshset, wallid, {realz,x,i})

							walltiles[realz][x][i] = 
								WallTile:new{
								  wtile_texture = textures[i],
								  wtile_texture_scalex = 1,
								  wtile_texture_scaly = 1,
								  wtile_texture_offx = 0,
								  wtile_texture_scaly = 0,
								  wtile_coords = wall[dest[i]]
								}
						end
					end
				end

			end

			t = Tile:new(tileprops)

			--local realz = height - z + 1
			--grid:swapTile(x,realz, t)
			grid:swapTile(x,realz, t)
		end
	end

	return grid, walls, walltiles, gridmeshset, wallmeshset
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
		w[1],w[2],w[3],w[4],w[5] = walls,walls,walls,walls,nil
	end
	return w
end

-- wall_side
-- 1,2,3,4 = west,south,east,north
function Map.generateWallMesh(map, z,x, wall, wall_side, texture)
	if not wall then return nil end

	local mesh = Mesh:new(texture, 6, "triangles", "dynamic")

	local wx,wy,wz = Tile.tileCoordToWorld(x,0,z)
	local u,v = Wall.u, Wall.v

	local vert = {}
	if wall_side == Wall.westi then
		for i=1,4 do
			local wallv = wall.west[i]
			vert[i] = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+wallv[3]*TILE_SIZE, u[i], -wallv[2]}
		end
	elseif wall_side == Wall.southi then
		for i=1,4 do
			local wallv = wall.south[i]
			vert[i] = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+wallv[3]*TILE_SIZE, u[i], -wallv[2]}
		end
	elseif wall_side == Wall.easti then
		for i=1,4 do
			local wallv = wall.east[i]
			vert[i] = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+(wallv[3]-1)*TILE_SIZE, u[i], -wallv[2]}
		end
	elseif wall_side == Wall.northi then
		for i=1,4 do
			local wallv = wall.north[i]
			vert[i] = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+(wallv[3]-1)*TILE_SIZE, u[i], -wallv[2]}
		end
	end

	mesh:setRectangle(1,vert[1],vert[2],vert[3],vert[4])
	--mesh:fitTexture(TILE_SIZE, -TILE_HEIGHT)
	return mesh
end

function Map.getWallMeshes(map, walls, wallset, walltiles)
	local meshes = {}

	for i,v in pairs(wallset) do
		local texture = Textures.queryTexture(map.wall_set[i])
		local set_meshes = {}
		local set_walls = {}

		for _,wall_in_set in ipairs(v) do
			local z,x,side = wall_in_set[1], wall_in_set[2], wall_in_set[3]
			
			--print(map.wall_set[i], unpack(wall_in_set))
			local wall = walls[z][x]
			local mesh = Map.generateWallMesh(map, z,x, walls[z][x], side, texture)
			table.insert(set_meshes, mesh)
			table.insert(set_walls, wall)
		end

		local vindices = {}
		local merge = Mesh.mergeMeshes(texture, set_meshes, vindices, WallTile.atypes)
		table.insert(meshes, merge)

		for i,wall_in_set in ipairs(v) do
			local z,x,side = wall_in_set[1], wall_in_set[2], wall_in_set[3]

			local walltile = walltiles[z][x][side]
			local wtprops = walltile.props
			wtprops.wtile_mesh = merge.attr_mesh
			wtprops.wtile_mesh_vstart_index = vindices[i][1]
			wtprops.wtile_mesh_vend_index = vindices[i][2]
		end
	end

	return meshes
end

function Map.generateTileMesh(map, z,x, tile, texture)
	local mesh = Mesh:new(texture, 6, "triangles", "dynamic")

	local u = {0,1,1,0}
	local v = {0,0,1,1}

	local tprops = tile.props

	local x1,y1,z1 = Tile.tileCoordToWorld( x , tprops.tile_height1, (z+1) )
	local x2,y2,z2 = Tile.tileCoordToWorld( x+1, tprops.tile_height2, (z+1) )
	local x3,y3,z3 = Tile.tileCoordToWorld( x+1, tprops.tile_height3, (z+0) )
	local x4,y4,z4 = Tile.tileCoordToWorld( x+0, tprops.tile_height4, (z+0) )
	
	v1 = {x1,y1,z1, u[1], v[1]}
	v2 = {x2,y2,z2, u[2], v[2]}
	v3 = {x3,y3,z3, u[3], v[3]}
	v4 = {x4,y4,z4, u[4], v[4]}
	mesh:setRectangle(1, v1,v2,v3,v4)
	return mesh
end

function Map.generateLongTileMesh(map, z,x, tile, texture, length)
	local mesh = Mesh:new(texture, 6, "triangles", "dynamic")

	local u = {0,length,length,0}
	local v = {0,0,1,1}

	local tprops = tile.props

	local x1,y1,z1 = Tile.tileCoordToWorld( x , tprops.tile_height1, (z+1) )
	local x2,y2,z2 = Tile.tileCoordToWorld( x+length, tprops.tile_height2, (z+1) )
	local x3,y3,z3 = Tile.tileCoordToWorld( x+length, tprops.tile_height3, (z+0) )
	local x4,y4,z4 = Tile.tileCoordToWorld( x+0, tprops.tile_height4, (z+0) )
	
	v1 = {x1,y1,z1, u[1], v[1]}
	v2 = {x2,y2,z2, u[2], v[2]}
	v3 = {x3,y3,z3, u[3], v[3]}
	v4 = {x4,y4,z4, u[4], v[4]}
	mesh:setRectangle(1, v1,v2,v3,v4)
	return mesh
end

-- generates a rectangle spanning the entire bottom of the map, facing downwards, slightly below y=0
-- to be used when shadow mapping
function Map.generateBottomMesh(map)

	local width  = map.width
	local height = map.height

	local x1,y1,z1 = Tile.tileCoordToWorld( 0 , -0.5, height+1 )
	local x2,y2,z2 = Tile.tileCoordToWorld( width+1, -0.5, height+1 )
	local x3,y3,z3 = Tile.tileCoordToWorld( width+1, -0.5, 0 )
	local x4,y4,z4 = Tile.tileCoordToWorld( 0 , -0.5, 0 )

	local u = {0,1,1,0}
	local v = {0,0,1,1}

	v1 = {x1,y1,z1, u[1], v[1]}
	v2 = {x2,y2,z2, u[2], v[2]}
	v3 = {x3,y3,z3, u[3], v[3]}
	v4 = {x4,y4,z4, u[4], v[4]}
	
	local mesh = Mesh:new(Textures.queryTexture("nil.png"), 6, "triangles", "dynamic")
	mesh:setRectangle(1, v1,v2,v3,v4) -- vertices in opposite order to face downwards
	return mesh
end

-- returns table set with {x,z} for identical consecutive tiles, and how
-- many tiles are in this set
function Map.getIndenticalConsecutiveTiles(grid, x,z)
	local tile = grid:queryTile(x,z)
	if not tile:isLand() then
		return {},0 end

	local flat, height = tile:isFlat()
	if not flat then
		return {{x,z}}, 1 end

	local tiles = {{x,z}}
	local X = x + 1
	while X <= grid:getWidth() do
		local tile2 = grid:queryTile(X,z)

		local flat2, height2 = tile2:isFlat()
		if not tile2:isLand() or not flat2 then break end
		if height ~= height2 then break end
		if not tile:attributeEquals(tile2) then break end

		table.insert(tiles, {X,z})
		X=X+1
	end

	return tiles, X-x
end

function Map.getGridMeshes(map, grid, gridset)
	local meshes = {}

	for i,v in pairs(gridset) do
		local texture = Textures.queryTexture(map.tile_set[i].tile_texture)

		local set_meshes = {}
		local set_tiles  = {}

		-- sort elements in increasing x coordinate order
		table.sort(v, function(a,b) return a[2]<b[2] end)

		local grid_w = grid:getWidth()
		local tiles_done = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil} -- filled with nil's to reduce table resizes
		local tiles_done_index = function(x,z) return x+z*grid_w end

		for _,tile_in_set in ipairs(v) do
			local z,x = tile_in_set[1], tile_in_set[2]

			if not tiles_done[tiles_done_index(x,z)] then

				local consec, count = Map.getIndenticalConsecutiveTiles(grid, x,z)
				-- add all included tiles to tiles_done
				for i,v in ipairs(consec) do
					tiles_done[ tiles_done_index(v[1],v[2]) ] = true end

				--local tile = grid:queryTile(x,z)
				--local mesh = Map.generateTileMesh(map, z,x, grid:queryTile(x,z), texture)
				local tile = grid:queryTile(x,z)
				local mesh = Map.generateLongTileMesh(map, z,x, tile, texture, count)
				table.insert(set_meshes, mesh)
				table.insert(set_tiles, tile)

			end
		end

		local vindices = {}
		local merge = Mesh.mergeMeshes(texture, set_meshes, vindices, Tile.atypes)

		for i,tile in ipairs(set_tiles) do
			local props = tile.props
			props.tile_mesh = merge.attr_mesh
			props.tile_mesh_vstart_index = vindices[i][1]
			props.tile_mesh_vend_index = vindices[i][2]
		end

		table.insert(meshes, merge)
	end

	--local bottom_mesh = Map.generateBottomMesh(map)
	table.insert(meshes, bottom_mesh)

	return meshes
end


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
