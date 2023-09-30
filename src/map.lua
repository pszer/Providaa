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
--     each entry in the tile_set is a texture name
--     only the [0] index is allowed to be nil
--     tile_set = {
--       [0] = nil,
--       [1] = "dirt.png",
--     },
--
--     textures can be given animations, in this example any tile/wall with a
--     "dirt.png" (the first texture listed in the textures paramater) texture will have this animation applied to them
--     anim_tex = {
--       [1] = {textures = "dirt.png", "dirt2.png",
--              sequence = {1,2},
--              delay    = 30}
--     },
--
--     each entry in the wall_set is a texture to use when generating walls 
--     only the [0] index is allowed to be nil
--     wall_set = {
--       [0] = nil
--       [1] = "wall.png"
--       [2] = "wall2.png"
--     },
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
--     },
--
--
--     all the static models in a map
--     each entry is of the form
--     {name="model.iqm", pos={6,6,6}}
--     or
--     {name="model.iqm", matrix={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}}
--
--     the position is given in tile coordinates, the actual world position will be (x*TILE_SIZE, y*TILE_HEIGHT, z*TILE_SIZE)
--     the position can have either 3 components or 2 components, 3 components specify (x,y,z) and 2 components specify only (x,?,z), the
--     model's y position is then determined by the height of the tile at (x,z)
--
--     a model matrix can be specified instead of a position vector
--
--     models =
--     {
--      {name="model.iqm", pos={6,6,6}, orient={0,0,-1,"dir"}, scale={1,1,1}},
--      {name="model.iqm", pos={6,6,6}}
--      {name="model.iqm", matrix={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}}
--     }
--
-- }

--require "texture"
require "grid"
require "wall"
require "mapmesh"
require "model"

local cpml = require 'cpml'

Map = { __dir = "maps/" }
Map.__index = Map

local testmap = require "maps.test"

function Map.getMap(filename)
	assert_type(filename, "string")
	local map = loadfile(Map.__dir .. filename)
	assert(map, string.format("Map.getMap(): map %s%s doesn't exist", Map.__dir, filename))
	map.name = filename
	return map
end

-- returns tex_count
function Map.internalLoadTilesetTextures( map , textures , tex_names , tex_count , tileset_id_to_tex , wallset_id_to_tex )
	assert(map and textures and tex_names and tileset_id_to_tex and wallset_id_to_tex)

	tex_count = tex_count

	local function is_duplicate(tex_name)
		for i,v in ipairs(tex_names) do
			if v == tex_name then return i end
		end
		return nil
	end

	local function load_tex(i,tex_name, id_to_tex)
		local dup_id = is_duplicate(tex_name)
		if dup_id then
			if id_to_tex then
				id_to_tex[i] = dup_id end
			return dup_id
		end

		tex_count = tex_count + 1
		textures[tex_count] = Loader:getTextureReference(tex_name)
		tex_names[tex_count] = tex_name
		if id_to_tex then
			id_to_tex[i] = tex_count end
		return tex_count
	end

	for i,t in pairs(map.tile_set) do
		local tex_name = t
		if tex_name then
			load_tex(i, tex_name, tileset_id_to_tex)
		end
	end

	for i,t in pairs(map.wall_set) do
		local tex_name = t
		if tex_name then
			load_tex(i, tex_name, wallset_id_to_tex)
		end
	end

	return tex_count
end

-- returns updated tex_count
function Map.internalLoadAnimTextureDefinitions(map, anim_textures_info, textures, tex_names, tex_count)
	local function is_duplicate(tex_name)
		for i,v in ipairs(tex_names) do
			if v == tex_name then return i end
		end
		return nil
	end

	local function load_tex(tex_name)
		local dup_id = is_duplicate(tex_name)
		if dup_id then
			return dup_id
		end

		tex_count = tex_count + 1
		textures[tex_count] = Loader:getTextureReference(tex_name)
		tex_names[tex_count] = tex_name
		return tex_count
	end
	-- we generate the information needed for animated textures
	-- all textures specified are loaded and correct indices are assigned
	for i,v in pairs(map.anim_tex) do
		anim_textures_info[i] = v

		local texs = v.textures

		local seq_length = #v.sequence
		local tex_count  = #v.textures
		anim_textures_info[i].seq_length = seq_length
		anim_textures_info[i].tex_count  = tex_count

		anim_textures_info[i].delay = v.delay or 8

		local seq = anim_textures_info[i].sequence
		for j,u in ipairs(seq) do
			if u > tex_count then
				print(string.format("Map.generateMapMesh(): animated texture for tile type %s has a malformed sequence, correcting.", tostring(i)))
				seq[j] = tex_count
			elseif u < 1 then
				print(string.format("Map.generateMapMesh(): animated texture for tile type %s has a malformed sequence, correcting.", tostring(i)))
				seq[j] = 1
			end
		end

		anim_textures_info[i].indices = {}
		for j,tex_name in ipairs(texs) do
			local index =load_tex(tex_name)
			anim_textures_info[i].indices[j] = index
		end
	end

	return tex_count
end

-- returns vert_count, index_count, attr_count
function Map.internalGenerateTileVerts(map, verts, index_map, attr_verts,
                                            vert_count, index_count, attr_count,
											tileset_id_to_tex, optimise, gen_all_verts, nil_texture_id, tile_vert_map)
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
		if tex_id or gen_all_verts then
			local consec_count = 1
			if optimise then
				consec_count = Map.getIdenticalConsecutiveTilesCount(map, x,z)
			end

			local h1,h2,h3,h4 = unpack(Map.getHeights(map, x,z))
			local gv1,gv2,gv3,gv4 = Map.getTileVerts(x,z,h1,h2,h3,h4)
			if consec_count == 1 then
				gv1,gv2,gv3,gv4 = Map.getTileVerts(x,z,h1,h2,h3,h4)
			else
				gv1,gv2,gv3,gv4 = Map.getLongTileVerts(x,z,h1,h2,h3,h4, consec_count)
				--gv1,gv2,gv3,gv4 = Map.getTileVerts(x,z,h1,h2,h3,h4)
			end
			local tex_norm_id = nil
			if tex_id then
				tex_norm_id = (tex_id-1) -- this will be the index sent to the shader
			else
				tex_norm_id = (nil_texture_id - 1)
			end

			if tile_vert_map then
				tile_vert_map[z][x] = vert_count+1
			end

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

	return vert_count, index_count, attr_count
end

function Map.internalGenerateWallVerts(map, verts, index_map, attr_verts,
                                            vert_count, index_count, attr_count,
											wallset_id_to_tex, textures,
											gen_all_verts, nil_texture_id,
											wall_vert_map)
	local int = math.floor
	local I = 1
	local rect_I = {1,2,3,3,4,1}

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
				elseif gen_all_verts then
					textures_loaded[i] = nil_texture_id
				end
			end

			local tile_height  = Map.getHeights ( map , x   , z   )
			local west_height  = Map.getHeights ( map , x-1 , z   )
			local south_height = Map.getHeights ( map , x   , z+1 )
			local east_height  = Map.getHeights ( map , x+1 , z   )
			local north_height = Map.getHeights ( map , x   , z-1 )

			local wall = nil
			if not gen_all_verts then
				wall = 
					Wall:getWallInfo(textures,
						tile_height,
						west_height,
						south_height,
						east_height,
						north_height)
			else -- if gen_all_walls, we skip testing if a wall has a texture defined and generate vertices for all walls
				wall = 
					Wall:getWallInfo(nil,
						tile_height,
						west_height,
						south_height,
						east_height,
						north_height)

			end

			local function add_wall_verts(wall, side, tex_id)
				if not tex_id then return end

				local wv1,wv2,wv3,wv4 = Map.getWallVerts(x,z, wall, side)

				if not (wv1 and wv2 and wv3 and wv4) then return end

				local vert = {wv1,wv2,wv3,wv4}
				local tex_norm_id = (tex_id-1) -- this will be the index sent to the shader

				if wall_vert_map then
					wall_vert_map[z][x][side] = vert_count+1
				end

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
			end

			add_wall_verts(wall, Wall.westi , textures_loaded[1])
			add_wall_verts(wall, Wall.southi, textures_loaded[2])
			add_wall_verts(wall, Wall.easti , textures_loaded[3])
			add_wall_verts(wall, Wall.northi, textures_loaded[4])
		end
		I = I + 1
	end

	return vert_count, index_count, attr_count
end

function Map.internalGenerateWallVertsBuffered(map, verts, index_map, attr_verts,
                                               vert_count, index_count, attr_count,
											   wallset_id_to_tex, textures,
											   gen_all_verts, nil_texture_id,
											   wall_vert_map, wall_exists)
	local int = math.floor
	local I = 1
	local rect_I = {1,2,3,3,4,1}

	while I <= map.width * map.height do
		local x = (I-1) % map.width + 1
		local z = map.height - int((I-1) / map.width)
		local tilewalls = Map.getWalls(map, x,z)
		local textures_loaded = {}
		if not tilewalls then tilewalls = {} end

		for i = 1,4 do 
			local wallid = tilewalls[i]
			if wallid and wallset_id_to_tex[wallid] then
				textures_loaded[i] = wallset_id_to_tex[wallid]
			else
				textures_loaded[i] = nil_texture_id
			end
		end

		local tile_height  = Map.getHeights( map , x   , z   )
		local west_height  = Map.getHeights( map , x-1 , z   )
		local south_height = Map.getHeights( map , x   , z+1 )
		local east_height  = Map.getHeights( map , x+1 , z   )
		local north_height = Map.getHeights( map , x   , z-1 )

		local wall = 
			Wall:getWallInfo(nil,
				tile_height,
				west_height,
				south_height,
				east_height,
				north_height)


		local function add_wall_verts(wall, side, tex_id)
			--if not tex_id then return end
			local wv1,wv2,wv3,wv4 = Map.getWallVerts(x,z, wall, side)

			local exists = true
			if not (wv1 and wv2 and wv3 and wv4) then
				wv1 = {0,0,0}
				wv2 = wv1
				wv3 = wv2
				wv4 = wv3
				exists = false
			end

			local vert = {wv1,wv2,wv3,wv4}
			local tex_norm_id = (tex_id-1) -- this will be the index sent to the shader

			if wall_vert_map then
				wall_vert_map[z][x][side] = vert_count+1 end
			if wall_exists then
				wall_exists[z][x][side] = exists
			end

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
		end

		add_wall_verts(wall, Wall.westi , textures_loaded[1])
		add_wall_verts(wall, Wall.southi, textures_loaded[2])
		add_wall_verts(wall, Wall.easti , textures_loaded[3])
		add_wall_verts(wall, Wall.northi, textures_loaded[4])
		I = I + 1
	end

	return vert_count, index_count, attr_count
end

function Map.internalGenerateSimpleWallVerts(map, simple_verts, simple_index_map,
                                                  simple_vert_count, simple_index_count,
											      wallset_id_to_tex, textures)
	local int = math.floor
	local I = 1
	local rect_I = {1,2,3,3,4,1}

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

				local vert = {wv1,wv2,wv3,wv4}

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

	return simple_vert_count, simple_index_count
end

function Map.internalGenerateSimpleTileVerts(map, simple_verts, simple_index_map, simple_vert_count, simple_index_count, tileset_id_to_tex)
	local int = math.floor
	local I = 1
	local rect_I = {1,2,3,3,4,1}

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
	return simple_vert_count, simple_index_count
end

-- generates and returns a MapMesh object from a given map and optional parameters
--
-- dont_optimise      = true : dont optimise tile mesh by merging identical consecutive tiles
-- dont_gen_simple    = true : dont generate the textureless simple mesh (made for use with shadowmapping)
-- gen_all_verts      = true : generate vertices for textureless void tiles
-- gen_nil_texture    = ...  : texture to use for the void tiles generated by gen_all_verts, either a texture filename/love2d texture
-- gen_index_map      = true : generates a mapping table, mapping tiles/walls to their vertices inside mapmesh.mesh
-- gen_newvert_buffer = true : buffers out mapmesh.mesh with addtional (0,0,0) vertices, it will then hold enough space for any number of
--                             additional walls to dynamically add to the mesh. will also preemptively fill out the revelant wall_vert_map
--                             info for these buffered walls and setup a wall_exists table in map_mesh.
function Map.generateMapMesh( map , params )
	local maperror = Map.malformedCheck(map)
	if maperror then
		error(maperror)
		return
	end

	local params = params or {}
	local optimise   = not params.dont_optimise
	local gen_simple = not params.dont_gen_simple

	local gen_all_verts   = params.gen_all_verts
	local gen_nil_texture = params.gen_nil_texture
	local nil_texture_id  = -1

	local gen_index_map  = params.gen_index_map
	local gen_newvert_buffer = params.gen_newvert_buffer

	local keep_textures = params.keep_textures

	if gen_all_walls and not gen_nil_texture then
		error("Map.generateMapMesh(): gen_all_verts enabled, but no gen_nil_texture supplied. give either a filename/texture")
	end

	local textures = {}
	local tex_names = {}
	local tileset_id_to_tex = {}
	local wallset_id_to_tex = {}

	local tex_count = 0
	if gen_nil_texture then
		local arg_type = type(gen_nil_texture)
		if arg_type == "string" then
			local nil_tex = Loader:getTextureReference(gen_nil_texture)
			assert(nil_tex)
			tex_count = tex_count+1
			textures[tex_count] = nil_tex
			tex_names[tex_count] = gen_nil_texture
		elseif arg_type == "Texture" then
			tex_count = tex_count+1
			textures[tex_count] = gen_nil_texture
			tex_names[tex_count] = ""
		else
			error(string.format("Map:generateMapMesh(): gen_nil_texture parameter type is %s, expected a string filename/love2d texture.", arg_type))
		end
		
		nil_texture_id = tex_count
	end

	tex_count = Map.internalLoadTilesetTextures(map, textures, tex_names, tex_count, tileset_id_to_tex, wallset_id_to_tex)

	local anim_textures_info = {}
	tex_count = Map.internalLoadAnimTextureDefinitions(map, anim_textures_info, textures, tex_names, tex_count)
	
	-- generate atlas
	local atlas, atlas_uvs = MapMesh:generateTextureAtlas( textures )
	
	-- once the textures are added to an atlas, we don't need to keep
	-- references to the original textures
	if not keep_textures then
		for i,name in ipairs(tex_names) do
			if name and name ~= "" then
				Loader:deref("texture", name)
			end
		end
	else
		textures.names = tex_names
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

	local wall_exists = {}

	if gen_newvert_buffer then
		for z = 1, map.height do
			wall_exists[z] = {}
			for x = 1, map.width do
				wall_exists[z][x] = {false,false,false,false}
			end
		end
	end

	local tile_vert_map, wall_vert_map = nil,nil
	if gen_index_map then	
		tile_vert_map = {}
		wall_vert_map = {}

		for z=1,map.height do
			tile_vert_map[z] = {}
			wall_vert_map[z] = {}
			for x=1,map.width do
				wall_vert_map[z][x] = {
					--west=1,south=2,east=3,north=4
				}
			end
		end
	end

	local int = math.floor
	local I = 1

	local rect_I = {1,2,3,3,4,1}

	vert_count, index_count, attr_count =
		Map.internalGenerateTileVerts(map, verts, index_map, attr_verts,
		                                   vert_count, index_count, attr_count,
										   tileset_id_to_tex, optimise, gen_all_verts, nil_texture_id,
										   tile_vert_map)
	if gen_newvert_buffer then
		vert_count, index_count, attr_count =
			Map.internalGenerateWallVertsBuffered(map, verts, index_map, attr_verts,
											      vert_count, index_count, attr_count,
											      wallset_id_to_tex, textures, gen_all_verts, nil_texture_id,
											      wall_vert_map, wall_exists)
	else
		vert_count, index_count, attr_count =
			Map.internalGenerateWallVerts(map, verts, index_map, attr_verts,
											   vert_count, index_count, attr_count,
											   wallset_id_to_tex, textures, gen_all_verts, nil_texture_id,
											   wall_vert_map)
	end

	if gen_simple then
		simple_vert_count, simple_index_count =
			Map.internalGenerateSimpleTileVerts(map, simple_verts, simple_index_map,
													 simple_vert_count, simple_index_count, tileset_id_to_tex)

		simple_vert_count, simple_index_count =
			Map.internalGenerateSimpleWallVerts(map, simple_verts, simple_index_map,
													 simple_vert_count, simple_index_count, wallset_id_to_tex,
													 textures)
	end

	local mesh = love.graphics.newMesh(MapMesh.atypes, verts, "triangles", "static")
	mesh:setVertexMap(index_map)
	mesh:setTexture(atlas)

	local attr_mesh = love.graphics.newMesh(MapMesh.atts_atypes, attr_verts, "triangles", "static")
	mesh:attachAttribute("TextureScale", attr_mesh, "pervertex")
	mesh:attachAttribute("TextureOffset", attr_mesh, "pervertex")
	mesh:attachAttribute("TextureUvIndex", attr_mesh, "pervertex")

	local simple_mesh = nil
	if gen_simple then
		simple_mesh = love.graphics.newMesh(MapMesh.simple_atypes, simple_verts, "triangles", "static")
		simple_mesh:setVertexMap(simple_index_map)
	end

	--return MapMesh:new(mesh, attr_mesh, atlas, atlas_uvs, simple_mesh, anim_textures_info, tile_vert_map, wall_vert_map, wall_exists)
	
	if not keep_textures then
		textures = nil
		tex_names = nil
	end

	return MapMesh:new{
		mesh=mesh,
		mesh_atts=attr_mesh,
		tex=atlas,
		uvs=atlas_uvs,
		simple_mesh=simple_mesh,
		animated_tex_info=anim_textures_info,
		tile_vert_map=tile_vert_map,
		wall_vert_map=wall_vert_map,
		wall_exists=wall_exists,

		textures=textures,
		texture_names=tex_names}

end

function Map.getHeights(map, x,z)
	if x < 1 or x > map.width or z < 1 or z > map.height then
		return {0,0,0,0}
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

-- unlike Map.getHeights, this function doesn't return {0,0,0,0}
-- if x and z are out of bounds
function Map.getHeightsBounded(map, x,z)
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

function Map.getHeightsInterp(map, x,z)
	local int = math.floor
	local int_x, int_z = int(x), int(z)
	local h = Map.getHeights(map, int_x,int_z)

	local xi,yi = x-int_x , y-int_y

	return (1.0-xi)*(1.0-yi) * h[1] +
	            xi *(1.0-yi) * h[2] +
				xi *     yi  * h[3] +
		   (1.0-xi)*     yi  * h[4]
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

local DEG_TO_RADIANS = math.pi/180.0
function Map.generateModelInstances(map, dont_use_instancing)
	local model_defs = map.models

	local models = {}
	for i,v in ipairs(model_defs) do
		local mod_name = v.name
		if not models[mod_name] then
			models[mod_name] = {}
		end
		Loader:openModel(mod_name)
		table.insert(models[mod_name], i)
	end

	local insts_count = 0
	local insts = {}

	local default_rot, default_scale = {0,0,0,"rot"}, {1,1,1}
	for model_name , indices in pairs(models) do
		--local model = Loader:getModelReference(model_name)
		local model = Models.loadModel(model_name)

		for i,v in ipairs(indices) do
			local mod_info = model_defs[v]

			--[[local mod_pos    = mod_info.pos
			local mod_orient = mod_info.orient or default_rot
			local mod_scale  = mod_info.scale  or default_scale
			local final_pos
			local final_rot
			local final_scale = {mod_scale[1],mod_scale[2],mod_scale[3]}

			if #mod_pos == 3 then
				final_pos = {mod_pos[1] * TILE_SIZE, mod_pos[2] * TILE_HEIGHT, mod_pos[3] * TILE_SIZE}
			else
				local y = Map.getHeightsInterp(map, mod_pos[1], mod_pos[3])
				final_pos = {mod_pos[1] * TILE_SIZE, y * TILE_HEIGHT, mod_pos[3] * TILE_SIZE}
			end

			if mod_orient[4] == "rot" then
				final_rot = {
				mod_orient[1] * DEG_TO_RADIANS,
				mod_orient[2] * DEG_TO_RADIANS,
				mod_orient[3] * DEG_TO_RADIANS,
				"rot"}
			elseif mod_orient[4] == "dir" then
				if mod_orient[1] == 0 and mod_orient[2] == 0 and mod_orient[3] == 0 then
					final_rot = {0,0,-1,"dir"}
				else
					final_rot = {mod_orient[1],mod_orient[2],mod_orient[3],"dir"}
				end
			else
				final_rot = {0,0,0,"rot"}
			end

			indices[i] = ModelInfo.new(final_pos, final_rot, final_scale)--]]

			local mod_pos = mod_info.pos
			local mod_mat = mod_info.matrix

			if mod_mat then
				indices[i] = ModelInfo.newFromMatrix(cpml.mat4.new(mod_mat))
			else
				local final_pos
				if #mod_pos == 3 then
					final_pos = {mod_pos[1] * TILE_SIZE, mod_pos[2] * TILE_HEIGHT, mod_pos[3] * TILE_SIZE}
				else
					local y = Map.getHeightsInterp(map, mod_pos[1], mod_pos[3])
					final_pos = {mod_pos[1] * TILE_SIZE, y * TILE_HEIGHT, mod_pos[3] * TILE_SIZE}
				end

				local mat = cpml.mat4.new()
				local vec = cpml.vec3.new(final_pos)
				mat:translate(mat, vec)
				--indices[i] = ModelInfo.new(final_pos, {0,0,-1,"dir",{1,1,1}})
				indices[i] = ModelInfo.newFromMatrix(mat)
			end
		end

		local model_inst = nil
		local count = #indices
		-- if the model appears several times, we use a gpu instancing variant of
		-- ModelInstance
		if count == 1 then
			indices[1].model_i_static = true
			model_inst = ModelInstance:newInstance(model, indices[1])
			insts_count = insts_count+1
			insts[insts_count] = model_inst
		else
			if not dont_use_instancing then
				model_inst = ModelInstance:newInstances(model, indices)
				insts_count = insts_count+1
				insts[insts_count] = model_inst
			else
				for _,info in ipairs(indices) do
					local model_inst = ModelInstance:newInstance(model, info)
					insts_count = insts_count+1
					insts[insts_count] = model_inst
				end
			end
		end
	end

	return insts
end

-- returns a skybox_texture, skybox_texture_name, skybox_hdr_brightness
function Map.generateSkybox(map)
	local skybox = map.skybox
	assert(skybox)

	local tex_name = skybox.texture
	local brightness = skybox.brightness or 1.0

	local tex = Loader:getTextureReference(tex_name)
	assert(tex)

	local tex_type = tex:getTextureType()
	if tex_type ~= "cube" then
		error(string.format("Map.generateSkybox(): map %s, skybox texture %s is not a cubemap.", tostring(map.name), tostring(tex_name)))
	end

	return tex, tex_name, brightness
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

	local models   = map.models
	if not models then
		return string.format("Map %s is missing a model table, add an empty [\"models\"]={} if not needed", name) end

	for i,v in ipairs(models) do
		local mod_name   = v.name
		local mod_pos    = v.pos
		local mod_matrix = v.matrix

		if not mod_name then
			return string.format("Map %s model index %d is missing a model name", name, i) end
		if not mod_pos and not mod_matrix then
			return string.format("Map %s model index %d with model %s is missing a model position/model matrix", name, i, mod_name) end
		if mod_pos then
			if #mod_pos ~= 3 then
				return string.format("Map %s model index %d with model %s has a malformed position", name, i, mod_name) 
			end
			for I=1,3 do
				if type(mod_pos[I]) ~= "number" then
					return string.format("Map %s model index %d with model %s has a malformed position, non-number data", name, i, mod_name) 
				end
			end
		end
		if mod_matrix then
			if #mod_matrix ~= 16 then
				return string.format("Map %s model index %d with model %s has a malformed matrix", name, i, mod_name)
			end
			for I=1,16 do
				if type(mod_matrix[I]) ~= "number" then
					return string.format("Map %s model index %d with model %s has a malformed matrix, non-number data", name, i, mod_name) 
				end
			end
		end
	end

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
			if not tile_set[tile] and tile ~= 0 then
				return string.format("Map %s: tile (z=%d,x=%d) uses undefined tile [%s]", name, z,x, tostring(tile))
			end
			--if wall and not wall_set[wall] and wall ~= 0 then
			--	return string.format("Map %s: wall (z=%d,x=%d) uses undefined wall [%s]", name, z,x, tostring(wall))
			--end
		end
	end

	local anim_tex = map.anim_tex
	if not anim_tex then
		return string.format("Map %s is missing an animated textures table, add an empty [\"anim_tex\"]={} if not needed", name) end

	for i,info in pairs(anim_tex) do
		local texs  = info.textures
		local seq   = info.sequence
		local delay = info.delay
		if not texs then
			return string.format("Map %s animated texture %s is missing a texture list", name, tostring(i)) end
		if not seq then
			return string.format("Map %s animated texture %s is missing a sequence definition", name, tostring(i)) end
		if not delay then
			return string.format("Map %s animated texture %s is missing the delay parameter", name, tostring(i)) end
	end

	local skybox = map.skybox
	if not skybox then
		return string.format("Map %s is missing a skybox table", name) end

	return nil
end
