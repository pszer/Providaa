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
--     each textured tile in the tile_set has an optional animated texture parameter
--     anim_tex = {
--       [1] = {textures = "dirt.png", "dirt2.png",
--              sequence = {1,2},
--              delay    = 30}
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
require "mapmesh"

local cpml = require 'cpml'

Map = {}
Map.__index = Map

local testmap = require "maps.test"

function Map.generateMapMesh( map )
	local maperror = Map.malformedCheck(map)
	if maperror then
		error(maperror)
		return
	end

	local tex_count = 0

	local textures = {}
	local tex_names = {}

	local function is_duplicate(tex_name)
		for i,v in ipairs(tex_names) do
			if v == tex_name then return i end
		end
		return nil
	end

	local tileset_id_to_tex = {}
	local wallset_id_to_tex = {}

	local function load_tex(i,tex_name, id_to_tex)
		local dup_id = is_duplicate(tex_name)
		if dup_id then
			id_to_tex[i] = dup_id
			return
		end

		tex_count = tex_count + 1
		textures[tex_count] = Loader:getTextureReference(tex_name)
		tex_names[tex_count] = tex_name
		id_to_tex[i] = tex_count
	end

	for i,t in pairs(map.tile_set) do
		local tex_name = t.tile_texture
		if tex_name then
			load_tex(i, tex_name, tileset_id_to_tex)
		end
	end

	for i,t in pairs(map.wall_set) do
		if t then
			load_tex(i, t, wallset_id_to_tex)
		end
	end

	-- generate atlas
	local atlas, atlas_uvs = MapMesh:generateTextureAtlas( textures )
	
	-- once the textures are added to an atlas, we don't need to keep
	-- references to the original textures
	for i,name in ipairs(tex_names) do
		Loader:deref("texture", name)
	end

	local verts = {}
	local vert_count = 0
	local index_map = {}
	local index_count = 0

	local attr_verts  = {}
	local attr_count = 0

	local simple_verts = {}
	local simple_vert_count = 0
	local simple_index_map = {}
	local simple_index_count = 0

	local int = math.floor
	local I = 1

	local rect_I = {1,2,3,3,4,1}

	-- generate floor tile vertices for the mesh
	while I <= map.width * map.height do
		local x = (I-1) % map.width + 1
		local z = map.height - int((I-1) / map.width)

		local tileid = map.tile_map[z][x]

		-- we only add a floor tile to mesh if it actually has a texture
		local tex_id = tileset_id_to_tex[tileid]
		if tex_id then
			local consec_count = Map.getIdenticalConsecutiveTilesCount(map, x,z)

			local h1,h2,h3,h4 = unpack(Map.getHeights(map, x,z))
			local gv1,gv2,gv3,gv4 = Map.getTileVerts(x,z,h1,h2,h3,h4)
			if consec_count == 1 then
				gv1,gv2,gv3,gv4 = Map.getTileVerts(x,z,h1,h2,h3,h4)
			else
				gv1,gv2,gv3,gv4 = Map.getLongTileVerts(x,z,h1,h2,h3,h4, consec_count)
				--gv1,gv2,gv3,gv4 = Map.getTileVerts(x,z,h1,h2,h3,h4)
			end
			local tex_norm_id = (tex_id-1) -- this will be the index sent to the shader

			local vert = {gv1,gv2,gv3,gv4}
			for i=1,4 do
				verts[vert_count+i] = vert[i]
			end
			for i=1,6 do
				index_map[index_count+i] = vert_count + rect_I[i]
			end
			vert_count  = vert_count  + 4
			index_count = index_count + 6

			local attr = { 1.0, 1.0, 0.0, 0.0, tex_norm_id }
			for i=1,4 do
				attr_verts[attr_count + i] = attr
			end
			attr_count = attr_count + 4

			I = I + consec_count
		else
			I = I + 1
		end
	end

	I = 1
	while I <= map.width * map.height do
		local x = (I-1) % map.width + 1
		local z = map.height - int((I-1) / map.width)
		local tilewalls = Map.getWalls(map, x,z)
		if tilewalls then
			local textures_loaded = {}
			for i = 1,4 do 
				local wallid = tilewalls[i]
				if wallid then
					textures_loaded[i] = wallset_id_to_tex[wallid]
				end
			end

			local tile_height  = Map.getHeights ( map , x   , z   )
			local west_height  = Map.getHeights ( map , x-1 , z   )
			local south_height = Map.getHeights ( map , x   , z+1 )
			local east_height  = Map.getHeights ( map , x+1 , z   )
			local north_height = Map.getHeights ( map , x   , z-1 )

			local wall =
				Wall:getWallInfo(textures,
					tile_height,
					west_height,
					south_height,
					east_height,
					north_height)

			local function add_wall_verts(wall, side, tex_id)
				local wv1,wv2,wv3,wv4 = Map.getWallVerts(x,z, wall, side)

				if not (wv1 and wv2 and wv3 and wv4) then return end

				--print(unpack(wv1))
				--print(unpack(wv2))
				--print(unpack(wv3))
				--print(unpack(wv4))

				local vert = {wv1,wv2,wv3,wv4}
				local tex_norm_id = (tex_id-1) -- this will be the index sent to the shader

				for i=1,4 do
					verts[vert_count+i] = vert[i]
				end
				for i=1,6 do
					index_map[index_count+i] = vert_count + rect_I[i]
				end
				vert_count  = vert_count  + 4
				index_count = index_count + 6

				local tex_height = textures[tex_id]:getHeight() / TILE_HEIGHT

				local attr = { 1.0, tex_height, 0.0, 0.0, tex_norm_id }
				for i=1,4 do
					attr_verts[attr_count + i] = attr
				end
				attr_count = attr_count + 4

				for i=1,4 do
					simple_verts[simple_vert_count + i] = vert[i]
				end
				for i=1,6 do
				simple_index_map[simple_index_count+i] = simple_vert_count + rect_I[i]
				end
				simple_vert_count = simple_vert_count + 4
				simple_index_count = simple_index_count + 6
			end

			add_wall_verts(wall, Wall.westi , textures_loaded[1])
			add_wall_verts(wall, Wall.southi, textures_loaded[2])
			add_wall_verts(wall, Wall.easti , textures_loaded[3])
			add_wall_verts(wall, Wall.northi, textures_loaded[4])
		end
		I = I + 1
	end

	local tile_in_simple_set = {}
	-- generated simplified floor tile vertices for the shadow mapping mesh
	I = 1
	while I <= map.width * map.height do
		local x = (I-1) % map.width + 1
		--local z = map.height - int((I-1) / map.width)
		local z = int((I-1) / map.width) + 1

		local tileid = map.tile_map[z][x]

		-- we only add a tile to mesh if it actually has a texture AND is not
		-- already part of the simplified set
		local tex_id = tileset_id_to_tex[tileid]
		if tex_id and not tile_in_simple_set[x + z*map.width] then
			local square_size = Map.getIdenticalSquareTilesCount(map, x,z)

			--print(x,z,x+square_size,z+square_size,square_size)
			
			-- add all tiles in the square to the simplified set
			for Z=0,square_size-1 do
				for X=0,square_size-1 do
					tile_in_simple_set[x+X + (z+Z)*map.width] = true
				end
			end

			local h1,h2,h3,h4 = unpack(Map.getHeights(map, x,z))
			local gv1,gv2,gv3,gv4 = Map.getSimpleSquareTileVerts(x,z,h1,h2,h3,h4, square_size,square_size)
			local vert = {gv1,gv2,gv3,gv4}

			for i=1,4 do
				simple_verts[simple_vert_count + i] = vert[i]
			end
			for i=1,6 do
			simple_index_map[simple_index_count+i] = simple_vert_count + rect_I[i]
			end
			simple_vert_count = simple_vert_count + 4
			simple_index_count = simple_index_count + 6
		end

		I = I + 1
	end

	local mesh = love.graphics.newMesh(MapMesh.atypes, verts, "triangles", "static")
	mesh:setVertexMap(index_map)
	mesh:setTexture(atlas)
	local attr_mesh = love.graphics.newMesh(MapMesh.atts_atypes, attr_verts, "triangles", "static")
	--attr_mesh:setVertexMap(attr_index_map)
	mesh:attachAttribute("TextureScale", attr_mesh, "pervertex")
	mesh:attachAttribute("TextureOffset", attr_mesh, "pervertex")
	mesh:attachAttribute("TextureUvIndex", attr_mesh, "pervertex")

	local simple_mesh = love.graphics.newMesh(MapMesh.simple_atypes, simple_verts, "triangles", "static")
	simple_mesh:setVertexMap(simple_index_map)

	return MapMesh:new(mesh, attr_mesh, atlas, atlas_uvs, simple_mesh)

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
		w[1],w[2],w[3],w[4] = walls[1],walls[2],walls[3],walls[4]
	else
		--w[1],w[2],w[3],w[4],w[5] = walls,walls,walls,nil,nil
		w[1],w[2],w[3],w[4] = walls,walls,walls,walls
	end
	return w
end

local __tempverts = {}
function Map.getWallVerts(x,z, wall, wall_side)
	if not wall then return nil,nil,nil,nil end

	local wx,wy,wz = Tile.tileCoordToWorld(x,0,z)
	local u,v = Wall.u, Wall.v

	local function get_uv_v_max(side) 
		local m = -1/0
		for i=1,4 do m = math.max(side[i][2], m) end
		return m
	end

	local vert = __tempverts
	if wall_side == Wall.westi then
		if not wall.west then return nil,nil,nil,nil end
		local vmax = get_uv_v_max(wall.west)
		for i=1,4 do
			local wallv = wall.west[i]
			__tempverts[i] = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3]+1)*TILE_SIZE, u[i], wallv[2]-vmax,
			                  -1,0,0}
		end
	elseif wall_side == Wall.southi then
		if not wall.south then return nil,nil,nil,nil end
		local vmax = get_uv_v_max(wall.south)
		for i=1,4 do
			local wallv = wall.south[i]
			__tempverts[i] = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3]+1)*TILE_SIZE, u[i], wallv[2]-vmax,
			                  0,0,1}
		end
	elseif wall_side == Wall.easti then
		if not wall.east then return nil,nil,nil,nil end
		local vmax = get_uv_v_max(wall.east)
		for i=1,4 do
			local wallv = wall.east[i]
			__tempverts[i] = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3])*TILE_SIZE, u[i], wallv[2]-vmax,
			                  1,0,0}
		end
	elseif wall_side == Wall.northi then
		if not wall.north then return nil,nil,nil,nil end
		local vmax = get_uv_v_max(wall.north)
		for i=1,4 do
			local wallv = wall.north[i]
			__tempverts[i] = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3])*TILE_SIZE, u[i], wallv[2]-vmax,
			                  0,0,-1}
		end
	end
	
	return __tempverts[1], __tempverts[2], __tempverts[3], __tempverts[4]
end


local __tempavec = cpml.vec3.new()
local __tempbvec = cpml.vec3.new()
local __tempnorm1 = cpml.vec3.new()
local __tempnorm2 = cpml.vec3.new()
function Map.getTileVerts(x,z, h1,h2,h3,h4)
	local u = {0,1,1,0}
	local v = {0,0,1,1}

	local x1,y1,z1 = Tile.tileCoordToWorld( x+0 , h1 , -(z+0) )
	local x2,y2,z2 = Tile.tileCoordToWorld( x+1 , h2 , -(z+0) )
	local x3,y3,z3 = Tile.tileCoordToWorld( x+1 , h3 , -(z+1) )
	local x4,y4,z4 = Tile.tileCoordToWorld( x+0 , h4 , -(z+1) )

	local norm1 = __tempnorm1
	local norm2 = __tempnorm2
	local function calcnorm(norm, x1,y1,z1, x2,y2,z2, x3,y3,z3 )

		x2 = x2 - x1
		y2 = y2 - y1
		z2 = z2 - z1

		x3 = x3 - x1
		y3 = y3 - y1
		z3 = z3 - z1

		--local a,b = cpml.vec3(x2,y2,z2), cpml.vec3(x3,y3,z3)
		local a,b = __tempavec, __tempbvec
		a.x, a.y, a.z = x2,y2,z2
		b.x, b.y, b.z = x3,y3,z3

		norm = cpml.vec3.cross(a,b)
		norm = cpml.vec3.normalize(norm)
		return norm
	end

	norm1 = calcnorm(norm1, x1,y1,z1, x2,y2,z2, x3,y3,z3 )
	norm2 = calcnorm(norm2, x3,y3,z3, x4,y4,z4, x1,y1,z1 )

	local norm3x = (norm1.x + norm2.x) * 0.5
	local norm3y = (norm1.y + norm2.y) * 0.5
	local norm3z = (norm1.z + norm2.z) * 0.5


	
	v1 = {x1,y1,z1, u[1], v[1], norm1.x, norm1.y, norm1.z }
	v2 = {x2,y2,z2, u[2], v[2], norm3x, norm3y, norm3z }
	v3 = {x3,y3,z3, u[3], v[3], norm3x, norm3y, norm3z }
	v4 = {x4,y4,z4, u[4], v[4], norm2.x, norm2.y, norm2.z }

	return v1,v2,v3,v4
end

function Map.getLongTileVerts(x,z, h1,h2,h3,h4, length)
	local u = {0,length,length,0}
	local v = {0,0,1,1}

	local x1,y1,z1 = Tile.tileCoordToWorld( x+0      , h1 , -(z+0) )
	local x2,y2,z2 = Tile.tileCoordToWorld( x+length , h2 , -(z+0) )
	local x3,y3,z3 = Tile.tileCoordToWorld( x+length , h3 , -(z+1) )
	local x4,y4,z4 = Tile.tileCoordToWorld( x+0      , h4 , -(z+1) )
	
	v1 = {x1,y1,z1, u[1], v[1], 0, -1, 0 }
	v2 = {x2,y2,z2, u[2], v[2], 0, -1, 0 }
	v3 = {x3,y3,z3, u[3], v[3], 0, -1, 0 }
	v4 = {x4,y4,z4, u[4], v[4], 0, -1, 0}

	return v1,v2,v3,v4
end

function Map.getSimpleSquareTileVerts(x,z, h1,h2,h3,h4, width, height)
	local x1,y1,z1 = Tile.tileCoordToWorld( x+0     , h1 , -(z+0) )
	local x2,y2,z2 = Tile.tileCoordToWorld( x+width , h2 , -(z+0) )
	local x3,y3,z3 = Tile.tileCoordToWorld( x+width , h3 , -(z+height) )
	local x4,y4,z4 = Tile.tileCoordToWorld( x+0     , h4 , -(z+height) )
	
	v1 = {x1,y1,z1}
	v2 = {x2,y2,z2}
	v3 = {x3,y3,z3}
	v4 = {x4,y4,z4}

	return v1,v2,v3,v4

end


function Map.getIdenticalConsecutiveTilesCount(map, x,z)
	local tile_id = map.tile_map[z][x]
	local h1,h2,h3,h4 = unpack(Map.getHeights(map, x,z))

	if (h1~=h2) or (h1~=h3) or(h1~=h4) then -- we check that the start tile is flat
		return 1 end

	local X = x + 1
	while X <= map.width do
		local tile_id2 = map.tile_map[z][X]
		if tile_id ~= tile_id2 then
			break end
		local j1,j2,j3,j4 = unpack(Map.getHeights(map, X,z))
		if (j1~=j2) or (j1~=j3) or(j1~=j4) then -- we check that the next tile is flat
			break end
		if (j1~=h1) then -- check that the next tile has the same height as the start tile
			break end

		X=X+1
	end

	return X-x
end

function Map.getIdenticalSquareTilesCount(map, x,z)
	local tile_id = map.tile_map[z][x]
	if map.tile_set[tile_id].tile_texture == nil then
		return 1,1 end

	local h1,h2,h3,h4 = unpack(Map.getHeights(map, x,z))

	if (h1~=h2) or (h1~=h3) or(h1~=h4) then -- we check that the start tile is flat
		return 1 end

	local i = 1
	while x+i <= map.width and z+i <= map.height do
		local pass = true

		for X=x,x+i do
			local Z = z+i
			local tile_id2 = map.tile_map[Z][X]
			if map.tile_set[tile_id].tile_texture == nil then -- check that the next tile is renderable
				pass = false break end
			local j1,j2,j3,j4 = unpack(Map.getHeights(map, X,Z))
			if (j1~=j2) or (j1~=j3) or(j1~=j4) then -- we check that the next tile is flat
				pass = false break end
			if (j1~=h1) then -- check that the next tile has the same height as the start tile
				pass = false break end
		end
		if not pass then break end

		for Z=z,z+i-1 do
			local X = x+i
			local tile_id2 = map.tile_map[Z][X]
			if map.tile_set[tile_id].tile_texture == nil then -- check that the next tile is renderable
				pass = false break end
			local j1,j2,j3,j4 = unpack(Map.getHeights(map, X,Z))
			if (j1~=j2) or (j1~=j3) or(j1~=j4) then -- we check that the next tile is flat
				pass = false end
			if (j1~=h1) then -- check that the next tile has the same height as the start tile
				pass = false end
		end
		if not pass then break end

		i=i+1
	end

	return i,i
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
