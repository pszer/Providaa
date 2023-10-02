--
-- map exporting function
-- MapEditExport() returns result,log
--
-- result is the serialized data of the map ready to be saved to a file, log is a table
-- of strings that gives info about anything malformed within the map
--

local function MapEditExport(props, name, settings)

	local settings = settings or {}
	local save_groups = settings.save_groups
	local newlines = settings.newlines

	local __log = {}
	local function Log(str)
		table.insert(__log, str)
	end

	local serializeTable = require 'serialise'

	local w = props.mapedit_map_width
	local h = props.mapedit_map_height

	local tile_set = {}
	local tex_to_tile_set = {}

	local wall_set = {}
	local tex_to_wall_set = {}

	local height_map = props.mapedit_tile_heights
	local tile_map = {}
	local wall_map = {}

	local anim_tex = props.mapedit_anim_tex

	for z=1,h do
		tile_map[z] = {}
		wall_map[z] = {}
		for x=1,w do
			wall_map[z][x] = {nil,nil,nil,nil}
		end
	end

	local models = {}
	local groups = {}

	-- generate model and group info
	--
	local model_to_index_map = {}
	for i,model in ipairs(props.mapedit_model_insts) do
		model_to_index_map[model]=i

		local model_fname = model.props.model_i_reference.props.model_name
		-- all models in the editor use a model matrix instead of pos,rot,scale components
		local __matrix = model.props.model_i_matrix
		local matrix = {}
		for i=1,16 do
			matrix[i]=__matrix[i]
		end

		local model_entry = {
			name = model_fname,
			matrix = matrix,
		}
		models[i] = model_entry
	end

	if save_groups then
		for i,group in ipairs(props.mapedit_model_groups) do
			local count = #group.insts
			if count > 0 then
				local group_entry = {
					name = group.name,
					insts = {}
				}

				for i,v in ipairs(group.insts) do
					local model_i = model_to_index_map[v]
					if model_i then
						table.insert(group_entry.insts, model_i)
					else
						Log(string.format("MapExport: group %s contains non-existance model instance, ignoring", tostring(group.name)))
					end
				end

				table.insert(groups, group_entry)
			else
				Log(string.format("MapExport: empty group %s found, ignoring", tostring(group.name)))
			end
		end
	end
	--
	-- generate model and group info finished

	--
	-- generate tile and wall set
	for i,v in ipairs(props.mapedit_texture_list) do
		local fname = v[1]
		if not v[2] then
			Log(string.format("MapExport: texture %s found, has no actual texture info? ignoring.", tostring(fname)))
		elseif not fname then
			Log(string.format("MapExport: texture at index %d  has no texture filename? ignoring.", i))
		else
			tile_set[i] = fname
			tex_to_tile_set[fname] = i
			wall_set[i] = fname
			tex_to_wall_set[fname] = i
		end
	end

	--
	-- fill out tile_map and wall_map
	local tile_texs = props.mapedit_tile_textures
	local wall_texs = props.mapedit_wall_textures
	for z=1,h do
		for x=1,w do
			local t_tex = tile_texs[z][x]
			if t_tex then
				if type(t_tex) ~= "table" then
					local id = tex_to_tile_set[t_tex]
					tile_map[z][x] = id
					if not id then
						tile_map[z][x] = {1,1}
						Log(string.format("MapExport: tile (%d,%d) uses texture outside of texture list. Defaulting to tile_set[1]",x,z))
					end
				else
					local id1 = t_tex[1] and tex_to_tile_set[t_tex[1]]
					local id2 = t_tex[2] and tex_to_tile_set[t_tex[2]]
					tile_map[z][x] = {id1,id2}
					if not id1 or not id2 then
						tile_map[z][x] = {1,1}
						Log(string.format("MapExport: tile (%d,%d) uses texture outside of texture list. Defaulting to tile_set[1]",x,z))
					end
				end
			else
				tile_map[z][x] = {1,1}
				Log(string.format("MapExport: tile (%d,%d) untextured.",x,z))
			end

			local w_tex = wall_texs[z][x]
			local w_tex_type = type(w_tex)
			if w_tex_type=="string" then
				local id = tex_to_wall_set[w_tex]
				if not id then
					wall_map[z][x] = {1,1,1,1,1}
					Log(string.format("MapExport: wall (%d,%d) uses texture outside of texture list (%s). Defaulting to wall_set[1]",x,z,tostring(w_tex)))
				end
			elseif w_tex_type=="table" then
				for i=1,5 do
					local w_tex = w_tex[i]
					if w_tex then
						local id = tex_to_wall_set[w_tex]
						if not id then
							wall_map[z][x][i] = 1
							local __side={"west","south","east","north"}
							Log(string.format("MapExport: wall (%d,%d,%d(%s)) uses texture outside of texture list (%s). Defaulting to wall_set[1]",
							 x,z,i,__side[i],tostring(w_tex)))
						else
							wall_map[z][x][i] = id
						end
					end
				end
			elseif w_tex ~= nil then
				Log(string.format("MapExport: wall (%d,%d) texture is a malformed data type? Defaulting to wall_set[1]",x,z,i,__side[i]))
			end
		end
	end

	local skybox = props.mapedit_skybox

	local MAP = {
		name = name,
		width = props.mapedit_map_width,
		height = props.mapedit_map_height,
		tile_set = tile_set,
		wall_set = wall_set,
		anim_tex = anim_tex,
		height_map = height_map,
		tile_map = tile_map,
		wall_map = wall_map,
		models = models,
		groups = groups,
		skybox = skybox
	}

	local result = "return "..serializeTable(MAP, nil, not newlines)
	return result, __log
end

return MapEditExport
