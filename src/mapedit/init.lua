require "props/mapeditprops"

require "map"
require "camera"
require "render"
require "angle"
require "assetloader"
require "tile"

local maptransform = require "mapedit.transform"

local shadersend   = require "shadersend"
local cpml         = require "cpml"
local transobj     = require "transobj"

local gui         = require 'mapedit.gui'
local guirender   = require 'mapedit.guidraw'
local commands    = require 'mapedit.command'
local lang        = require 'mapedit.guilang'

local export_map  = require 'mapedit.export'
local model_thumb = require 'modelthumbnail'

local mapdecal = require 'mapdecal'

ProvMapEdit = {

	props = nil,

	map_edit_shader = nil,
	tex_preview_shader = nil,

	viewport_input = nil,
	transform_input = nil,

	view_rotate_mode = false,
	grabbed_mouse_x = 0,
	grabbed_mouse_y = 0,

	-- table of command definitions
	commands = {},

	wireframe_col = {19/255,66/255,72/255,0.8},
	selection_col = {255/255,161/255,66/255,1.0},
	mesh_trans_col = {255/255,224/255,194/255,0.8},

	decal_box_col     = {19/255,66/255,72/255,1.0},
	decal_box_sel_col = {255/255,161/255,66/255,1.0},

	active_selection = {},
	highlight_mesh = nil,

	active_transform = nil,
	active_transform_tile_mat_a = nil,
	active_transform_model_mat_a = nil,
	granulate_transform = false,

	-- if non-nil, the camera will fly over to cam_move_to_pos coordinate
	-- and rotate its direction to cam_rot_to_dir
	cam_move_to_pos = nil,
	--cam_rot_to_dir  = nil -- not implemented
	
	__cache_selection_centre = nil,
	__cache_selection_min = nil,
	__cache_selection_max = nil,
	__cache_recalc_selection_centre = false,

	__object_painted = nil,
	__object_painted_time = 0,

	selection_changed = false,

	rotate_cam_around_selection = false,
	rotate_cam_point = nil,

	super_modifier = false,
	ctrl_modifier  = false,
	alt_modifier   = false,

	curr_context_menu = nil,
	curr_popup = nil,

	clipboard = {},

	tilevertex_objs = {},
	wall_objs = {},

	file_dropped_hook = nil
}
ProvMapEdit.__index = ProvMapEdit

function ProvMapEdit:load(args)
	SET_ACTIVE_KEYBINDS(MAPEDIT_KEY_SETTINGS)
	if not self.map_edit_shader then
		self.map_edit_shader = love.graphics.newShader("shader/mapedit.glsl") end
	if not self.tex_preview_shader then
		self.tex_preview_shader = love.graphics.newShader("shader/texpreview.glsl") end

	maptransform.positionAtCursor = function(tests) return function(x,y) ProvMapEdit:positionAtCursor(x,y,tests) end end
	
	local lvledit_arg = args["lvledit"]
	assert(lvledit_arg and lvledit_arg[1], "ProvMapEdit:load(): no level specified in lvledit launch argument")

	self.props = MapEditPropPrototype()

	self:loadConfig()

	local map_name = lvledit_arg[1]
	self:loadMap(map_name)

	self:newCamera()
	self:setupInputHandling()
	self:enterViewportMode()
	self:defineCommands()
	gui:init(self)
	self:loadNito()

	local quat = cpml.quat.from_angle_axis(math.pi/4.0,0,-1,0)
	quat = quat * cpml.quat.from_angle_axis(math.pi/2.0,1,0,0)

	local testdecal = mapdecal:new(
		Loader:getTextureReference("uv.png"),"uv.png",{40*TILE_SIZE,1*TILE_HEIGHT,61*TILE_SIZE},{80,80,80},0.0*math.pi/4,{0,-1,0})
	testdecal:generateVerts(self.props.mapedit_map_mesh.verts,
	                        self.props.mapedit_map_width,
	                        self.props.mapedit_map_height,
	                        self.props.mapedit_map_mesh.tile_vert_map,nil
													)
	testdecal:generateMesh()

	local d_obj = self:makeDecalObject(testdecal)
	self:addDecal(d_obj)
end

function ProvMapEdit:quit()
	self:saveConfig()
end

function ProvMapEdit:loadNito()
	self.nito_model = Model:fromLoader("mapedit/nito.iqm")
	self.nito = ModelInstance:newInstance(self.nito_model,{["model_i_contour_flag"]=true,["model_i_static"]=false})
	local a1 = self.nito:getAnimator()
	self.nito.props.model_i_animator_interp=0.0

	self.nito_anim_push = a1:getAnimationByName("Push")
	self.nito_anim_paint = a1:getAnimationByName("Painting")

	a1:playAnimationByName("Push")
	a1:stopAnimation()
end

function ProvMapEdit:unload()
	CONTROL_LOCK.MAPEDIT_VIEW.close()
	CONTROL_LOCK.MAPEDIT_TRANSFORM.close()
end

function ProvMapEdit:loadConfig(conf_fpath)
	local fpath = conf_fpath or "mapeditcfg.lua"

	local file = love.filesystem.newFile(fpath)
	if not file then return end

	local conf_str = file:read()
	local status, conf = pcall(function() return loadstring(conf_str)() end)
	if status and conf then
		local lang_setting = conf.lang_setting
		lang:setLanguage(lang_setting)
	end
	file:close()
end

function ProvMapEdit:saveConfig(conf_fpath)
	local fpath = conf_fpath or "mapeditcfg.lua"

	local file = love.filesystem.newFile(fpath)
	if not file then return end

	local status, err = file:open("w")
	if not status then
		print(err)
		return
	end

	local conf_table = {
		lang_setting = lang.__curr_lang
	}
	local serialise = require 'serialise'
	local str = "return "..serialise(conf_table)
	file:write(str)
	file:close()
end

function ProvMapEdit:loadMap(map_name)
	local dir = love.filesystem.getSource()
	local fullpath = dir .. Map.__dir .. map_name
	local status, err = pcall(function() return dofile(fullpath) end)
	local map_file = nil

	if not status then
		error(string.format("ProvMapEdit:load(): [%s] %s", fullpath, tostring(err)))
	else
		map_file = err
		print(string.format("ProvMapEdit:load(): loading %s", fullpath))
	end

	local map_mesh = Map.generateMapMesh( map_file ,
		{ dont_optimise=true, dont_gen_simple=true , gen_all_verts = true, gen_nil_texture = "nil.png", gen_index_map = true,
		  gen_newvert_buffer = true, keep_textures=true, gen_whole_overlay=true, dont_gen_decals=true } )
	if map_mesh then
		self.props.mapedit_map_mesh = map_mesh
	else
		error(string.format("ProvMapEdit:load(): %s failed to load", fullpath))
	end
	self:generateMeshHighlightAttributes()
	self:attachHighlightMesh()

	local textures = {}
	local tex_names = map_mesh.texture_names
	for i,v in ipairs(map_mesh.textures) do
		local entry = {
			tex_names[i],
			v
		}
		textures[i] = entry
		textures[entry[1]] = i
	end
	self.props.mapedit_texture_list = textures

	local skybox_img, skybox_fname, skybox_brightness = Map.generateSkybox( map_file )
	if skybox_img then
		self.props.mapedit_skybox_img = skybox_img
	end

	local models, model_set, models_ordered = Map.generateModelInstances( map_file, true )
	self.props.mapedit_model_insts = models
	self:updateModelMatrices()
	for _,v in ipairs(model_set) do
		self:addModelToList(v)
	end

	local decals, decal_textures = Map.internalGenerateDecalsDynamic( map_file, map_mesh.verts, map_mesh.tile_vert_map, map_mesh.wall_vert_map )
	for i,v in ipairs(decals) do
		local obj = self:makeDecalObject(v)
		self:addDecal(obj)
	end
	for i,v in ipairs(decal_textures) do
		self:addTexture(v[1], v[2])
	end

	self:copyPropsFromMap(map_file)
	self:allocateObjects()

	Map.loadGroups(
		map_file,
		--models,
		models_ordered,
		function(name,insts)
			self:createModelGroup(name,insts)
		end
	)
	for i,v in ipairs(self.props.mapedit_model_groups) do
		v:calcMinMax()
	end
end

function ProvMapEdit:reloadSkybox()
	local skybox_img, skybox_fname, skybox_brightness = Map.__generateSkybox( self.props.mapedit_skybox )
	if skybox_img then
		self.props.mapedit_skybox_img = skybox_img
	else
		error("ProvMapEdit:reloadSkybox(): fail")
	end
end

function ProvMapEdit:addModelToList(model)
	assert_type(model,"model")
	local thumbnail = model_thumb(model)
	local list = self.props.mapedit_model_list
	local name = model.props.model_name
	table.insert(list,{name,thumbnail,model})
end
function ProvMapEdit:removeModelFromList(model)
	return false,false
end
local __tempvectt = cpml.vec3.new()
function ProvMapEdit:getPlaceModelFunctions()
	local grid = gui.model_grid
	local sel = grid:getGridSelectedObject()

	if not sel then return nil,nil end
	local model = sel[3]
	if not model then return nil,nil end

	local place_at_selection_func = nil
	local place_at_origin_func = nil

	--local tile_s,wall_s,model_s= self:getObjectTypesInSelection()
	--local exists = self:getObjectTypesInSelection()
	--local place_at_grid_flag = (exists.tile or exists.wall) and (not exists.model)
	local place_at_grid_flag = self:objectTypesSelectedLimit{"tile","wall"}
	
	if place_at_grid_flag then
		place_at_selection_func = function ()
			local centre = self:getSelectionCentreAndMinMax()
			local mat = cpml.mat4.new()
			local t = __tempvectt
			t.x=centre[1]
			t.y=centre[2]
			t.z=centre[3]
			mat:translate(mat,t)

			local inst = ModelInstance:newInstance(model, {model_i_transformation_mode="matrix", model_i_matrix=mat})
			self:commitComposedCommand(
			 {"deselect_all", {}},
			 {"add_obj", {objects={inst}}},
			 {"additive_select", {select_objects = {{"model",inst}} }}
			)
			self:centreCamOnSelection()
		end
	end

	place_at_origin_func = function ()
			local mat = cpml.mat4.new()
			local inst = ModelInstance:newInstance(model, {model_i_matrix=mat})
			self:commitComposedCommand(
			 {"deselect_all", {}},
			 {"add_obj", {objects={inst}}},
			 {"additive_select", {select_objects = {{"model",inst}} }}
			)
			self:centreCamOnSelection()
	end

	return place_at_selection_func, place_at_origin_func
end

function ProvMapEdit:addDecal(decal_obj)
	assert_type(decal_obj, "decalobj")
	table.insert(self.props.mapedit_decals, decal_obj)
end
function ProvMapEdit:removeDecal(decal_obj)
	for i,v in ipairs(self.props.mapedit_decals) do
		if v==decal_obj then
			table.remove(self.props.mapedit_decals, i)
			return
		end
	end
end

local __decalobj_mt = {
	__type = "decalobj",
	getPosition = function(self)
		return self.decal.pos end,
	getDirection = function(self)
		local n = self.decal.normal
		local t = {n[1],n[2],n[3],self.decal.rotation}
		return t end,
	getRotation = function(self)
		return self.decal.rotation end,
	getScale = function(self)
		return self.decal.size end,

	updateMesh = function(self)
		self.decal:generateVerts(ProvMapEdit.props.mapedit_map_mesh.verts,
		                         ProvMapEdit.props.mapedit_map_width,
		                         ProvMapEdit.props.mapedit_map_height,
		                         ProvMapEdit.props.mapedit_map_mesh.tile_vert_map,
														 ProvMapEdit.props.mapedit_map_mesh.wall_vert_map, nil)
		self.decal:generateMesh()
		self:updateSelectBox()
	end,
	setPosition = function(self, pos)
		self.decal.pos = pos
		self:updateMesh()
		end,
	setDirection = function(self, dir)
		self.decal.normal[1] = dir[1]
		self.decal.normal[2] = dir[2]
		self.decal.normal[3] = dir[3]
		self.decal.rotation = dir[4]
		self:updateMesh()
		end,
	setRotation = function(self, rot)
		print(self.decal.rotation, rot)
		self.decal.rotation = rot
		self:updateMesh()
	end,
	setScale = function(self, scale)
		self.decal.size[1] = scale[1]
		self.decal.size[2] = scale[2]
		self.decal.size[3] = scale[3]
		self:updateMesh()
		end,

	updateSelectBox = function(self)
		local pos = self:getPosition()
		self.box_pos[1]=pos[1]-2
		self.box_pos[2]=pos[2]-2
		self.box_pos[3]=pos[3]-2
	end
}
__decalobj_mt.__index = __decalobj_mt
function ProvMapEdit:makeDecalObject(decal)
	local this = {
		decal=decal,

		box_pos  = {decal.pos[1]-2,decal.pos[2]-2,decal.pos[3]-2},
		box_size = {4,4,4},
		box_col  = self.decal_box_col,
		box_border_col  = self.decal_box_sel_col,
	}
	setmetatable(this,__decalobj_mt)
	return this
end

function ProvMapEdit:removeDecal(decal)
	for i,v in ipairs(self.props.mapedit_decals) do
		if decal==v then
			table.remove(self.props.mapedit_decals,i)
			return
		end
	end
end

function ProvMapEdit:addTexture(tex_name, tex)
	assert_type(tex_name, "string")
	assert(tex)
	local entry = {tex_name, tex}
	local texs = self.props.mapedit_texture_list
	local count = #texs
	--table.insert(texs, entry)
	texs[count+1] = entry
	texs[tex_name] = count+1

	self:regenAtlas()
end

-- each entry is {texture_name, texture_data}
function ProvMapEdit:addTextures(tex_table)
	assert_type(tex_table, "table")
	for i,v in ipairs(tex_table) do
		assert_type(v[1], "string")
		assert(v2[2]:typeOf("Texture"))
		local entry = {v[1],v[2]}
		local texs = self.props.mapedit_texture_list
		local count = #texs
		texs[count+1] = entry
		texs[tex_name] = count+1
	end

	self:regenAtlas()
end

function ProvMapEdit:textureIsInAnimatedTexture(tex_name)
	for i,v in pairs(self.props.mapedit_anim_tex) do
		local texs = v.textures
		for i,v in ipairs(texs) do
			if v==tex_name then return true end
		end
	end
	return false
end

function ProvMapEdit:textureIsAppliedToMesh(tex_name)
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	for z=1,h do
		for x=1,w do
			local t_tex = self.props.mapedit_tile_textures[z][x]
			if t_tex == tex_name then return true end
			if type(t_tex)=="table" then
				if t_tex[1] == tex_name then return true end
				if t_tex[2] == tex_name then return true end
			end
			local w_tex = self.props.mapedit_wall_textures[z][x]
			if w_tex == tex_name then return true end
			if type(w_tex)=="table" then
				if w_tex[1] == tex_name then return true end
				if w_tex[2] == tex_name then return true end
				if w_tex[3] == tex_name then return true end
				if w_tex[4] == tex_name then return true end
				if w_tex[5] == tex_name then return true end
			end
		end
	end
	return false
end

-- returns true is texture removed, otherwise false,info_str
-- it can fail if the texture is not loaded,the
-- texture is part of an animated texture, or the texture
-- is currently applied to a tile,wall
function ProvMapEdit:removeTexture(tex_name)
	local is_in_anim = self:textureIsInAnimatedTexture(tex_name)
	if is_in_anim then return false, tex_name..lang[" is part of an animated texture, can't be deleted."] end
	local is_applied = self:textureIsAppliedToMesh(tex_name)
	if is_applied then return false, tex_name..lang[" is applied to the map mesh, can't be deleted."] end

	local texs = self.props.mapedit_texture_list
	if not texs[tex_name] then return end -- ignore if not loaded
	for i,v in ipairs(texs) do
		if v[1]==tex_name then
			Loader:deref("texture",tex_name)
			local count = #texs

			for j=i,count-1 do
				texs[j]=texs[j+1]
				local j_tex_name = texs[j][1]
				texs[j_tex_name]=j
			end
			texs[count] = nil
			texs[tex_name] = nil
			self:regenAtlas()
			return true
		end
	end

	return false
end

function ProvMapEdit:regenAtlas()
	local texatlas = require 'texatlas'

	local loaded_textures = self.props.mapedit_texture_list
	local map_mesh = self.props.mapedit_map_mesh
	local tex_table = {}
	for i,v in ipairs(loaded_textures) do
		tex_table[i] = v[2]
		tex_table[v[1]] = i
	end

	local atlas, uvs = texatlas(tex_table, CONSTS.ATLAS_SIZE, CONSTS.ATLAS_SIZE)

	if map_mesh.tex then map_mesh.tex:release(false) end
	map_mesh:setNewAtlasUvs(atlas, uvs)
	map_mesh:reloadAnimDefinitions(self.props.mapedit_anim_tex, tex_table)

	self:fixAllTileTextures()
	self:fixAllWallTextures()
end

function ProvMapEdit:copyPropsFromMap(map_file)
	local function clone(dest, t, clone)
		for i,v in pairs(t) do
			local type = type(v)
			if provtype ~= "table" then
				dest[i] = v
			else
				dest[i] = {}
				clone(dest[i], v, clone)
			end
		end
		return dest
	end

	local props = self.props
	props.mapedit_map_width  = map_file.width
	props.mapedit_map_height = map_file.height
	
	clone(props.mapedit_models, map_file.models)
	clone(props.mapedit_tileset, map_file.tile_set)
	clone(props.mapedit_wallset, map_file.wall_set)
	clone(props.mapedit_tile_heights, map_file.height_map)
	clone(props.mapedit_anim_tex, map_file.anim_tex)
	clone(props.mapedit_skybox, map_file.skybox)
	clone(props.mapedit_tile_shapes, map_file.tile_shape)

	clone(props.mapedit_tile_tex_offsets, map_file.tile_tex_offset)
	clone(props.mapedit_wall_tex_offsets, map_file.wall_tex_offset)
	clone(props.mapedit_tile_tex_scales, map_file.tile_tex_scale)
	clone(props.mapedit_wall_tex_scales, map_file.wall_tex_scale)
	clone(props.mapedit_overlay_tex_offsets, map_file.overlay_tile_offset)
	clone(props.mapedit_overlay_tex_scales, map_file.overlay_tile_scale)

	-- get the texture names for each of the tile and walls
	local t_tex = props.mapedit_tile_textures
	local w_tex = props.mapedit_wall_textures
	local o_tex = props.mapedit_overlay_textures
	for z=1,map_file.height do
		t_tex[z] = {}
		w_tex[z] = {}
		o_tex[z] = {}
		for x=1,map_file.width do
			w_tex[z][x] = {}

			local tile_id = map_file.tile_map[z][x]
			local wall_id = map_file.wall_map[z][x]
			local over_id = map_file.overlay_tile_map[z][x]

			if tile_id then
				if type(tile_id)=="table" then
					local tex1 = map_file.tile_set[tile_id[1]]
					local tex2 = map_file.tile_set[tile_id[2]]
					t_tex[z][x] = {tex1,tex2}
				else
					local tex = map_file.tile_set[tile_id]
					t_tex[z][x] = {tex,tex}
				end
			end

			if over_id then
				if type(over_id)=="table" then
					local tex1 = map_file.tile_set[over_id[1]]
					local tex2 = map_file.tile_set[over_id[2]]
					o_tex[z][x] = {tex1,tex2}
				else
					local tex = map_file.tile_set[over_id]
					o_tex[z][x] = {tex,tex}
				end
			end

			if wall_id then
				local info_type = type(wall_id)
				if info_type ~= "table" then
					local tex = map_file.wall_set[wall_id]
					w_tex[z][x][1] = tex
					w_tex[z][x][2] = tex
					w_tex[z][x][3] = tex
					w_tex[z][x][4] = tex
					w_tex[z][x][5] = tex
				else
					local wall_id_table = wall_id
					for i=1,5 do
						local wall_id = wall_id_table[i]
						if wall_id then
							local tex = map_file.wall_set[wall_id]
							w_tex[z][x][i] = tex
						end
					end
				end
			end
		end
	end
end

function ProvMapEdit:allocateObjects()
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	for z=1,h do
		self.tilevertex_objs[z]={}
		self.wall_objs[z] = {}
		for x=1,w do
			self.tilevertex_objs[z][x]={}
			self.wall_objs[z][x]={}
			for i=1,6 do
				self.tilevertex_objs[z][x][i]           = self:getTileVertexObject(x,z,i)
				self.tilevertex_objs[z][x][i].__overlay = self:getTileVertexObject(x,z,i,true)
			end
			for i=1,5 do
				self.wall_objs[z][x][i]=self:getWallObject(x,z,i)
			end
		end
	end
end

function ProvMapEdit:defineCommands()
	coms = self.commands

	coms["invertible_select"] = commands:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable{}},
		},
		function(props) -- command function
			self.selection_changed = true
			local mapedit = self
			local active_selection = mapedit.active_selection
			local skip = {}

			-- first we inverse the selection if already selected
			for i,v in ipairs(props.select_objects) do
				for j,u in ipairs(active_selection) do
					if v[2] == u[2] then
						skip[i] = true
						table.remove(active_selection, j)
						self:highlightObject(v,0.0)
						break
					end
				end
			end

			for i,v in ipairs(props.select_objects) do
				if not skip[i] then
					local unique = true
					for j,u in ipairs(active_selection) do
						if v[2] == u[2] then
							unique = false
							break
						end
					end

					if unique then
						table.insert(active_selection, v)
						self:highlightObject(v,1.0)
					end
				end
			end
		end, -- command function

		function(props) -- undo command function
			self.selection_changed = true
			local mapedit = self
			local active_selection = mapedit.active_selection
			local skip = {}

			-- invert any previous invert selections
			for i,v in ipairs(props.select_objects) do
				local unique = true
				for j,u in ipairs(active_selection) do
					if v == u then
						unique = false
						break
					end
				end

				if unique then
					skip[i] = true
					table.insert(active_selection, v)
					self:highlightObject(v,1.0)
				end
			end

			for i,v in ipairs(props.select_objects) do
				if not skip[i] then
					for j,u in ipairs(active_selection) do
						if v == u then
							table.remove(active_selection, j)
							self:highlightObject(v,0.0)
							break
						end
					end
				end
			end -- undo command function
		end) 

	coms["additive_select"] = commands:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable{}},
		 {"first_pass", "boolean", true, nil} -- first time this command is invoked, we remove any already selected objects from select_objects
		},
		function(props) -- command function
			self.selection_changed = true
			local mapedit = self
			local active_selection = mapedit.active_selection

			if props.first_pass then
				-- remove already selected objects from the additive select
				local lookup = {}
				for i,v in ipairs(active_selection) do
					lookup[v[2]] = true
				end

				local obj_count = #props.select_objects
				for i=obj_count,1,-1 do
					local obj = props.select_objects[i][2]
					if lookup[obj] then
						table.remove(props.select_objects, i)
					end
				end
			end

			local obj_count = #props.select_objects
			for i=obj_count,1,-1 do
				v = props.select_objects[i]

				table.insert(active_selection, v)
				self:highlightObject(v,1.0)
			end

			props.first_pass = false
		end, -- command function

		function(props) -- undo command function
			self.selection_changed = true
			local mapedit = self
			local active_selection = mapedit.active_selection
			for i,v in ipairs(props.select_objects) do
				for j,u in ipairs(active_selection) do
					if v[2] == u[2] then
						table.remove(active_selection, j)
						self:highlightObject(v,0.0)
						break
					end
				end
			end -- undo command function
		end)

	coms["deselect_all"] = commands:define(
		{
		 {"past_selection", "table", nil, PropDefaultTable(self.active_selection)},
		 {"memory", "table", nil, PropDefaultTable{}}
		},
		function(props) -- command function
			self.selection_changed = true
			local mapedit = self
			if props.memory[1] == nil then
				for i,v in ipairs(mapedit.active_selection) do
					table.insert(props.memory, v)
				end
			end

			for i=#mapedit.active_selection,1,-1 do
				self:highlightObject(mapedit.active_selection[i], 0.0)
				table.remove(mapedit.active_selection, i)
			end
		end, -- command function

		function(props) -- undo command function
			self.selection_changed = true
			local mapedit = self
			for i,v in ipairs(props.memory) do
				self:highlightObject(v, 1.0)
				table.insert(mapedit.active_selection, i, v)
			end
		end -- undo command function
		)

	coms["delete_obj"] = commands:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable(self.active_selection)},
		 {"groups_memory", nil, nil, nil},
		},
		function (props) -- command function
			if props.groups_memory == nil then
				props.groups_memory = {}
				for i,v in ipairs(props.select_objects) do
					local obj_type = v[1]
					if obj_type == "model" then
						local g = self:isModelInAGroup(v[2])
						if g then
							props.groups_memory[i] = g
						end
					end
				end
			end

			local insts = {}
			for i,v in ipairs(props.select_objects) do
				local obj_type = v[1]
				if obj_type == "model" then
					local inst = v[2]
					table.insert(insts, inst)
				else
					--error()
				end
			end
			-- collecting the models into a table first to 
			-- pass into removeModel should be more efficient for
			-- large delete operations
			self:removeModelInstance(insts)
			self:dissolveEmptyGroups()
		end, -- command function
		function (props) -- undo command function
			local insts = {}
			for i,v in ipairs(props.select_objects) do
				local obj_type = v[1]
				if obj_type == "model" then
					local inst = v[2]
					table.insert(insts, inst)

					local group = props.groups_memory[i]
					if group then
						group:addToGroup(v[2])
						self:addModelGroup(group)
					end
				else
					--error()
				end
			end

			self:addModelInstance(insts)
		end -- undo command function
	)

	coms["add_obj"] = commands:define(
		{
		 {"objects", "table", nil, PropDefaultTable{}},
		},
		function (props) -- command function
			self:addModelInstance(props.objects)
		end, -- command function
		function (props) -- undo command function
			self:removeModelInstance(props.objects)
		end -- undo command function
	)
 
	local function add_to_set(set, g)
		for i,v in ipairs(set) do
			if v==g then return end
		end
		table.insert(set, g)
	end

	coms["transform"] = commands:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable(self.active_selection)},
		 {"transform_info", nil, nil, nil},
		 {"memory", "table", nil, PropDefaultTable{}},
		 {"memory_to", "table", nil, PropDefaultTable{}},
		 {"transform_function", nil, nil, nil}
		},
		function(props) -- command function
			local groups = {}
			local calc_mem = props.memory[1] == nil
			local calc_trans = props.memory_to[1] == nil
			for i,v in ipairs(props.select_objects) do
				if calc_mem then -- if memory hasn't been calculated yet
					props.memory[i] = transobj:from(v[2])
				end
			
				local o_type = v[1]
				if o_type == "model" then -- remember any groups models are in, their bounding box has to be updated
					local g = self:isModelInAGroup(v[2])
					if g then add_to_set(groups,g) end
				end
			end

			if calc_trans then
				if not props.transform_function then
					--props.transform_function = self:applyActiveTransformationFunction(props.select_objects)
					props.transform_function = self:applyTransformationFunction(props.select_objects, props.transform_info)
				end
				props.transform_function()

				for i,v in ipairs(props.select_objects) do
					props.memory_to[i] = transobj:from(v[2])
				end
			else
				for i,v in ipairs(props.select_objects) do
					local memory_to = props.memory_to[i]
					memory_to:send(v[2])
					--props.memory_to[i] = transobj:from(v[2])
				end
			end

			self:updateModelMatrices()

			for i,g in ipairs(groups) do
				g:calcMinMax()
			end
			self:updateSelectedTileWalls(props.select_objects)
		end, -- command function
		function(props) -- undo command function
			local groups = {}
			for i,v in ipairs(props.select_objects) do
				local o_type = v[1]
				local memory = props.memory[i]
				memory:send(v[2])
				if o_type == "model" then
					local g = self:isModelInAGroup(v[2])
					if g then add_to_set(groups,g) end
				end
			end

			self:updateModelMatrices()
			for i,g in ipairs(groups) do
				g:calcMinMax()
			end
			self:updateSelectedTileWalls(props.select_objects)
		end -- undo command function
	)

	coms["create_group"] = commands:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable(self.active_selection)},
		 {"created_group", nil, nil, nil}
		},
		function(props) -- command function
			local models = {}
			for i,v in ipairs(props.select_objects) do
				if v[1] == "model" then table.insert(models, v[2]) end
			end
			props.created_group = self:createModelGroup(nil,models)
		end, -- command function
		function(props) -- undo command function
			self:dissolveGroup(props.created_group)
		end -- undo command function
	)

	coms["add_to_group"] = commands:define(
		{
		 {"models", "table", nil, PropDefaultTable{}},
		 {"group", "table", nil, nil}
		},
		function(props) -- command function
			for i,v in ipairs(props.models) do
				props.group:addToGroup(v)
			end
			props.group:calcMinMax()
		end, -- command function
		function(props) -- undo command function
			for i,v in ipairs(props.models) do
				props.group:removeFromGroup(v)
			end
			props.group:calcMinMax()
		end -- undo command function
	)

	coms["dissolve_groups"] = commands:define(
		{
		 {"groups", nil, nil, PropDefaultTable{}}
		},
		function(props) -- command function
			for i,v in ipairs(props.groups) do
				self:dissolveGroup(v)
			end
		end, -- command function
		function(props) -- undo command function
			for i,v in ipairs(props.groups) do
				self:addModelGroup(v)
			end
		end -- undo command function
	)

	coms["merge_groups"] = commands:define(
		{
		 {"groups", "table", nil, PropDefaultTable{}},
		 {"merged_group", nil, nil, nil}
		},
		function(props) -- command function
			if props.merged_group == nil then
				props.merged_group = self:mergeGroups(unpack(props.groups))
			end
			self:addModelGroup(props.merged_group)
		end, -- command function
		function(props) -- undo command function
			self:dissolveGroup(props.merged_group)
			for i,group in ipairs(props.groups) do
				self:addModelGroup(group)
			end
		end -- undo command function
	)

	coms["reset_transformation"] = commands:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable{self.active_selection}},
		 {"memory", nil, nil, PropDefaultTable{}}
		},
		function(props) -- command function
			local calc = props.memory[1]==nil
			for i,v in ipairs(props.select_objects) do
				if v[1] == "model" or v[1] == "decal" then
					if calc then
						props.memory[i] = transobj:from(v[2]) end
					local reset = transobj:from(v[2])
					reset:reset()
					reset:send(v[2])
				end
			end
		end, -- command function
		function(props) -- undo command function
			for i,v in ipairs(props.select_objects) do
				if v[1] == "model" or v[1] == "decal" then
					local old_trans = props.memory[i]
					old_trans:send(v[2])
				end
			end
		end -- undo command function
	)

	coms["change_texture"] = commands:define(
		{
			{"objects", "table", nil, nil},
			{"previous_textures", "table", nil, nil},
			{"new_textures", "table", nil, nil},
		},
		function(props) -- command function
			local new = props.new_textures
			for i,v in ipairs(props.objects) do
				self:setObjectTexture(v,new[i])
			end
		end, -- command function
		function(props) -- undo command function
			local prev = props.previous_textures
			for i,v in ipairs(props.objects) do
				self:setObjectTexture(v,prev[i])
			end
		end -- undo command function
	)

	coms["change_texture_attributes"] = commands:define(
		{
			{"objects","table",nil,nil},
			{"offsets","table",nil,nil},
			{"scales","table",nil,nil},
			{"offset_memory" ,"table",nil,PropDefaultTable{}},
			{"scale_memory" ,"table",nil,PropDefaultTable{}},
		},
		function(props) -- command function
			for i,v in ipairs(props.objects) do
				if not props.offset_memory[i] then
					local offset, scale = ProvMapEdit:getTexOffset(v),
					                      ProvMapEdit:getTexScale(v)
					props.offset_memory[i] = {offset[1],offset[2]}
					props.scale_memory[i] = {scale[1] ,scale[2]}
				end
			end

			for i,v in ipairs(props.objects) do
				local off,scale = props.offsets[i], props.scales[i]
				if off then self:setTexOffset(v,off) end
				if scale then self:setTexScale(v,scale) end
			end
		end, -- command function
		function(props) -- undo command function
			for i,v in ipairs(props.objects) do
				local off,scale = props.offset_memory[i], props.scale_memory[i]
				if off then self:setTexOffset(v,off) end
				if scale then self:setTexScale(v,scale) end
			end
		end -- undo command function
	)

	--[[coms["flip_decals"] = commands:define(
		{
			{"decals","table",nil,nil},
			{"flip_mem","table",nil,PropDefaultTable{}},
			{"flip_xy","string","x",PropIsOneOf{"x","y","X","Y"}},
		},
		function(props) -- command function
			for i,v in ipairs(decals) do
				
			end
		end, -- command function
		function(props) -- command function
		end -- command function
	)--]]

end

function ProvMapEdit:commitCommand(command_name, props)
	local command_table = self.commands
	local command_definition = command_table[command_name]
	assert(command_definition, string.format("No command %s defined", tostring(command_name)))
	local command = command_definition:new(props)
	assert(command)

	local pointer = self.props.mapedit_command_pointer
	local command_history = self.props.mapedit_command_stack
	local history_length = #command_history
	-- if the command pointer isn'at the top of the stack (i.e. there have been undo operations)
	-- we prune any commands after it
	local pruned=false
	for i=pointer+1,history_length do
		pruned=true
		command_history[i] = nil
	end
	if pruned then collectgarbage("step",5000) end

	table.insert(command_history, command)

	-- add the new command to the stack, shifting it down if maximum limit of
	-- remembered commands is reached
	history_length = #command_history
	if history_length > self.props.mapedit_command_stack_max then
		for i=1,history_length-1 do
			command_history[i] = command_history[i+1]
		end
		command_history[history_length] = nil
		self.props.mapedit_command_pointer = history_length
	else
		self.props.mapedit_command_pointer = history_length
	end

	command:commit()
end

function ProvMapEdit:pushCommand(command)
	local pointer = self.props.mapedit_command_pointer
	local command_history = self.props.mapedit_command_stack
	local history_length = #command_history
	-- if the command pointer isn'at the top of the stack (i.e. there have been undo operations)
	-- we prune any commands after it
	local pruned=false
	for i=pointer+1,history_length do
		pruned=true
		command_history[i] = nil
	end
	if pruned then collectgarbage("step",5000) end

	table.insert(command_history, command)

	-- add the new command to the stack, shifting it down if maximum limit of
	-- remembered commands is reached
	history_length = #command_history
	if history_length > self.props.mapedit_command_stack_max then
		for i=1,history_length-1 do
			command_history[i] = command_history[i+1]
		end
		command_history[history_length] = nil
		self.props.mapedit_command_pointer = history_length
	else
		self.props.mapedit_command_pointer = history_length
	end

	command:commit()
end

function ProvMapEdit:commitComposedCommand(...)
	local com_args = {...}
	local coms = {}

	local command_table = self.commands
	for i,v in ipairs(com_args) do
		local command_definition = command_table[v[1]]
		assert(command_definition, string.format("No command %s defined", tostring(v[1])))
		local command = command_definition:new(v[2])
		coms[i] = command
	end

	local composed = commands:compose(coms)
	self:pushCommand(composed)
end

function ProvMapEdit:commitUndo()
	local pointer = self.props.mapedit_command_pointer
	local command_history = self.props.mapedit_command_stack

	if pointer == 0 then return end
	local command = command_history[pointer]
	command:undo()
	self.props.mapedit_command_pointer = self.props.mapedit_command_pointer - 1
end

function ProvMapEdit:commitRedo()
	local pointer = self.props.mapedit_command_pointer
	local command_history = self.props.mapedit_command_stack
	local history_length = #command_history

	if pointer == history_length then return end
	local command = command_history[pointer+1]
	command:commit()
	self.props.mapedit_command_pointer = self.props.mapedit_command_pointer + 1
end

function ProvMapEdit:canUndo()
	return self.props.mapedit_command_pointer > 0
end
function ProvMapEdit:canRedo()
	return self.props.mapedit_command_pointer ~= #(self.props.mapedit_command_stack)
end

function ProvMapEdit:setupInputHandling()
	--
	-- CONTEXT MENU MODE INPUTS
	--
	--[[self.cxtm_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_CONTEXT,
	                                   {"cxtm_select","cxtm_scroll_up","cxtm_scroll_down"})

	local cxtm_select_option = Hook:new(function ()
		local cxtm = gui.curr_context_menu
		if not cxtm then
			gui:exitContextMenu()
			return end
		local hovered_opt = cxtm:getCurrentlyHoveredOption()
		if not hovered_opt then
			gui:exitContextMenu()
			return end
		local action = hovered_opt.action
		if action then action() end
		gui:exitContextMenu()
	end)
	self.cxtm_input:getEvent("cxtm_select", "down"):addHook(cxtm_select_option)
	--]]

	--
	-- VIEWPORT MODE INPUTS
	--
	self.viewport_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_VIEW,
	                    {"cam_forward","cam_backward","cam_left","cam_right","cam_down","cam_up",
										   "cam_rotate","cam_reset","cam_centre","edit_select","edit_deselect","edit_undo","edit_redo",
										   "cam_zoom_in","cam_zoom_out","edit_cycle_tool", "edit_edit_tool", "edit_paint_tool", "edit_overlay_toggle",
										   {"super",CONTROL_LOCK.META},{"toggle_anim_tex",CONTROL_LOCK.META},{"ctrl",CONTROL_LOCK.META},{"alt",CONTROL_LOCK.META},
											 {"cycle_vision",CONTROL_LOCK.META},

										   "transform_move","transform_rotate","transform_scale"})

	local forward_v  = {0 , 0,-1}
	local backward_v = {0 , 0, 1}
	local left_v     = {-1, 0,0}
	local right_v    = { 1, 0,0}
	local up_v       = { 0,-1,0}
	local down_v     = { 0, 1,0}

	local function __move(dir_v, relative_mode)
		return function()
			local dt = love.timer.getDelta()
			local cam = self.props.mapedit_cam
			local dir
			if relative_mode then
				dir = {cam:getDirectionVector(dir_v)}
			else
				dir = dir_v
			end
			local speed = self.props.mapedit_cam_speed
			local campos = cam:getPosition()
			self.rotate_cam_around_selection = false
			cam:setPosition{
				campos[1] + dir[1] * dt * speed,
				campos[2] + dir[2] * dt * speed,
				campos[3] + dir[3] * dt * speed}
		end
	end

	-- hooks for moving the camera
	local viewport_move_forward = Hook:new(function ()__move(forward_v, true)() end)
	local viewport_move_backward = Hook:new(function ()__move(backward_v, true)() end)
	local viewport_move_left = Hook:new(function ()__move(left_v, true)() end)
	local viewport_move_right = Hook:new(function ()__move(right_v, true)() end)
	local viewport_move_up = Hook:new(function ()__move(up_v)() end)
	local viewport_move_down = Hook:new(function () __move(down_v)() end)
	self.viewport_input:getEvent("cam_forward","held"):addHook(viewport_move_forward)
	self.viewport_input:getEvent("cam_backward","held"):addHook(viewport_move_backward)
	self.viewport_input:getEvent("cam_left","held"):addHook(viewport_move_left)
	self.viewport_input:getEvent("cam_right","held"):addHook(viewport_move_right)
	self.viewport_input:getEvent("cam_up","held"):addHook(viewport_move_up)
	self.viewport_input:getEvent("cam_down","held"):addHook(viewport_move_down)

	-- hooks for camera rotation
	local viewport_rotate_start = Hook:new(function ()
		self.view_rotate_mode = true
		self:captureMouse()
		self.viewport_input:lockInverse{"cam_rotate","cam_forward","cam_backward","cam_left","cam_right","cam_up","cam_down"}
		CONTROL_LOCK.MAPEDIT_VIEW.elevate()
	end)
	local viewport_rotate_finish = Hook:new(function ()
		self.view_rotate_mode = false
		self:releaseMouse()
		self.viewport_input:unlockAll()
		CONTROL_LOCK.MAPEDIT_VIEW.open()
	end)
	self.viewport_input:getEvent("cam_rotate","down"):addHook(viewport_rotate_start)
	self.viewport_input:getEvent("cam_rotate","up"):addHook(viewport_rotate_finish)

	self.viewport_input:getEvent("cam_reset","down"):addHook(Hook:new(function()
		self:newCamera() end))
	self.viewport_input:getEvent("cam_centre","down"):addHook(Hook:new(function()
		self:centreCamOnSelection()
	end))

	local additive_select_obj = nil

	local __viewport_select_edit_tool = function()
		local x,y = love.mouse.getPosition()
		local obj = self:objectAtCursor( x,y , {tile=true,wall=true,model=true,decal=true})

		if not obj then self:deselectSelection() return end

		if not self.super_modifier then
			self:commitCommand("invertible_select", {select_objects={self:decomposeObject(obj)}})
			if obj[1] == "tile" then
				additive_select_obj = obj
			end
			return
		end

		if not additive_select_obj then
			if obj[1] == "tile" then
				additive_select_obj = obj
			else
				additive_select_obj = nil
			end
			self:commitCommand("additive_select", {select_objects={self:decomposeObject(obj)}})
			return
		end

		local x1,z1,x2,z2
		local min,max = math.min,math.max
		if obj[1] == "tile" then
			if self:isSelected(additive_select_obj) then
				x1 = min(obj[2].x, additive_select_obj[2].x)
				z1 = min(obj[2].z, additive_select_obj[2].z)
				x2 = max(obj[2].x, additive_select_obj[2].x)
				z2 = max(obj[2].z, additive_select_obj[2].z)

				local objs_in_range = {}
				for x=x1,x2 do
					for z=z1,z2 do
						local tile_shape = self:getTileShape(x,z)
						local overlay = self.props.mapedit_overlay_edit
						if tile_shape==0 then
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,1,overlay)})
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,2,overlay)})
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,3,overlay)})
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,4,overlay)})
						else
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,1,overlay)})
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,2,overlay)})
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,3,overlay)})
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,4,overlay)})
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,5,overlay)})
							table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,6,overlay)})
						end
					end
				end

				self:commitCommand("additive_select", {select_objects=objs_in_range})
				additive_select_obj = nil
				return
			end
			self:commitCommand("additive_select", {select_objects={self:decomposeObject(obj)}})
			return
		end

		additive_select_obj = nil
		self:commitCommand("additive_select", {select_objects={self:decomposeObject(obj)}})
	end

	local __viewport_select_paint_tool = function()
		local x,y = love.mouse.getPosition()
		local obj = self:objectAtCursor( x,y , {tile=true,wall=true})
		if not obj then return end

		local gui_texture_grid = gui.texture_grid
		local tex_select = gui_texture_grid:getGridSelectedObject()
		if not tex_select then return end
		local tex_name = tex_select[1]

		local obj_tex = self:getObjectTexture(obj)
		if obj_tex==tex_name then return end
		self:commitCommand("change_texture",
		{ ["objects"] = {obj},
		  ["previous_textures"] = {obj_tex},
			["new_textures"] = {tex_name}
		})
	end

	local viewport_select = Hook:new(function ()
		local tool = self.props.mapedit_tool
		if tool == "edit" then
			__viewport_select_edit_tool()
		elseif tool == "paint" then
			__viewport_select_paint_tool()
		end
	end)

	local held_limiter = periodicUpdate(4)
	local viewport_select_held = Hook:new(function ()
		if not held_limiter() then return end
		local tool = self.props.mapedit_tool
		if tool == "paint" then
			__viewport_select_paint_tool()
		end
	end)
	local viewport_deselect = Hook:new(function ()
		if not self:isSelectionEmpty() then
			self:viewportRightClickAction()
			--self:commitCommand("deselect_all", {})
		end
	end)
	self.viewport_input:getEvent("edit_select", "down"):addHook(viewport_select)
	self.viewport_input:getEvent("edit_select", "held"):addHook(viewport_select_held)
	self.viewport_input:getEvent("edit_deselect", "down"):addHook(viewport_deselect)

	local viewport_undo = Hook:new(function ()
		self:commitUndo() end)
	local viewport_redo = Hook:new(function ()
		self:commitRedo() end)

	local enable_super_hook = Hook:new(function () self.super_modifier = true end)
	local disable_super_hook = Hook:new(function () self.super_modifier = false end)

	local enable_ctrl_hook = Hook:new(function () self.ctrl_modifier = true end)
	local disable_ctrl_hook = Hook:new(function () self.ctrl_modifier = false end)

	local enable_alt_hook = Hook:new(function () self.alt_modifier = true end)
	local disable_alt_hook = Hook:new(function () self.alt_modifier = false end)

	local toggle_anim_tex = Hook:new(function ()
		self.props.mapedit_enable_tex_anim = not self.props.mapedit_enable_tex_anim end)
	local cycle_vision = Hook:new(function ()
		local cycle = {
			"default","normal","uv",}
		local i=1
		while i<=#cycle do
			if cycle[i]==self.props.mapedit_vision then break end
			i=i+1
		end
		i=((i+1)%#cycle)+1
		self.props.mapedit_vision=cycle[i] end)

	local __cycle = {
		["edit"]  = "paint",
		["paint"] = "edit",
	}
	local viewport_cycle_tool = Hook:new(function () self:cycleTool() end)
	local viewport_edit_tool  = Hook:new(function () self:cycleTool("edit") end)
	local viewport_paint_tool = Hook:new(function () self:cycleTool("paint") end)
	local viewport_overlay_toggle = Hook:new(function ()
		self.props.mapedit_overlay_edit = not self.props.mapedit_overlay_edit	
	end)


	self.viewport_input:getEvent("edit_undo","down"):addHook(viewport_undo)
	self.viewport_input:getEvent("edit_redo","down"):addHook(viewport_redo)
	self.viewport_input:getEvent("super", "down"):addHook(enable_super_hook)
	self.viewport_input:getEvent("super", "up"):addHook(disable_super_hook)
	self.viewport_input:getEvent("ctrl", "down"):addHook(enable_ctrl_hook)
	self.viewport_input:getEvent("ctrl", "up"):addHook(disable_ctrl_hook)
	self.viewport_input:getEvent("alt", "down"):addHook(enable_alt_hook)
	self.viewport_input:getEvent("alt", "up"):addHook(disable_alt_hook)
	self.viewport_input:getEvent("toggle_anim_tex", "up"):addHook(toggle_anim_tex)
	self.viewport_input:getEvent("cycle_vision", "up"):addHook(cycle_vision)
	self.viewport_input:getEvent("edit_cycle_tool", "down"):addHook(viewport_cycle_tool)
	self.viewport_input:getEvent("edit_edit_tool", "down"):addHook(viewport_edit_tool)
	self.viewport_input:getEvent("edit_paint_tool", "down"):addHook(viewport_paint_tool)
	self.viewport_input:getEvent("edit_overlay_toggle", "down"):addHook(viewport_overlay_toggle)

	-- 
	-- VIEWPORT MODE ----> TRANSFORM MODE INPUTS
	--
	local viewport_to_move = Hook:new(function ()
		self:enterTransformMode("translate")
		end)
	local viewport_to_rotate = Hook:new(function ()
		self:enterTransformMode("rotate")
		end)
	local viewport_to_scale = Hook:new(function ()
		self:enterTransformMode("scale")
		end)
	self.viewport_input:getEvent("transform_move", "down"):addHook(viewport_to_move)
	self.viewport_input:getEvent("transform_rotate", "down"):addHook(viewport_to_rotate)
	self.viewport_input:getEvent("transform_scale", "down"):addHook(viewport_to_scale)

	--
	-- TRANSFORM MODE INPUTS
	--
	self.transform_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_TRANSFORM,
	                                       {"transform_move", "transform_scale", "transform_rotate", "transform_cancel", "transform_commit",
										    "transform_x_axis", "transform_y_axis", "transform_z_axis"})
	local transform_commit = Hook:new(function ()
		if not self:selectionEmpty() then
			self:commitCommand("transform", {transform_info=self.active_transform})
		end
		self:enterViewportMode()
		end)
	local transform_cancel = Hook:new(function ()
		self:enterViewportMode()
		end)
	self.transform_input:getEvent("transform_commit", "down"):addHook(transform_commit)
	self.transform_input:getEvent("transform_cancel", "down"):addHook(transform_cancel)

	local transform_x_axis = Hook:new(function ()
		local active_transform = self.active_transform
		if active_transform then
			active_transform:lockX() end end)
	local transform_y_axis = Hook:new(function ()
		local active_transform = self.active_transform
		if active_transform then
			active_transform:lockY() end end)
	local transform_z_axis = Hook:new(function ()
		local active_transform = self.active_transform
		if active_transform then
			active_transform:lockZ() end end)
	self.transform_input:getEvent("transform_x_axis", "down"):addHook(transform_x_axis)
	self.transform_input:getEvent("transform_y_axis", "down"):addHook(transform_y_axis)
	self.transform_input:getEvent("transform_z_axis", "down"):addHook(transform_z_axis)

	local transform_to_move = Hook:new(function ()
		self:enterTransformMode("translate")
		end)
	local transform_to_rotate = Hook:new(function ()
		self:enterTransformMode("rotate")
		end)
	local transform_to_scale = Hook:new(function ()
		self:enterTransformMode("scale")
		end)
	self.transform_input:getEvent("transform_move", "down"):addHook(transform_to_move)
	self.transform_input:getEvent("transform_rotate", "down"):addHook(transform_to_rotate)
	self.transform_input:getEvent("transform_scale", "down"):addHook(transform_to_scale)
end

function ProvMapEdit:cycleTool(tool)
	local __cycle = {
		["edit"]  = "paint",
		["paint"] = "edit",
	}
	local __cyclefuncs = {
		["edit"]  = function ()
			gui:showModelPanel()
		end,
		["paint"] = function ()
			gui:showTexturePanel()
		end,
	}

	if tool then
		self.props.mapedit_tool = tool
		local func = __cyclefuncs[tool]
		if func then func() end
		return
	end

	self.props.mapedit_tool = __cycle[self.props.mapedit_tool]
	local func = __cyclefuncs[self.props.mapedit_tool]
	if func then func() end
end

function ProvMapEdit:selectionEmpty()
	return self.active_selection[1] == nil
end

local grabbed_mouse_x=0
local grabbed_mouse_y=0
function ProvMapEdit:captureMouse()
	love.mouse.setRelativeMode( true )
	grabbed_mouse_x = love.mouse.getX()
	grabbed_mouse_y = love.mouse.getY()
end
function ProvMapEdit:releaseMouse()
	love.mouse.setRelativeMode( false )
	love.mouse.setX(grabbed_mouse_x)
	love.mouse.setY(grabbed_mouse_y)
end

function ProvMapEdit:enterViewportMode()
	CONTROL_LOCK.MAPEDIT_VIEW.open()
	CONTROL_LOCK.MAPEDIT_TRANSFORM.close()
	self.props.mapedit_mode = "viewport"
	self.active_transform = nil
end

function ProvMapEdit:enterTransformMode(transform_mode)
	assert(transform_mode and (transform_mode == "translate" or transform_mode == "rotate" or transform_mode == "scale"))

	if self:selectionEmpty() then return end

	--local tile_selected, wall_selected, model_selected = self:getObjectTypesInSelection()
	local ok = self:objectTypesSelectedLimit{"tile","wall"}

	if transform_mode ~= "translate" and ok then
		if transform_mode == "rotate" then
			gui:displayPopup("Tiles cannot be rotated")
		else
			gui:displayPopup("Tiles cannot be scaled")
		end
		return
	end

	CONTROL_LOCK.MAPEDIT_TRANSFORM.elevate()
	self.props.mapedit_mode = "transform"
	self.props.mapedit_transform_mode = transform_mode
	local centre,_,_ = self:getSelectionCentreAndMinMax()
	self.active_transform = maptransform:newTransform(transform_mode,centre)
end

function ProvMapEdit:getCurrentMode()
	return self.props.mapedit_mode
end

function ProvMapEdit:addModelInstance(inst)
	local minsts = self.props.mapedit_model_insts
	local arg_type = provtype(inst)

	if arg_type == "table" then
		for i,v in ipairs(inst) do
			table.insert(minsts, v)
		end
	elseif arg_type == "modelinstance" then
		table.insert(minsts, inst)
	else
		error(string.format("ProvMapEdit:addModel(): unexpected argument of type %s, expected modelinstance/table", tostring(arg_type)))
	end
end

function ProvMapEdit:removeModelInstance(inst)
	local minsts = self.props.mapedit_model_insts
	local arg_type = provtype(inst)

	if arg_type == "table" then
		local set = {}
		local set_count = 0
		for i,v in ipairs(inst) do
			set[i] = v
			set_count = set_count + 1
		end

		for i=#minsts,1,-1 do
			for j,u in ipairs(set) do
				if minsts[i] == u then
					local group = self:isModelInAGroup(u)
					if group then
						group:removeFromGroup(u)
					end
					table.remove(set, j)
					table.remove(minsts, i)
					set_count = set_count - 1
					break
				end
			end

			if set_count == 0 then break end
		end
	elseif arg_type == "modelinstance" then
		for i=#minsts,1,-1 do
			if minsts[i] == inst then
				table.remove(minsts, i)
				return
			end
		end
	else
		error(string.format("ProvMapEdit:removeModel(): unexpected argument of type %s, expected modelinstance/table", tostring(arg_type)))
	end
end

local __GroupMeta = {
	isInGroup = function(self, inst)
		--for i,v in ipairs(self.insts) do
		--	if inst == v then return true end
		--end
		return self.__lookup[inst] ~= nil
		--return false
	end,

	addToGroup = function(self, inst)
		--[[for i,v in ipairs(self.insts) do
			if inst == v then return end
		end--]]
		if self.__lookup[inst] then return end
		table.insert(self.insts, inst)
		self.__lookup[inst]=true
	end,

	removeFromGroup = function(self, inst)
		for i,v in ipairs(self.insts) do
			if inst == v then
				table.remove(self.insts, i)
				self.__lookup[inst]=nil
				return
			end
		end
	end,

	calcMinMax = function(self)
		local insts = self.insts
		local c,min,max = ProvMapEdit:getObjectsCentreAndMinMax(insts)
		self.centre = c
		self.min = min
		self.max = max
	end,

	isEmpty = function(self)
		return self.insts[1] == nil
	end
}
__GroupMeta.__index = __GroupMeta
function ProvMapEdit:createModelGroup(name, insts)
	local group = {
		name = nil,
		insts = {},
		__lookup = {},

		centre = {0,0,0},
		min = {0,0,0},
		max = {0,0,0},
	}
	for i,v in ipairs(insts) do
		if not self:isModelInAGroup(v) then
			table.insert(group.insts, v)
			group.__lookup[v]=true
		end
	end
	-- ignore if empty
	if group.insts[1] == nil then return end

	-- ensure name is unique, appending an increasing number
	-- if not
	local groups = self.props.mapedit_model_groups
	local num = 1
	local unique_name = self:makeUniqueGroupName(name)
	group.name = unique_name

	setmetatable(group, __GroupMeta)
	table.insert(groups, group)
	group:calcMinMax()
	return group
end

function ProvMapEdit:addModelGroup(group)
	if not group then return end
	local groups = self.props.mapedit_model_groups
	for i,v in ipairs(groups) do
		if group == v then return end
	end
	table.insert(groups, group)
end

function ProvMapEdit:makeUniqueGroupName(name)
	local name = name or lang["default_group_name"]
	local groups = self.props.mapedit_model_groups
	local num = 1
	local unique_name = name
	while true do
		local unique = true
		for i,v in ipairs(groups) do
			if v.name == unique_name then
				num = num+1
				unique_name = name .. tostring(num)
				unique = false
				break
			end
		end
		if unique then break end
	end
	return unique_name
end

function ProvMapEdit:dissolveGroup(group)
	if not group then return end
	local groups = self.props.mapedit_model_groups
	for i,v in ipairs(groups) do
		if v == group then
			table.remove(groups,i)
			return
		end
	end
end

function ProvMapEdit:dissolveEmptyGroups()
	local groups = self.props.mapedit_model_groups
	local count = #groups
	for i=count,1,-1 do
		local group = groups[i]
		if #group.insts == 0 then
			table.remove(groups,i)
		end
	end
end

-- objectAtCursor returns {"model",model1,model2,...}
-- when selecting a group of models
-- this function decomposes this table into
-- {"model",model1},{"model",model2}...
function ProvMapEdit:decomposeObject(obj)
	if not obj then return nil end
	local o_type = obj[1]
	if obj[3] == nil then return obj end
	local objs = {}
	for i=2,#obj do
		table.insert(objs, {o_type,obj[i]})
	end
	return unpack(objs)
end

function ProvMapEdit:mergeGroups(...)
	local groups = {...}
	if groups[1]==nil then return nil end
	local insts = {}
	for _,group in ipairs(groups) do
		for i,v in ipairs(group.insts) do
			table.insert(insts, v) 
		end
		self:dissolveGroup(group)
	end
	local new_group = self:createModelGroup(groups[1].name.." Merge", insts)
	return new_group
end

function ProvMapEdit:isModelInAGroup(m)
	local groups = self.props.mapedit_model_groups

	for i,v in ipairs(groups) do
		local inside_group = v:isInGroup(m)
		if inside_group then return v end
	end
	return false
end

function ProvMapEdit:applyTransformObjOntoModel(model, t_obj)
	local pos = t_obj.position
	local rot = t_obj.rotation
	local scl = t_obj.scale
	model:setPosition(pos)
	model:setRotation(rot)
	model:setScale(scl)
end

local __tempregiontests = {}
-- returns either nil, or {"tile",x,z}, {"wall",x,z,side}, {"model", model_i, ...}
-- it may return multiple models in case a model group is clicked
function ProvMapEdit:objectAtCursor(x, y, tests)
	local unproject = cpml.mat4.unproject

	local test_tiles  = tests and tests.tile
	local test_walls  = tests and tests.wall
	local test_models = tests and tests.model
	local test_decals = tests and tests.decal
	local test_all = not tests

	local cam = self.props.mapedit_cam
	local viewproj = cam:getViewProjMatrix()
	local vw,vh = love.window.getMode()
	local viewport_xywh = {0,0,vw,vh}

	local cursor_v = cpml.vec3.new(x,y,1)
	local cam_pos = cpml.vec3.new(cam:getPosition())
	local unproject_v = unproject(cursor_v, viewproj, viewport_xywh)
	--local ray_dir_v = cpml.vec3.new(cam:getDirection())
	local ray = {position=cam_pos, direction=cpml.vec3.normalize(unproject_v - cam_pos)}

	local min_dist = 1/0
	local mesh_test = nil
	local normal = nil
	-- test against map mesh
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height

	local overlay = self.props.mapedit_overlay_edit
	local function __test_tile(x,z)
		local test_type = "face"
		if self.alt_modifier then test_type = "vert" end
		local intersect, dist, verts, n= self:testTileAgainstRay(ray, x,z, test_type)
		if intersect and dist < min_dist then
			mesh_test = {"tile"}
			for i,v in ipairs(verts) do
				mesh_test[i+1] = self:getTileVertexObject(x,z,v,overlay)
			end
			min_dist = dist
			normal = n
		end
	end

	local function __test_wall(x,z)
		local intersect, dist
		for i=1,5 do
			intersect, dist, n = self:testWallSideAgainstRay(ray, x,z, i)
			if intersect and dist < min_dist  then
				mesh_test = {"wall",self:getWallObject(x,z,i)}
				min_dist = dist
				normal = n
			end
		end
	end

	local function __test_model(model)
		local intersect, dist, normal = self:testModelAgainstRay(ray, model)
		if intersect and dist < min_dist then
			local group = self:isModelInAGroup(model)
			if group then
				mesh_test = {"model", unpack(group.insts)}
			else
				mesh_test = {"model", model}
			end
			min_dist = dist
		end
	end

	local function __test_decal(decal)
		local p = decal.box_pos
		local s = decal.box_size
		local intersect, dist = self:testBoxAgainstRay(ray, p[1],p[2],p[3],s[1],s[2],s[3])
		if intersect and dist-16 < min_dist then
			print("mad")
			mesh_test = {"decal", decal}
			min_dist = dist
		end
	end

	-- perform tests on each 4x4 section of the grid map
	local grid_size = 4
	local region_tests = __tempregiontests
	local g_w,g_h
	print("")
	if test_tiles or test_walls or test_all then
		local ceil = math.ceil
		local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
		local min,max = math.min,math.max
		g_w,g_h = ceil(w/grid_size), ceil(h/grid_size)
		for z=1,g_h do
			for x=1,g_w do
				local X,Z = (x-1.5)*TILE_SIZE*(grid_size), (z-1.5)*TILE_SIZE*(grid_size)
				local W   = TILE_SIZE*(grid_size+2.5)
				local D=W
				local Y = -5000
				local H = 10000

				local minY,maxY = 100000,-100000
				for _x=(x-1)*grid_size+1,min(x*grid_size+1,w) do
					for _z=(z-1)*grid_size+1,min(z*grid_size+1,h) do
						local Ht = self.props.mapedit_tile_heights[_z][_x]
						local Ht_type = type(Ht)
						if Ht_type=="number" then
							minY = min(minY,Ht*TILE_HEIGHT)
							maxY = max(maxY,Ht*TILE_HEIGHT)
						elseif Ht_type=="table" then
							for i,v in ipairs(Ht) do
								minY = min(minY,v*TILE_HEIGHT)
								maxY = max(maxY,v*TILE_HEIGHT)
							end
						end
					end
				end

				Y = minY-1
				H = (maxY-minY)+2

				local intersect = self:testBoxAgainstRay(ray,X,Y,Z,W,H,D)
				region_tests[x + (z-1)*g_w] = intersect ~= false
			end
		end
	end
	local function get_region_test_result(X,Z)
		return region_tests[X + (Z-1)*g_w]
	end

	local min = math.min
	if test_tiles or test_all then
		--for z=1,h do
		--	for x=1,w do
		--		__test_tile(x,z)
		--	end
		--end
		local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
		for X=1,g_w do
			for Z=1,g_h do
				local test_result = get_region_test_result(X,Z)
				if test_result then
					for z=(Z-1)*grid_size,min(Z*grid_size,h-1) do
						for x=(X-1)*grid_size,min(X*grid_size,w-1) do
							__test_tile(x+1,z+1)
						end
					end
				end
			end
		end
	end

	if test_walls or test_all then
		--for z=1,h do
		--	for x=1,w do
		--		__test_wall(x,z)
		--	end
		--end
		local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
		for X=1,g_w do
			for Z=1,g_h do
				local test_result = get_region_test_result(X,Z)
				if test_result then
					for z=(Z-1)*grid_size,min(Z*grid_size,h-1) do
						for x=(X-1)*grid_size,min(X*grid_size,w-1) do
							__test_wall(x+1,z+1)
						end
					end
				end
			end
		end
	end

	if test_models or test_all then
		for i,model in ipairs(self.props.mapedit_model_insts) do
			__test_model(model)
		end
	end

	if test_decals or test_all then
		for i,d_obj in ipairs(self.props.mapedit_decals) do
			__test_decal(d_obj)
		end
	end

	local result_pos=nil
	if mesh_test then
		result_pos = {0,0,0}
		result_pos[1] = ray.position.x + ray.direction.x * min_dist
		result_pos[2] = ray.position.y + ray.direction.y * min_dist
		result_pos[3] = ray.position.z + ray.direction.z * min_dist
	end

	return mesh_test, result_pos, normal
end

local __tempv1,__tempv2,__tempv3,__tempv4,__tempv5,__tempv6 = cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new()
local __temptri1, __temptri2 = {},{}
local __tempt1,__tempt2,__tempt3,__tempt4,__tempt5,__tempt6 = {0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0},{0,0,0}
local __results_t = {{1},{2},{3},{4},{1,2},{2,3},{3,4},{4,1}}
local __shape_map = {
{1,2,3,4,nil,nil},
{1,2,3,5,4,6},
{1,2,4,5,3,6},
{6,2,5,3,4,1},
{1,5,6,2,3,4}}
-- returns false
--         true, dist
--         true, dist, verts
-- where verts is a table containing at least one of [1,2,3,4], corresponding
-- to the nearest vertices/edge selected, if vert_test argument is true
function ProvMapEdit:testTileAgainstRay(ray, x,z, test_type)
	local ray_triangle = cpml.intersect.ray_triangle
	local v1,v2,v3,v4,v5,v6 = self:getTileVerts(x,z)
	local V1,V2,V3,V4,V5,V6 = __tempv1, __tempv2, __tempv3, __tempv4,__tempv5,__tempv6
	V1.x,V1.y,V1.z = v1[1],v1[2],v1[3]
	V2.x,V2.y,V2.z = v2[1],v2[2],v2[3]
	V3.x,V3.y,V3.z = v3[1],v3[2],v3[3]
	V4.x,V4.y,V4.z = v4[1],v4[2],v4[3]
	local tile_shape = self:getTileShape(x,z)
	if tile_shape > 0 then
		V5.x,V5.y,V5.z = v5[1],v5[2],v5[3]
		V6.x,V6.y,V6.z = v6[1],v6[2],v6[3]
	end

	if tile_shape == 0 then
	__temptri1[1], __temptri1[2], __temptri1[3] = V1, V2, V3
	__temptri2[1], __temptri2[2], __temptri2[3] = V3, V4, V1
	elseif tile_shape > 0 then
		__temptri1[1], __temptri1[2], __temptri1[3] = V1, V2, V3
		__temptri2[1], __temptri2[2], __temptri2[3] = V4, V5, V6
	end

	local intersect1, dist1 = ray_triangle(ray, __temptri1, false) 
	local intersect2, dist2 = ray_triangle(ray, __temptri2, false)

	local dist = nil
	local intersect = intersect1 or intersect2
	local normal = nil

	local function line(A,B)
		local v = {0,0,0}
		v[1]=B.x-A.x
		v[2]=B.y-A.y
		v[3]=B.z-A.z
		return v
	end
	local function crossN(A, B)
    local x = A[2] * B[3] - A[3] * B[2]
    local y = A[3] * B[1] - A[1] * B[3]
    local z = A[1] * B[2] - A[2] * B[1]
		local L = math.sqrt(x*x+y*y+z*z)
		if L == 0 then return nil end
		L=1/L
		x=x*L
		y=y*L
		z=z*L
    return {x, y, z}
	end
	if intersect1 and intersect2 then
		if dist1 < dist2 then
			normal = crossN(line(__temptri1[1],__temptri1[2]),line(__temptri1[1],__temptri1[3]))
		else
			normal = crossN(line(__temptri2[1],__temptri2[2]),line(__temptri2[1],__temptri2[3]))
		end
	elseif intersect1 then
		normal = crossN(line(__temptri1[1],__temptri1[2]),line(__temptri1[1],__temptri1[3]))
	elseif intersect2 then
		normal = crossN(line(__temptri2[1],__temptri2[2]),line(__temptri2[1],__temptri2[3]))
	end

	if intersect1 and intersect2 then
		dist = math.min(dist1,dist2)
	else
		dist = dist1 or dist2
	end

	local verts_t = nil
	if test_type=="vert" and intersect then
		local function length(v1,V) 
			local x = v1[1]-V.x
			local y = v1[2]-V.y
			local z = v1[3]-V.z
			return math.sqrt(x*x + y*y + z*z)
		end

		if tile_shape == 0 then
			local edge1,edge2,edge3,edge4,edge5,edge6 = __tempt1,__tempt2,__tempt3,__tempt4,__tempt5,__tempt6

			edge1[1] = (v1[1] + v2[1]) * 0.5
			edge1[2] = (v1[2] + v2[2]) * 0.5
			edge1[3] = (v1[3] + v2[3]) * 0.5

			edge2[1] = (v2[1] + v3[1]) * 0.5
			edge2[2] = (v2[2] + v3[2]) * 0.5
			edge2[3] = (v2[3] + v3[3]) * 0.5

			edge3[1] = (v3[1] + v4[1]) * 0.5
			edge3[2] = (v3[2] + v4[2]) * 0.5
			edge3[3] = (v3[3] + v4[3]) * 0.5

			edge4[1] = (v4[1] + v1[1]) * 0.5
			edge4[2] = (v4[2] + v1[2]) * 0.5
			edge4[3] = (v4[3] + v1[3]) * 0.5

			local v1d = length(v1,intersect)*1.15 -- multiply by 1.25 so edges are easier to grab
			local v2d = length(v2,intersect)*1.15
			local v3d = length(v3,intersect)*1.15
			local v4d = length(v4,intersect)*1.15
			local e1d = length(edge1,intersect)
			local e2d = length(edge2,intersect)
			local e3d = length(edge3,intersect)
			local e4d = length(edge4,intersect)

			local list={v1d,v2d,v3d,v4d,e1d,e2d,e3d,e4d}
			local list_min = 1/0
			local min_i=1
			for i=1,8 do
				local l = list[i]
				if l < list_min then min_i=i list_min=l end
			end
			verts_t = __results_t[min_i]
		else
			local verts={v1,v2,v3,v4,v5,v6}

			local edge1,edge2,edge3,edge4,edge5,edge6 = __tempt1,__tempt2,__tempt3,__tempt4,__tempt5,__tempt6
			local map = __shape_map[tile_shape+1]

			local vm1 = verts[map[1]]
			local vm2 = verts[map[2]]
			local vm3 = verts[map[3]]
			local vm4 = verts[map[4]]
			local vm5 = verts[map[5]]
			local vm6 = verts[map[6]]

			local edge_verts_order = {
				{1,2},{2,3},{3,1},{4,5},{5,6},{6,4}
			}

			edge1[1] = (vm1[1] + vm2[1]) * 0.5
			edge1[2] = (vm1[2] + vm2[2]) * 0.5
			edge1[3] = (vm1[3] + vm2[3]) * 0.5

			edge2[1] = (vm2[1] + vm3[1]) * 0.5
			edge2[2] = (vm2[2] + vm3[2]) * 0.5
			edge2[3] = (vm2[3] + vm3[3]) * 0.5

			edge3[1] = (vm3[1] + vm1[1]) * 0.5
			edge3[2] = (vm3[2] + vm1[2]) * 0.5
			edge3[3] = (vm3[3] + vm1[3]) * 0.5

			edge4[1] = (vm4[1] + vm5[1]) * 0.5
			edge4[2] = (vm4[2] + vm5[2]) * 0.5
			edge4[3] = (vm4[3] + vm5[3]) * 0.5

			edge5[1] = (vm5[1] + vm6[1]) * 0.5
			edge5[2] = (vm5[2] + vm6[2]) * 0.5
			edge5[3] = (vm5[3] + vm6[3]) * 0.5

			edge6[1] = (vm6[1] + vm4[1]) * 0.5
			edge6[2] = (vm6[2] + vm4[2]) * 0.5
			edge6[3] = (vm6[3] + vm4[3]) * 0.5


			local v1d = length(v1,intersect)*1.15 -- multiply by 1.25 so edges are easier to grab
			local v2d = length(v2,intersect)*1.15
			local v3d = length(v3,intersect)*1.15
			local v4d = length(v4,intersect)*1.15
			local v5d = length(v5,intersect)*1.15
			local v6d = length(v6,intersect)*1.15
			local e1d = length(edge1,intersect)
			local e2d = length(edge2,intersect)
			local e3d = length(edge3,intersect)
			local e4d = length(edge4,intersect)
			local e5d = length(edge5,intersect)
			local e6d = length(edge6,intersect)

			local list={v1d,v2d,v3d,v4d,v5d,v6d,e1d,e2d,e3d,e4d,e5d,e6d}
			local list_min = 1/0
			local min_i=1
			for i=1,12 do
				local l = list[i]
				if l < list_min then min_i=i list_min=l end
			end
			if min_i <= 6 then
				verts_t = {min_i}
			else
				local edge_i = min_i-6
				verts_t = {map[edge_verts_order[edge_i][1]], map[edge_verts_order[edge_i][2]]}
			end
		end
	elseif test_type=="face" and intersect then
		if tile_shape == 0 then
			verts_t = {1,2,3,4}
		else
			if intersect1 then
				verts_t = {1,2,3}
			else
				verts_t = {4,5,6}
			end
		end
	end

	return intersect, dist, verts_t, normal
end

local __tempvec3min = cpml.vec3.new()
local __tempvec3max = cpml.vec3.new()
local __tempaabb = {min=__tempvec3min, max=__tempvec3max}
function ProvMapEdit:testBoxAgainstRay(ray, x,y,z, w,h,d)
	local ray_aabb = cpml.intersect.ray_aabb

	local aabb = __tempaabb
	local min = aabb.min
	local max = aabb.max

	min.x,min.y,min.z = x  , y  , z
	max.x,max.y,max.z = x+w, y+h, z+d

	local intersect,dist = ray_aabb(ray,aabb)
	return intersect,dist
end

function ProvMapEdit:testWallSideAgainstRay(ray, x,z,side)
	local ray_triangle = cpml.intersect.ray_triangle
	local v1,v2,v3,v4 = self:getWallVerts(x,z, side)

	if not (v1 and v2 and v3 and v4) then return false, nil end

	local V1,V2,V3,V4 = __tempv1, __tempv2, __tempv3, __tempv4
	V1.x,V1.y,V1.z = v1[1],v1[2],v1[3]
	V2.x,V2.y,V2.z = v2[1],v2[2],v2[3]
	V3.x,V3.y,V3.z = v3[1],v3[2],v3[3]
	V4.x,V4.y,V4.z = v4[1],v4[2],v4[3]

	__temptri1[1], __temptri1[2], __temptri1[3] = V1, V2, V3
	__temptri2[1], __temptri2[2], __temptri2[3] = V3, V4, V1

	local intersect1, dist1 = ray_triangle(ray, __temptri1, false) 
	local intersect2, dist2 = ray_triangle(ray, __temptri2, false)

	local normal = nil
	local function line(A,B)
		local v = {0,0,0}
		v[1]=B.x-A.x
		v[2]=B.y-A.y
		v[3]=B.z-A.z
		return v
	end
	local function crossN(A, B)
    local x = A[2] * B[3] - A[3] * B[2]
    local y = A[3] * B[1] - A[1] * B[3]
    local z = A[1] * B[2] - A[2] * B[1]
		local L = math.sqrt(x*x+y*y+z*z)
		if L == 0 then return nil end
		L=1/L
		x=x*L
		y=y*L
		z=z*L
    return {x, y, z}
	end
	if intersect1 and intersect2 then
		if dist1 < dist2 then
			normal = crossN(line(__temptri1[1],__temptri1[2]),line(__temptri1[1],__temptri1[3]))
		else
			normal = crossN(line(__temptri2[1],__temptri2[2]),line(__temptri2[1],__temptri2[3]))
		end
	elseif intersect1 then
		normal = crossN(line(__temptri1[1],__temptri1[2]),line(__temptri1[1],__temptri1[3]))
	elseif intersect2 then
		normal = crossN(line(__temptri2[1],__temptri2[2]),line(__temptri2[1],__temptri2[3]))
	end

	local dist = nil
	local intersect = intersect1 or intersect2
	if intersect1 and intersect2 then
		dist = math.min(dist1,dist2)
	else
		dist = dist1 or dist2
	end

	return intersect, dist, normal
end

local __tempb3 = cpml.bound3.new(cpml.vec3.new{0,0,0},cpml.vec3.new{0,0,0})
function ProvMapEdit:testModelAgainstRay(ray , model_inst)
	local ray_aabb     = cpml.intersect.ray_aabb
	local ray_triangle = cpml.intersect.ray_triangle
	local mat4mul_vec4      = cpml.mat4.mul_vec4
	local bb_min,bb_max	= model_inst:getBoundingBoxMinMax()

	local bound3 = __tempb3
	bound3.min.x,bound3.min.y,bound3.min.z = bb_min[1], bb_min[2], bb_min[3]
	bound3.max.x,bound3.max.y,bound3.max.z = bb_max[1], bb_max[2], bb_max[3]

	local intersect, dist = ray_aabb(ray, bound3)

	if not intersect then return false, nil end

	local model_mat = model_inst:queryModelMatrix()
	local ref_model = model_inst:getModelReference()
	local mesh = ref_model.props.model_mesh

	if not mesh then -- ???
		return true, dist
	end

	local mesh_format = mesh:getVertexFormat()
	local position_attribute_i = nil
	for i,v in ipairs(mesh_format) do
		if v[1] == "VertexPosition" then
			position_attribute_i = i
			break
		end
	end
	assert(position_attribute_i)

	local vmap = mesh:getVertexMap()
	local vmap_count = #vmap
	local i = 1
	while i < vmap_count do
		local v1 = {mesh:getVertexAttribute(vmap[i+0], position_attribute_i)}
		local v2 = {mesh:getVertexAttribute(vmap[i+1], position_attribute_i)}
		local v3 = {mesh:getVertexAttribute(vmap[i+2], position_attribute_i)}
		v1[4],v2[4],v3[4] = 1,1,1

		mat4mul_vec4(v1, model_mat, v1)
		mat4mul_vec4(v2, model_mat, v2)
		mat4mul_vec4(v3, model_mat, v3)

		local V1,V2,V3 = __tempv1, __tempv2, __tempv3
		V1.x,V1.y,V1.z = v1[1],v1[2],v1[3]
		V2.x,V2.y,V2.z = v2[1],v2[2],v2[3]
		V3.x,V3.y,V3.z = v3[1],v3[2],v3[3]

		local tri_intersect, tri_dist = ray_triangle(ray, {V1,V2,V3}, true)
		if tri_intersect then
			return tri_intersect, tri_dist
		end

		i = i + 3
	end
	
	return nil, nil
end

--
-- in viewport mode, right clicking serves two purposes
-- if right clicking on a selected object, it opens open a context menu
-- if right clicking elsewhere, it gets rid of the current selection
-- 
function ProvMapEdit:viewportRightClickAction(x,y)
	if self.props.mapedit_mode ~= "viewport" then
		error("ProvMapEdit:viewportRightClickAction(): invoked outside of viewport mode.")
	end

	local x = x or love.mouse.getX()
	local y = y or love.mouse.getY()

	--local tile,wall,model = self:getObjectTypesInSelection(self.active_selection)
	local types = self:getObjectTypesInSelection(self.active_selection)
	--local obj = self:objectAtCursor( x,y , {tiles=tile,walls=wall,models=model} )
	local obj = self:objectAtCursor( x,y , types )

	if not obj then
		self:commitCommand("deselect_all", {})
		return
	else
		local function table_eq(a,b)
			for i,v in ipairs(a) do
				if v~=b[i] then return false end end
			return true
		end

		local isnt_part_of_selection = true
		for i,v in ipairs(self.active_selection) do
			if table_eq(v, obj) then
				isnt_part_of_selection = false
				break
			end
		end
		if isnt_part_of_selection then
			self:commitCommand("deselect_all", {})
			return
		end
	end

	self:openSelectionContextMenu(types)
end

function ProvMapEdit:getSelectionContextMenu()
	local exists = self:getObjectTypesInSelection(self.active_selection)
	--local tile,wall,model = self:getObjectTypesInSelection(self.active_selection)
	if self:objectTypesSelectedLimit{"model"} then
		 	local objs = self.active_selection
			local groups = {}
			local function add_to_groups(g) -- ensures unique entries in groups
				for i,v in ipairs(groups) do
					if v==g then return end end
				table.insert(groups, g)
			end
			local model_outside_group_exists = false
			local model_outside_group_count = 0
			local models_outside = {}
			for i,v in ipairs(objs) do
				local group = self:isModelInAGroup(v[2])
				if group then
					add_to_groups(group)
				else
					model_outside_group_exists = true
					model_outside_group_count = model_outside_group_count+1
					table.insert(models_outside, v[2])
				end
			end
			local group_count = #groups

			local group_flags = {
				create_enable = (group_count == 0) and (model_outside_group_count>1),
				merge_groups_enable = (group_count > 1) and (not model_outside_group_exists),
				add_to_group_enable = (group_count==1) and (model_outside_group_exists),
				ungroup_enable = (group_count==1) and (not model_outside_group_exists),
				models_outside = models_outside,
				groups = groups
			}

		--gui:openContextMenu("select_models_context", {select_objects=self.active_selection, group_info=group_flags})
		return "select_models_context", {select_objects=self.active_selection, group_info=group_flags}
	elseif self:objectTypesSelectedLimit{"tile","wall"} then
		return "select_mesh_context", {select_objects=self.active_selection}
	elseif self:objectTypesSelectedLimit{"decal"} then
		return "select_decal_context", {select_objects=self.active_selection}
	else
		return "select_undef_context", {}
	end
	return nil, nil
end

function ProvMapEdit:openSelectionContextMenu()
	local cxtm_name, props = self:getSelectionContextMenu()
	if cxtm_name then
		gui:openContextMenu(cxtm_name, props)
	end
end

function ProvMapEdit:deselectSelection()
	if not self:selectionEmpty() then
		self:commitCommand("deselect_all", {})
	end
end

-- returns tile_exists, wall_exists, models_exists
function ProvMapEdit:getObjectTypesInSelection(selection)
	local selection = selection or self.active_selection

	local exists = {}
	--local tile_exists   = false
	--local wall_exists   = false
	--local models_exists = false
	for i,v in ipairs(selection) do
		exists[v[1]] = true
		--if     v[1] == "tile"  then tile_exists = true
		--elseif v[1] == "wall"  then wall_exists = true
		--elseif v[1] == "model" then models_exists = true
		--end

		-- prematurely break if all types already found
		--if tile_exists and wall_exists and models_exists then break end
	end
	--return tile_exists, wall_exists, models_exists
	return exists
end

function ProvMapEdit:objectTypesSelectedLimit(lim, selection)
	local l={}
	for i,v in ipairs(lim) do
		l[v]=true
	end
	local found = false
	local selection = selection or self.active_selection
	for i,v in ipairs(selection) do
		local o_type = v[1]
		if not l[o_type] then return false end
		found = true
	end
	return found
end

function ProvMapEdit:getTilesIndexInMesh( x,z )
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then
		return nil end

	local vmap = self.props.mapedit_map_mesh.tile_vert_map
	local index = vmap[z][x].first
	local tile_shape = self.props.mapedit_tile_shapes[z][x]
	local count = 3
	if tile_shape > 0 then count = 5 end

	return index, index + count
end

function ProvMapEdit:getTileShape( x,z )
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then
		return nil end
	local shapes = self.props.mapedit_tile_shapes
	return shapes[z][x]
end

function ProvMapEdit:getTileVertCount( x,z )
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then
		return nil end
	local shapes = self.props.mapedit_tile_shapes
	local s = shapes[z][x]
	if s==0 then return 4
	else return 6 end
end

function ProvMapEdit:getTileVerts( x,z )
	local index, index_end = self:getTilesIndexInMesh( x,z )
	if not index then return nil,nil,nil,nil,nil,nil end

	local mesh = self.props.mapedit_map_mesh.mesh
	local v = {}
	for i=index, index_end do
		v[i-index+1] = {mesh:getVertexAttribute( i, 1 )}
	end
	return v[1],v[2],v[3],v[4],v[5],v[6]
end

function ProvMapEdit:getTileVertex( x,z , vert_i )
	local index = self:getTilesIndexInMesh( x,z )
	if not index then return nil end
	assert(vert_i>=1 and vert_i<=6)

	local mesh = self.props.mapedit_map_mesh.mesh
	local x,y,z = mesh:getVertexAttribute( index+vert_i-1, 1 )

	return
		{x,y,z}
end

function ProvMapEdit:setTileVertex( x,z , vert_i , pos )
	local index = self:getTilesIndexInMesh( x,z )
	if not index then
		return false end
	assert((vert_i>=1 and vert_i<=6) and pos)

	local mesh = self.props.mapedit_map_mesh.mesh
	local X,_,Z = mesh:getVertexAttribute( index+vert_i-1 , 1 )
	local int = math.ceil
	local new_y = int(pos[2])
	mesh:setVertexAttribute( index+vert_i-1 , 1 , X, new_y, Z)
	self:updateTileVertex(x,z, vert_i, X, new_y, Z)
	return true
end

function ProvMapEdit:getWallsIndexInMesh( x,z , side )
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then
		return nil end

	assert(side>=1 and side<=5)
	local wmap = self.props.mapedit_map_mesh.wall_vert_map
	local index = wmap[z][x][side].first
	local last  = wmap[z][x][side].last
	return index,last
end

function ProvMapEdit:getWallVerts( x,z , side )
	assert(x,z,side)
	local index = self:getWallsIndexInMesh(x,z,side)
	if not index then return nil,nil,nil,nil end

	local mesh = self.props.mapedit_map_mesh.mesh
	local x1,y1,z1 = mesh:getVertexAttribute( index+0, 1 )
	local x2,y2,z2 = mesh:getVertexAttribute( index+1, 1 )
	local x3,y3,z3 = mesh:getVertexAttribute( index+2, 1 )
	local x4,y4,z4 = mesh:getVertexAttribute( index+3, 1 )

	return
		{x1,y1,z1},
		{x2,y2,z2},
		{x3,y3,z3},
		{x4,y4,z4}
end

function ProvMapEdit:getTileVertexTexOffset(x,z,vert_i,overlay)
	if not overlay then
		return __getTileVertexTexOffset(self.props.mapedit_tile_tex_offsets,x,z,vert_i)
	else
		return __getTileVertexTexOffset(self.props.mapedit_overlay_tex_offsets,x,z,vert_i)
	end
end
function ProvMapEdit:getWallTexOffset(x,z,side)
	return __getWallTexOffset(self.props.mapedit_wall_tex_offsets,x,z,side)
end
function ProvMapEdit:getTileVertexTexScale(x,z,vert_i,overlay)
	if not overlay then
		return __getTileVertexTexScale(self.props.mapedit_tile_tex_scales,x,z,vert_i)
	else
		return __getTileVertexTexScale(self.props.mapedit_overlay_tex_scales,x,z,vert_i)
	end
end
function ProvMapEdit:getWallTexScale(x,z,side)
	return __getWallTexScale(self.props.mapedit_wall_tex_scales,x,z,side)
end

function ProvMapEdit:getTexOffset(obj)
	local o_type = obj[1]
	if o_type=="tile" then
		local t = obj[2]
		return self:getTileVertexTexOffset(t.x,t.z,t.vert_i,t.overlay)
	elseif o_type=="wall" then
		local w = obj[2]
		return self:getWallTexOffset(w.x,w.z,w.side)
	else
		error("ProvMapEdit:getTexOffset(): unexpected object")
	end
end

function ProvMapEdit:getTexScale(obj)
	local o_type = obj[1]
	if o_type=="tile" then
		local t = obj[2]
		return self:getTileVertexTexScale(t.x,t.z,t.vert_i,t.overlay)
	elseif o_type=="wall" then
		local w = obj[2]
		return self:getWallTexScale(w.x,w.z,w.side)
	else
		error("ProvMapEdit:getTexScale(): unexpected object")
	end
end

function ProvMapEdit:setTexOffset(obj, offset)
	if not offset then return end
	local o_type = obj[1]
	if o_type=="tile" then
		local t = obj[2]
		local overlay=t.overlay
		if overlay then
			self:setOverlayVertexTexOffset(t.x,t.z,t.vert_i, offset[1], offset[2])
		else
			self:setTileVertexTexOffset(t.x,t.z,t.vert_i, offset[1], offset[2])
		end
	elseif o_type=="wall" then
		local w = obj[2]
		self:setWallTexOffset(w.x,w.z,w.side, offset[1], offset[2])
	else
		error("ProvMapEdit:setTexOffset(): unexpected object")
	end
end

function ProvMapEdit:setTexScale(obj, scale)
	if not scale then return end
	local o_type = obj[1]
	if o_type=="tile" then
		local t = obj[2]
		local overlay=t.overlay
		if overlay then
			self:setOverlayVertexTexScale(t.x,t.z,t.vert_i, scale[1], scale[2])
		else
			self:setTileVertexTexScale(t.x,t.z,t.vert_i, scale[1], scale[2])
		end
	elseif o_type=="wall" then
		local w = obj[2]
		self:setWallTexScale(w.x,w.z,w.side, scale[1], scale[2])
	else
		error("ProvMapEdit:setTexScale(): unexpected object")
	end
end

local __temphtable = {0,0,0,0}
local __shape_map = {
{1,2,3,4,nil,nil},
{1,2,3,5,4,6},
{1,2,4,5,3,6},
{6,2,5,3,4,1},
{1,5,6,2,3,4}}
function ProvMapEdit:updateTileVerts(x,z)
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then return end

	-- update mesh and surrounding walls
	local mesh = self.props.mapedit_map_mesh.mesh
	local index, index_end = self:getTilesIndexInMesh(x,z)
	local heights = __temphtable
	--local heights = {0,0,0,0}
	for i=0, index_end-index-1 do
		local x,y,z = mesh:getVertexAttribute(index + i, 1)
		y = y / TILE_HEIGHT
		heights[i+1] = y
	end

	local tile_heights = self.props.mapedit_tile_heights
	local stored_heights = tile_heights[z][x]
	if type(stored_heights) ~= "table" then
		tile_heights[z][x] = {unpack(heights)}
	else
		local tile_shape = self:getTileShape(x,z)
		local shape_map = __shape_map[tile_shape+1]
		for i=1,6 do
			local I = shape_map[i]
			if not I then break end
			stored_heights[i]=heights[I]
		end
	end
end

function ProvMapEdit:updateTileVertex(x,z,i, _x,_y,_z)
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then return end
	assert(i>=1 and i<=6)

	-- update mesh and surrounding walls
	local mesh = self.props.mapedit_map_mesh.mesh
	local index = self:getTilesIndexInMesh(x,z)
	local X,Y,Z
	if _z then
		X,Y,Z = _x,_y,_z
	else
		X,Y,Z = mesh:getVertexAttribute(index+i-1, 1)
	end
	local height = Y / TILE_HEIGHT

	local tile_shape = self:getTileShape(x,z)
	local vertex_to_height_table_index = __shape_map[tile_shape+1]

	local tile_heights = self.props.mapedit_tile_heights
	local stored_heights = tile_heights[z][x]
	if type(stored_heights) ~= "table" then
		local h = stored_heights
		local t = {0,0,0,0,0,0}
		for j=1,6 do
			t[j] = h
		end
		local I = vertex_to_height_table_index[i]
		assert(I)
		t[I] = height

		tile_heights[z][x] = t
	else
		local I = vertex_to_height_table_index[i]
		stored_heights[I]=height
	end
end

-- takes in a list of selected objects in the form {"tile", tile_vertex_obj} (non-tile objects are ignored)
-- returns two 1:1 tables of unique x-indices and z-indices pairs for all tiles in this set of tile vertex objects
function ProvMapEdit:getSelectedTilesFromObjs(objs)
	local x_table = {}
	local z_table = {}

	local function insert_to_set(x,z)
		local S = #x_table
		for i=1,S do
			if x_table[i]==x and z_table[i]==z then return end
		end
		x_table[S+1] = x
		z_table[S+1] = z
	end

	for i,v in ipairs(objs) do
		local o_type = v[1]
		if o_type == "tile" then
			local x,z = v[2].x, v[2].z
			insert_to_set(x,z)
		end
	end
	return x_table,z_table
end

-- takes in a list of selected objects in the form {"tile", tile_vertex_obj} (non-tile objects are ignored)
-- returns two 1:1 tables of unique x-indices and z-indices pairs for all tiles in this set of tile vertex objects
-- this expanded version also includes all non-diagonally adjacent tiles
function ProvMapEdit:getSelectedTilesFromObjs_expanded(objs)
	local x_table = {}
	local z_table = {}

	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height

	local function insert_to_set(x,z)
		if x<1 or x>w or z<1 or z>h then return end

		local S = #x_table
		for i=1,S do
			if x_table[i]==x and z_table[i]==z then return end
		end
		x_table[S+1] = x
		z_table[S+1] = z
	end

	for i,v in ipairs(objs) do
		local o_type = v[1]
		if o_type == "tile" then
			local x,z = v[2].x, v[2].z
			insert_to_set(x,z)
			insert_to_set(x+1,z)
			insert_to_set(x-1,z)
			insert_to_set(x,z+1)
			insert_to_set(x,z-1)
		end
	end
	return x_table,z_table
end

-- regenerates all the appropiate walls for given table of selected object tile vertices {"tile", tile_vertex_object}
function ProvMapEdit:updateSelectedTileWalls(objs)
	local x_t,z_t = self:getSelectedTilesFromObjs_expanded(objs)
	for i,x in ipairs(x_t) do
		local z=z_t[i]
		self:updateWallVerts(x,z)
	end
end

function ProvMapEdit:getObjectTexture(obj)
	if obj[1] == "tile" then
		local tile_v = obj[2]
		local z,x=tile_v.z,tile_v.x

		local overlay = tile_v.overlay
		local t_texs = self.props.mapedit_tile_textures
		if overlay then t_texs = self.props.mapedit_overlay_textures end

		local tile_shape = self.props.mapedit_tile_shapes[tile_v.z][tile_v.x]
		local texture_i = 1
		if tile_shape~=0 and tile_v.vert_i>=4 then texture_i=2 end
		local tex = t_texs[z][x]
		if type(tex)=="table" then return tex[texture_i]
		else return tex end
	end
	if obj[1] == "wall" then
		local wall_v = obj[2]
		local z,x=wall_v.z,wall_v.x
		local tex = self.props.mapedit_wall_textures[z][x]
		if type(tex)=="table" then return tex[wall_v.side]
		else return tex end
	end
	if obj[1] == "model" then
		return nil
	end
	if obj[1] == "decal" then
		return obj[2].texture
	end
end

function ProvMapEdit:getTextureFromName(name)
	local texs = self.props.mapedit_texture_list
	local ti = texs[name]
	if not ti then return end
	local tex = texs[ti]
	if tex then return tex[2] end
	return nil
end

function ProvMapEdit:getOverlayTexTable()
	return self.props.mapedit_overlay_textures end
function ProvMapEdit:getOverlayAttrsMesh()
	return self.props.mapedit_map_mesh.overlay_atts end

function ProvMapEdit:setObjectTexture(obj, tex)
	local o_type = obj[1]
	if o_type == "tile" then
		local t = obj[2]
		local overlay = t.overlay
		if overlay then
			self:setTileVertexTexture(t.x,t.z,t.vert_i,tex,self:getOverlayTexTable(),self:getOverlayAttrsMesh())
		else
			self:setTileVertexTexture(t.x,t.z,t.vert_i,tex)
		end
	elseif o_type == "wall" then
		local t = obj[2]
		self:setWallTexture(t.x,t.z,t.side,tex)
	end
end

-- returns true if texture changed, otherwise false
-- also returns previous texture name
function ProvMapEdit:setTileVertexTexture(x,z,i,tex_name, tex_table, attrs)
	local tex_table = tex_table or self.props.mapedit_tile_textures
	local attrs = attrs or self.props.mapedit_map_mesh.mesh_atts

	local tile_shape = self:getTileShape(x,z)
	local texture_i = 1
	local v1i,v2i,v3i,v4i
	if tile_shape==0 then
		texture_i = 1
		v1i,v2i,v3i,v4i=1,2,3,4
	elseif tile_shape==1 then
		if (i>=4) then
			texture_i=2
			v1i,v2i,v3i,v4i=4,5,6,nil
		else
			v1i,v2i,v3i,v4i=1,2,3,nil
		end
	elseif tile_shape==2 then
		if (i>=4) then
			texture_i=2
			v1i,v2i,v3i,v4i=4,5,6,nil
		else
			v1i,v2i,v3i,v4i=1,2,3,nil
		end
	elseif tile_shape==3 then
		if (i<=3) then
			v1i,v2i,v3i,v4i=1,2,3,nil
		else
			texture_i=2
			v1i,v2i,v3i,v4i=4,5,6,nil
		end
	elseif tile_shape==4 then
		if (i<=3) then
			v1i,v2i,v3i,v4i=1,2,3,nil
		else
			texture_i=2
			v1i,v2i,v3i,v4i=4,5,6,nil
		end
	end

	-- convert to table for the future
	local curr_texture = tex_table[z][x]
	if type(curr_texture) ~= "table" and curr_texture then
		tex_table[z][x] = {curr_texture, curr_texture}
		curr_texture = tex_table[z][x][texture_i]
	else
		tex_table[z][x] = {tex_name,tex_name}
	end

	if curr_texture == tex_name then return false, curr_texture end

	local loaded_textures = self.props.mapedit_texture_list
	local tex_id = loaded_textures[tex_name]
	--assert(tex_id)
	if tex_id then
		tex_id = tex_id - 1 -- shift to 0-index for GLSL
	else
		tex_id = -1
	end

	local index = self:getTilesIndexInMesh( x,z )
	if not index then return false, curr_texture end

	attrs:setVertexAttribute(index+v1i-1, 3, tex_id)
	attrs:setVertexAttribute(index+v2i-1, 3, tex_id)
	attrs:setVertexAttribute(index+v3i-1, 3, tex_id)
	if v4i then attrs:setVertexAttribute(index+v4i-1, 3, tex_id) end
	tex_table[z][x][texture_i] = tex_name

	self.__object_painted = {"tile",{x=x,z=z,vert_i=i}}
	self.__object_painted_time = getTickSmooth()

	return true, curr_texture
end

function ProvMapEdit:fixAllTileTextures()
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	for z=1,h do
		for x=1,w do
			self:fixTileTexture(x,z)
		end
	end
end
function ProvMapEdit:fixTileTexture(x,z)
	local shape = self:getTileShape(x,z)
	if shape==0 then
		for i=1,4 do
			self:fixTileVertexTexture(x,z,i)
		end
	else
		for i=1,6 do
			self:fixTileVertexTexture(x,z,i)
		end
	end
end
function ProvMapEdit:fixTileVertexTexture(x,z,i)
	local tex = self.props.mapedit_tile_textures[z][x]
	if not tex then return end

	local entry_type = type(tex)
	local tex_id=nil
	if entry_type=="table" then
		local tile_shape = self:getTileShape(x,z)
		local texture_i = 1
		if tile_shape>0 and i>=4 then
			texture_i = 2
		end
		tex_id=tex[texture_i]
	else
		tex_id=tex
	end
	if not tex_id then return end
	tex_id = self.props.mapedit_texture_list[tex_id]-1
	local mesh = self.props.mapedit_map_mesh.mesh_atts
	local index = self:getTilesIndexInMesh(x,z)
	mesh:setVertexAttribute(index+i-1, 3, tex_id)
end

function ProvMapEdit:fixAllWallTextures()
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	for z=1,h do
		for x=1,w do
			self:fixWallTexture(x,z)
		end
	end
end
function ProvMapEdit:fixWallTexture(x,z)
	for side=1,5 do
		self:fixWallSideTexture(x,z,side)
	end
end
function ProvMapEdit:fixWallSideTexture(x,z,side)
	local tex = self.props.mapedit_wall_textures[z][x]
	if not tex then return end

	local entry_type = type(tex)
	local tex_id=nil
	if entry_type=="table" then
		tex_id=tex[side]
	else
		tex_id=tex
	end
	if not tex_id then return end
	tex_id = self.props.mapedit_texture_list[tex_id]-1
	local mesh = self.props.mapedit_map_mesh.mesh_atts
	index,index_end = self:getWallsIndexInMesh(x,z,side)
	for i=index,index_end do
		mesh:setVertexAttribute(i, 3, tex_id)
	end
end

function ProvMapEdit:setWallTexture(x,z,side,tex_name)
	local curr_texture = self.props.mapedit_wall_textures[z][x][side]
	if curr_texture == tex_name then return false, curr_texture end

	local loaded_textures = self.props.mapedit_texture_list
	local tex_id = loaded_textures[tex_name]
	assert(tex_id)
	local tex_info = loaded_textures[tex_id]
	tex_id = tex_id - 1 -- shift to 0-index for GLSL

	local tex_img = tex_info[2]
	local tex_h = tex_img:getHeight()
	local y_scale = tex_h / TILE_HEIGHT;

	local index = self:getWallsIndexInMesh( x,z, side )
	if not index then return false, curr_texture end

	local mesh = self.props.mapedit_map_mesh.mesh_atts
	mesh:setVertexAttribute(index+0, 3, tex_id)
	mesh:setVertexAttribute(index+1, 3, tex_id)
	mesh:setVertexAttribute(index+2, 3, tex_id)
	mesh:setVertexAttribute(index+3, 3, tex_id)
	self.props.mapedit_wall_textures[z][x][side] = tex_name
	self:setWallTexScale(x,z,side)
	return true, curr_texture
end

function ProvMapEdit:setOverlayVertexTexOffset(x,z,vert_i, new_x,new_y)
	self:setTileVertexTexOffset(x,z,vert_i, new_x,new_y, self.props.mapedit_overlay_tex_offsets, self:getOverlayAttrsMesh())
end
function ProvMapEdit:setTileVertexTexOffset(x,z,vert_i, new_x,new_y, offsets, attr)
	local offsets = offsets or self.props.mapedit_tile_tex_offsets
	local attr    = attr   or self.props.mapedit_map_mesh.mesh_atts

	local curr = self:getTileVertexTexOffset(x,z,vert_i)
	local new_x = new_x or curr[1]
	local new_y = new_y or curr[2]
	local tile_shape = self:getTileShape(x,z)

	local start_i,end_i = 0,5
	if tile_shape>0 then
		if not offsets[z][x] then
			offsets[z][x]={nil,nil}
		end
		if vert_i>=4 then
			start_i,end_i=3,5
			local o_type = type(offsets[z][x][1])
			if o_type=="table" then
				offsets[z][x][2] = {new_x,new_y}
			elseif o_type==nil then
				offsets[z][x][1] = {1,1}
				offsets[z][x][2] = {new_x,new_y}
			else
				offsets[z][x] = {{1,1},{new_x,new_y}}
			end
		else
			start_i,end_i=0,2
			local o_type = type(offsets[z][x][2])
			if o_type=="table" then
				offsets[z][x][1] = {new_x,new_y}
			elseif o_type==nil then
				offsets[z][x][2] = {1,1}
				offsets[z][x][1] = {new_x,new_y}
			else
				offsets[z][x] = {{new_x,new_y},{1,1}}
			end
		end
	else
		offsets[z][x] = {{new_x,new_y},{new_x,new_y}}
	end
	local tile_index = self:getTilesIndexInMesh(x,z)
	start_i,end_i = start_i+tile_index,end_i+tile_index
	for i=start_i,end_i do
		attr:setVertexAttribute(i, 2, new_x,new_y)
	end
end

function ProvMapEdit:setOverlayVertexTexScale(x,z,vert_i, new_x,new_y)
	self:setTileVertexTexScale(x,z,vert_i, new_x,new_y, self.props.mapedit_overlay_tex_scales, self:getOverlayAttrsMesh())
end
function ProvMapEdit:setTileVertexTexScale(x,z,vert_i, new_x,new_y, scales,attr)
	local scales = scales or self.props.mapedit_tile_tex_scales
	local attr   = attr   or self.props.mapedit_map_mesh.mesh_atts

	local curr = self:getTileVertexTexScale(x,z,vert_i)
	local new_x = new_x or curr[1]
	local new_y = new_y or curr[2]
	if new_x==0.0 then new_x = 0.01 end 
	if new_y==0.0 then new_y = 0.01 end 
	local tile_shape = self:getTileShape(x,z)

	local scales = self.props.mapedit_tile_tex_scales
	local start_i,end_i = 0,5
	if tile_shape>0 then
		if not scales[z][x] then
			scales[z][x]={nil,nil}
		end
		if vert_i>=4 then
			start_i,end_i=3,5
			local o_type = type(scales[z][x][1])
			if o_type=="table" then
				scales[z][x][2] = {new_x,new_y}
			elseif o_type==nil then
				scales[z][x][1] = {1,1}
				scales[z][x][2] = {new_x,new_y}
			else
				scales[z][x] = {{1,1},{new_x,new_y}}
			end
		else
			start_i,end_i=0,2
			local o_type = type(scales[z][x][2])
			if o_type=="table" then
				scales[z][x][1] = {new_x,new_y}
			elseif o_type==nil then
				scales[z][x][2] = {1,1}
				scales[z][x][1] = {new_x,new_y}
			else
				scales[z][x] = {{new_x,new_y},{1,1}}
			end
		end
	else
		scales[z][x] = {{new_x,new_y},{new_x,new_y}}
	end
	local tile_index = self:getTilesIndexInMesh(x,z)
	start_i,end_i = start_i+tile_index,end_i+tile_index
	for i=start_i,end_i do
		attr:setVertexAttribute(i, 1, new_x,new_y)
	end
end

function ProvMapEdit:setWallTexOffset(x,z,side, new_x,new_y)
	local curr = self:getWallTexOffset(x,z,vert_i)
	local new_x = new_x or curr[1]
	local new_y = new_y or curr[2]

	local offsets = self.props.mapedit_wall_tex_offsets
	local off = offsets[z][x]
	if not off then offsets[z][x]={} end
	off = offsets[z][x][side]
	if not off then
		offsets[z][x][side] = {new_x,new_y}
	else
		off[1] = new_x
		off[2] = new_y
	end

	local start_i, end_i = self:getWallsIndexInMesh(x,z,side)
	local mesh = self.props.mapedit_map_mesh.mesh_atts
	for i=start_i,end_i do
		mesh:setVertexAttribute(i, 2, new_x,new_y)
	end
end

function ProvMapEdit:fitWallTextureToScale(x,z,side)
	local mesh = self.props.mapedit_map_mesh.mesh_atts
	local wall = self:getWallObject(x,z,side)
	local tex = self:getObjectTexture{"wall",wall}
	if not tex then return end
	tex=self:getTextureFromName( tex )
	if not tex then return end
	local texh = tex:getHeight()
	local texw = tex:getWidth()
	local start_i, end_i = self:getWallsIndexInMesh(x,z,side)
	for i=start_i,end_i do
		local x,y = mesh:getVertexAttribute(i, 1)
		mesh:setVertexAttribute(i, 1, x, y * (texh/texw) * (TILE_SIZE/TILE_HEIGHT) )
	end
end
function ProvMapEdit:setWallTexScale(x,z,side, new_x,new_y)
	local curr = self:getWallTexScale(x,z,vert_i)
	local new_x = new_x or curr[1]
	local new_y = new_y or curr[2]
	if new_x==0.0 then new_x = 0.01 end 
	if new_y==0.0 then new_y = 0.01 end 

	local scales = self.props.mapedit_wall_tex_scales
	local scale = scales[z][x]
	if not scale then scales[z][x]={} end
	scale = scales[z][x][side]
	if not scale then
		scales[z][x][side] = {new_x,new_y}
	else
		scale[1] = new_x
		scale[2] = new_y
	end

	local start_i, end_i = self:getWallsIndexInMesh(x,z,side)
	local mesh = self.props.mapedit_map_mesh.mesh_atts
	for i=start_i,end_i do
		mesh:setVertexAttribute(i, 1, new_x,new_y)
	end
	self:fitWallTextureToScale(x,z,side)
end


function ProvMapEdit:__getScaleByDist()
	local w = love.graphics.getDimensions()
	local centre = self:getSelectionCentreAndMinMax()
	if not centre then
		return 1.0
	end
	local cam_pos = self.props.mapedit_cam:getPosition()
	local dx = centre[1] - cam_pos[1]
	local dy = centre[2] - cam_pos[2]
	local dz = centre[3] - cam_pos[3]
	local l = math.sqrt(dx*dx + dy*dy + dz*dz)
	if l == 0 then return 1.0 end
	l = (l*(90/50000))/(w/1366)
	return l
	--if l > 1 then return 1.0 end
	--return l*l*l
end

local __tempmat4tt = cpml.mat4.new()
local __tempvec3tt = cpml.vec3.new()
local __temptablett = {0,0,0,"dir"}
function ProvMapEdit:getBaseMatrixFromMapEditTransformation(transform)
	local info = transform:getTransform(self.props.mapedit_cam, self.granulate_transform)
	local t_type = info.type
	local getScaleByDist = self.__getScaleByDist

	local __id = {
		1,0,0,0,
		0,1,0,0,
		0,0,1,0,
		0,0,0,1}
	for i=1,16 do
		__tempmat4tt[i] = __id[i]
	end

	local absolute = transform.absolute
	if absolute then getScaleByDist=function () return 1.0 end end

	local mat = __tempmat4tt
	if t_type == "translate" then

		local int = math.floor
		local g_scale=8
		if not self.granulate_transform then
			g_scale = 0.5
		end
		local function granulate(v, g_scale)
			if absolute then return v end
			v.x = int(v.x/g_scale)*g_scale
			v.y = int(v.y/g_scale)*g_scale
			v.z = int(v.z/g_scale)*g_scale
			return v
		end

		local translate = __tempvec3tt
		local s = getScaleByDist(self)
		translate.x = int(info[1]*s)
		translate.y = int(info[2]*s)
		translate.z = int(info[3]*s)
		granulate(translate,g_scale)
		mat:translate(mat, translate)
		return mat, info
	end

	if t_type == "rotate" then
		-- granulating is handled by the MapEditTransform object itself
		local function granulate(v)
			return v
		end

		local quat = info[1]
		granulate(quat)
		return cpml.mat4.from_quaternion(quat), info
	end

	if t_type == "scale" or t_type == "flip" then

		local int = math.floor
		local function granulate(v)
			if absolute then return v end
			if not self.granulate_transform then return v end

			if v.x >= 1.0 then v.x = int(v.x) else
			                   v.x = 1/int(1/v.x) end
			if v.y >= 1.0 then v.y = int(v.y) else
			                   v.y = 1/int(1/v.y) end
			if v.z >= 1.0 then v.z = int(v.z) else
			                   v.z = 1/int(1/v.z) end
			return v
		end

		local scale = __tempvec3tt
		local s = 1.0
		scale.x = info[1]*s
		scale.y = info[2]*s
		scale.z = info[3]*s
		granulate(scale)
		mat:scale(mat, scale)
		return mat, info
	end
	error()
end

-- takes in a transformation matrix,
-- 2nd argument is an optional precalculated result from getBaseMatrixFromMapEditTransformation
-- returns two matrices a,b
-- b*model_mat*a gives the post-transformation model matrix for a model
-- matrix "a" translates a point by -selection_centre and applies the map edit transformation
-- matrix "b" translates the point back by +selection_centre
local __tempmat4A = cpml.mat4.new()
local __tempmat4B = cpml.mat4.new()
local __tempvec3c = cpml.vec3.new()
local __tempvec3ci = cpml.vec3.new()
function ProvMapEdit:getSelectionTransformationModelMatrix(transform, matrix)
	local base_mat, info = self:getBaseMatrixFromMapEditTransformation(transform)
	base_mat = base_mat or matrix

	local centre = self:getSelectionCentreAndMinMax()
	if not centre then
		error()
	end
	
	local __id = {
		1,0,0,0,
		0,1,0,0,
		0,0,1,0,
		0,0,0,1}
	for i=1,16 do
		__tempmat4A[i] = __id[i]
		__tempmat4B[i] = __id[i]
	end

	local centre_v = __tempvec3c
	local neg_centre_v = __tempvec3ci

	centre_v.x, centre_v.y, centre_v.z = centre[1],centre[2],centre[3]

	neg_centre_v.x = -centre_v.x
	neg_centre_v.y = -centre_v.y
	neg_centre_v.z = -centre_v.z

	local mat_a, mat_b = __tempmat4A, __tempmat4B
	mat_a:translate(mat_a, neg_centre_v)
	mat_b:translate(mat_b, centre_v)
	--cpml.mat4.mul(mat_a, base_mat, mat_a)
	cpml.mat4.mul(mat_a, base_mat, mat_a)
	cpml.mat4.mul(mat_a, mat_b, mat_a)

	--return mat_a, mat_b
	return mat_a, info
end

function ProvMapEdit:applyMapEditTransformOntoModel(model, trans, precomp_mat, precomp_info)
	local t_type = trans:getTransformType()
	local mat, info
	if precomp_mat and precomp_info then
		mat = precomp_mat
		info = precomp_info
	else
		mat, info = self:getSelectionTransformationModelMatrix(trans)
	end

	if t_type == "translate" then
		local trans_o = transobj:from(model)
		trans_o:applyMatrix(mat)
		trans_o:send(model)
	end

	if t_type == "rotate" then
		local trans_o = transobj:from(model)
		trans_o:applyMatrix(mat, {rot=true})
		trans_o:send(model)
	end

	if t_type == "scale" or t_type == "flip" then
		local trans_o = transobj:from(model)
		trans_o:applyMatrix(mat, {scale=true})
		trans_o:send(model)
	end

	self.__cache_recalc_selection_centre = true
end

function ProvMapEdit:applyMapEditTransformOntoDecal(decal, trans, _, precomp_info)
	local t_type = trans:getTransformType()
	local info = precomp_info or trans:getTransform(self.props.mapedit_cam)

	if t_type == "translate" then
		local x,y = love.mouse.getPosition()
		local obj,pos,norm = self:objectAtCursor(x,y,{tile=true,wall=true})
		if not obj or not norm then return end

		--[[
		local normal_x,normal_y,normal_z
		if obj[1]=="tile" then
			local T = obj[2]
			local x,z,vert_i = T.x,T.z,T.vert_i
			local start_i=self:getTilesIndexInMesh(x,z,vert_i)
			local nx,ny,nz = self.props.mapedit_map_mesh.mesh:getVertexAttribute(start_i,3)
			decal.decal.normal[1] = nx
			decal.decal.normal[2] = ny
			decal.decal.normal[3] = nz
		elseif obj[1] == "wall" then
			local W = obj[2]
			local x,z,side = W.x,W.z,W.side
			local start_i=self:getWallsIndexInMesh(x,z,side)
			local nx,ny,nz = self.props.mapedit_map_mesh.mesh:getVertexAttribute(start_i,3)
			decal.decal.normal[1] = nx
			decal.decal.normal[2] = ny
			decal.decal.normal[3] = nz
		end--]]
		decal.decal:setNormal(norm)

		--local pos = decal:getPosition()
		--[[decal:setPosition{
			pos[1]+info[1],
			pos[2]+info[2],
			pos[3]+info[3]
		}--]]
		decal:setPosition(pos)
	end

	if t_type == "rotate" then
		local angle = info.angle
		if not angle then
			local quat = info[1]
			angle = cpml.quat.to_angle_axis(quat)
		end
		local rot = decal:getRotation()
		decal:setRotation(rot + angle)
	end

	if t_type == "scale" or t_type == "flip" then
		local size = decal:getScale()
		decal:setScale{
			size[1]*info[1],
			size[2]*info[2],
			size[3]*info[3]
		}
	end
	
	self.__cache_recalc_selection_centre = true
end

function ProvMapEdit:applyMapEditTransformOntoTileVertex(tile_obj, trans, precomp_mat, precomp_info)
	local t_type = trans:getTransformType()
	local mat, info
	if precomp_mat and precomp_info then
		mat = precomp_mat
		info = precomp_info
	else
		mat, info = self:getTileTransformationMatrix(trans)
	end

	if t_type == "translate" then
		local trans_o = transobj:from(tile_obj)
		trans_o:applyMatrix(mat)
		trans_o:send(tile_obj)
	end

	if t_type == "rotate" then
		--local trans_o = transobj:from(tile_obj)
		--trans_o:applyMatrix(mat, {rot=true})
		--trans_o:send(tile_obj)
	end

	if t_type == "scale" or t_type == "flip" then
		--local trans_o = transobj:from(tile_obj)
		--trans_o:applyMatrix(mat, {scale=true})
		--trans_o:send(tile_obj)
	end
end

function ProvMapEdit:applyActiveTransformationFunction(objs)
	local trans = self.active_transform
	if not trans then return function() end end
	return self:applyTransformationFunction(objs, trans)
end

function ProvMapEdit:applyTransformationFunction(objs, trans)
	if next(objs) == nil then return function() end end
	if self:selectionEmpty() then return function() end end
	if not trans then return function() end end

	local mat,info = self:getSelectionTransformationModelMatrix(trans)
	local tile_mat,tile_info = self:getTileTransformationMatrix(trans)
	local generic_info = trans:getTransform(self.props.mapedit_cam)

	-- clone
	local __m_model = cpml.mat4.new()
	for i=1,16 do __m_model[i] = mat[i] end
	local __i_model = info
	local __m_tile = cpml.mat4.new()
	for i=1,16 do __m_tile[i] = tile_mat[i] end
	local __i_tile = tile_info

	return function()
		for i,v in ipairs(objs) do
			local o_type = v[1]
			if o_type == "model" then
				self:applyMapEditTransformOntoModel(v[2], trans, __m_model, __i_model)
			elseif o_type == "tile" then
				self:applyMapEditTransformOntoTileVertex(v[2], trans, __m_tile, __i_tile)
			elseif o_type == "decal" then
				self:applyMapEditTransformOntoDecal(v[2], trans, nil, generic_info)
			end
		end
	end
end

local __tempmat4T = cpml.mat4.new()
local __tempvec3T = cpml.vec3.new()
-- returns translation matrix
function ProvMapEdit:getTileTransformationMatrix(transform)
	local __id = {
		1,0,0,0,
		0,1,0,0,
		0,0,1,0,
		0,0,0,1}
	for i=1,16 do
		__tempmat4T[i] = __id[i]
	end

	local t_type = transform:getTransformType()

	-- the only valid type of transformation for tiles
	-- is a translation, return an identity matrix for
	-- anything inappropiate
	if t_type ~= "translate" then
		return __tempmat4T
	end

	local getScaleByDist = self.__getScaleByDist
	local g_scale=math.abs(TILE_HEIGHT*0.5)
	local int = math.floor
	local function granulate(v)
		if not self.granulate_transform then return v end
		v = int(v/g_scale)*g_scale
		return v
	end

	local t_vec = __tempvec3T
	local mat = __tempmat4T
	local int = math.floor
	local info = transform:getTransform(self.props.mapedit_cam)
	-- tiles can only move up and down
	local s = getScaleByDist(self)
	t_vec.x = 0
	t_vec.y = int(granulate(info[2])) * s
	t_vec.z = 0
	mat:translate(mat, t_vec)
	return mat, info
end

local __tileobj_mt = {
	getPosition = function(self)
		return ProvMapEdit:getTileVertex(self.x,self.z,self.vert_i)
	end,
	getDirection = function(self)
		return {0,0,-1,"dir"}
	end,
	getScale = function(self)
		return {1,1,1}
	end,

	setPosition = function(self, pos)
		ProvMapEdit:setTileVertex(self.x,self.z,self.vert_i,pos)
	end,
	setDirection = function(self, dir)
		-- do nothin
	end,
	setScale = function(self, scale)
		-- do nothing
	end,

	getTransformMode = function(self)
		return "component"
	end
}
__tileobj_mt.__index = __tileobj_mt
-- each tile has 4 vertices, i specifies which vertex going from 1 to 4
function ProvMapEdit:getTileVertexObject(x,z,i,overlay)
	if overlay then
		local obj = self.tilevertex_objs[z][x][i]
		if obj and obj.__overlay then return obj.__overlay end
	else
		local obj = self.tilevertex_objs[z][x][i]
		if obj then return obj end
	end

	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then return nil end
	assert(i>= 1 and i<=6, "ProvMapEdit:getTileVertexObject(): i out of range [1,6]")

	local tile = {
		x=x,
		z=z,
		vert_i=i,
		overlay=overlay
	}
	setmetatable(tile, __tileobj_mt)

	return tile
end

local __wallobj_mt = {
	--[[__eq = function(a,b)
		return a.x==b.x and
		       a.z==b.z and
					 a.side==b.side
	end--]]
	getPosition = function(self)
		return {0,0,0}
	end,
	getDirection = function(self)
		return {0,0,-1,"dir"}
	end,
	getScale = function(self)
		return {1,1,1}
	end,

	setPosition = function(self, pos)
		-- do nothing
	end,
	setDirection = function(self, dir)
		-- do nothin
	end,
	setScale = function(self, scale)
		-- do nothing
	end,

	getTransformMode = function(self)
		return "component"
	end
}
__wallobj_mt.__index = __wallobj_mt
function ProvMapEdit:getWallObject(x,z,side)
	local obj = self.wall_objs[z][x][side]
	if obj then return obj end

	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then return nil end
	assert(side>=1 and side<=5, "ProvMapEdit:getWallObject(): i out of range [1,5]")

	local mapedit = self
	local wall = {
		x=x,
		z=z,
		side=side,

		getPosition = function(self)
			return {0,0,0}
		end,
		getDirection = function(self)
			return {0,0,-1,"dir"}
		end,
		getScale = function(self)
			return {1,1,1}
		end,

		setPosition = function(self, pos)
			-- do nothing
		end,
		setDirection = function(self, dir)
			-- do nothin
		end,
		setScale = function(self, scale)
			-- do nothing
		end,

		getTransformMode = function(self)
			return "component"
		end
	}
	setmetatable(wall, __wallobj_mt)
	return wall
end

function ProvMapEdit:newCamera()
	self.props.mapedit_cam = Camera:new{
		["cam_position"] = {self.props.mapedit_map_width*0.5*TILE_SIZE, -128, self.props.mapedit_map_height*0.5*TILE_SIZE},
		["cam_bend_enabled"] = false,
		["cam_far_plane"] = 3000.0,
		["cam_fov"] = 75.0,
	}
end

function ProvMapEdit:centreCamOnPointMinMax(centre, min, max)
	if not (centre and min and max) then
		return false
	end

	local cam = self.props.mapedit_cam
	local dx,dy,dz = centre[1]-min[1] , centre[2]-min[2] , centre[3]-min[3]
	local dist = math.sqrt(dx*dx + dy*dy + dz*dz) + 100

	local cam_dir = cam:getDirection()
	local new_pos = {
		centre[1] - cam_dir[1] * dist,
		centre[2] - cam_dir[2] * dist,
		centre[3] - cam_dir[3] * dist
	}

	self.cam_move_to_pos = new_pos
	return true
end

function ProvMapEdit:centreCamOnPointDist(centre, dist)
	if not (centre and dist) then
		return false
	end

	local cam = self.props.mapedit_cam
	local dist = dist

	local cam_dir = cam:getDirection()
	local new_pos = {
		centre[1] - cam_dir[1] * dist,
		centre[2] - cam_dir[2] * dist,
		centre[3] - cam_dir[3] * dist
	}

	self.cam_move_to_pos = new_pos
	return true
end

-- this function first tries to centre on the current selection
-- if there is no selection, it tries to centre on where the cursor is
function ProvMapEdit:centreCamOnSelection()
	local centre,min,max = self:getSelectionCentreAndMinMax()
	if centre then
		self:centreCamOnPointMinMax(centre,min,max)
		self.rotate_cam_around_selection = true
		self.rotate_cam_point = centre
		return
	end

	local x,y = love.mouse.getPosition()
	local obj_at_cursor = self:objectAtCursor(x,y,{tile=true,wall=true,model=true,decal=true})
	if not obj_at_cursor then return end
	centre = self:getObjectCentre(obj_at_cursor)
	if not centre then return end
	self:centreCamOnPointDist(centre, 100)
	self.rotate_cam_around_selection = true
	self.rotate_cam_point = centre
end

function ProvMapEdit:getSelectionCentreAndMinMax()
	if not self.__cache_recalc_selection_centre then
		return self.__cache_selection_centre,
		       self.__cache_selection_min,
			   self.__cache_selection_max
	end
	self.__cache_recalc_selection_centre = false

	self.__cache_selection_centre, self.__cache_selection_min, self.__cache_selection_max =
		self:getObjectsCentreAndMinMax(self.active_selection, 
			self.__cache_selection_centre, self.__cache_selection_min, self.__cache_selection_max)
	return self.__cache_selection_centre, self.__cache_selection_min, self.__cache_selection_max
end

local __tempmint, __tempmaxt = {},{}
function ProvMapEdit:transformMinMax(min,max,matrix)
	local M = {min,max}
	local mul = cpml.mat4.mul_vec4
	local min,max=math.min,math.max
	local corner_i1 = {1,1,1,1,2,2,2,2}
	local corner_i2 = {1,1,2,2,1,1,2,2}
	local corner_i3 = {1,2,1,2,1,2,1,2}
	local min_x,min_y,min_z = 1/0, 1/0, 1/0
	local max_x,max_y,max_z =-1/0,-1/0,-1/0
	for i=1,8 do
		local corner = __tempmint
		corner[1] = M[corner_i1[i]][1]
		corner[2] = M[corner_i2[i]][2]
		corner[3] = M[corner_i3[i]][3]
		corner[4] = 1
		corner=mul(corner,matrix,corner)
		min_x,min_y,min_z = min(corner[1],min_x),min(corner[2],min_y),min(corner[3],min_z)
		max_x,max_y,max_z = max(corner[1],max_x),max(corner[2],max_y),max(corner[3],max_z)
	end
	__tempmint[1],__tempmint[2],__tempmint[3]=min_x,min_y,min_z
	__tempmaxt[1],__tempmaxt[2],__tempmaxt[3]=max_x,max_y,max_z
	return __tempmint,__tempmaxt
end

function ProvMapEdit:getObjectsCentreAndMinMax(objs, __c, __min, __max)
	local x,y,z = 0,0,0

	local min_x,min_y,min_z = 1/0,1/0,1/0
	local max_x,max_y,max_z = -1/0,-1/0,-1/0

	local min = math.min
	local max = math.max

	local count = 0
	for i,v in ipairs(objs) do
		local obj_type = v[1]

		local mx,my,mz

		local _min_x,_min_y,_min_z = 1/0,1/0,1/0
		local _max_x,_max_y,_max_z = -1/0,-1/0,-1/0

		local function get_min(v1,v2,v3,v4, i)
			local min = 1/0
			if v1[i] < min then min = v1[i] end
			if v2[i] < min then min = v2[i] end
			if v3[i] < min then min = v3[i] end
			if v4[i] < min then min = v4[i] end
			return min
		end
		local function get_max(v1,v2,v3,v4, i)
			local max = -1/0
			if v1[i] > max then max = v1[i] end
			if v2[i] > max then max = v2[i] end
			if v3[i] > max then max = v3[i] end
			if v4[i] > max then max = v4[i] end
			return max
		end

		if obj_type == "model" then
			local model = v[2]

			local min,max = model:getBoundingBoxMinMax()

			mx,my,mz = 
				(min[1] + max[1]) * 0.5,
				(min[2] + max[2]) * 0.5,
				(min[3] + max[3]) * 0.5
			_min_x, _min_y, _min_z = min[1],min[2],min[3]
			_max_x, _max_y, _max_z = max[1],max[2],max[3]
		elseif obj_type == "tile" then
			--local v1,v2,v3,v4 = self:getTileVerts(v[2],v[3])
			local v1,v2,v3,v4,v5,v6 = self:getTileVerts(v[2].x,v[2].z)
			mx = (v1[1]+v2[1]+v3[1]+v4[1])
			my = (v1[2]+v2[2]+v3[2]+v4[2])
			mz = (v1[3]+v2[3]+v3[3]+v4[3])
			if v5 then
				mx = mx+v5[1]+v6[1]
				my = my+v5[2]+v6[2]
				mz = mz+v5[3]+v6[3]
				mx=mx*(1/6)
				my=my*(1/6)
				mz=mz*(1/6)
			else
				mx=mx*0.25
				my=my*0.25
				mz=mz*0.25
			end

			_min_x, _min_y, _min_z = get_min(v1,v2,v3,v4,1),
			                         get_min(v1,v2,v3,v4,2),
			                         get_min(v1,v2,v3,v4,3)
			_max_x, _max_y, _max_z = get_max(v1,v2,v3,v4,1),
			                         get_max(v1,v2,v3,v4,2),
			                         get_max(v1,v2,v3,v4,3)
		elseif obj_type == "wall" then
			--local v1,v2,v3,v4 = self:getWallVerts(v[2],v[3],v[4])
			local v1,v2,v3,v4 = self:getWallVerts(v[2].x,v[2].z,v[2].side)
			mx = (v1[1]+v2[1]+v3[1]+v4[1]) * 0.25
			my = (v1[2]+v2[2]+v3[2]+v4[2]) * 0.25
			mz = (v1[3]+v2[3]+v3[3]+v4[3]) * 0.25
			_min_x, _min_y, _min_z = get_min(v1,v2,v3,v4,1),
			                         get_min(v1,v2,v3,v4,2),
			                         get_min(v1,v2,v3,v4,3)
			_max_x, _max_y, _max_z = get_max(v1,v2,v3,v4,1),
			                         get_max(v1,v2,v3,v4,2),
			                         get_max(v1,v2,v3,v4,3)
		elseif provtype(v) == "modelinstance" then
			local model = v
			local min,max = model:getBoundingBoxMinMax()
			mx,my,mz = 
				(min[1] + max[1]) * 0.5,
				(min[2] + max[2]) * 0.5,
				(min[3] + max[3]) * 0.5
			_min_x, _min_y, _min_z = min[1],min[2],min[3]
			_max_x, _max_y, _max_z = max[1],max[2],max[3]
		else
			local obj = v[2]
			local pos = obj:getPosition()
			mx,my,mz = pos[1],pos[2],pos[3]
			_min_x, _min_y, _min_z = pos[1],pos[2],pos[3]
			_max_x, _max_y, _max_z = pos[1],pos[2],pos[3]
		end

		x,y,z = x + mx, y + my, z + mz
		count = count + 1

		min_x = min(min_x, _min_x)
		min_y = min(min_y, _min_y)
		min_z = min(min_z, _min_z)
		max_x = max(max_x, _max_x)
		max_y = max(max_y, _max_y)
		max_z = max(max_z, _max_z)
	end

	if count == 0 then return nil end
	x = x / count
	y = y / count
	z = z / count
	local __c   = __c or {}
	local __min = __min or {}
	local __max = __max or {}
	__c[1],__c[2],__c[3] = x,y,z
	__min[1],__min[2],__min[3] = min_x,min_y,min_z
	__max[1],__max[2],__max[3] = max_x,max_y,max_z
	return __c, __min, __max
	--return {x,y,z},{min_x,min_y,min_z},{max_x,max_y,max_z}
end

function ProvMapEdit:copySelectionToClipboard()
	if self:selectionEmpty() then return end
	self.clipboard_paste_count = 0

	for i=#self.clipboard,1,-1 do
		self.clipboard[i]:releaseModel()
		table.remove(self.clipboard, i)
	end

	for i,v in ipairs(self.active_selection) do
		local o_type = v[1]
		if o_type == "model" then
			local model_clone = v[2]:clone()
			table.insert(self.clipboard, model_clone)
		end
	end
end

function ProvMapEdit:canCopy()
	return not self:selectionEmpty()
end

function ProvMapEdit:pasteClipboard()
	local objs
	local selection = {}
	objs = {}
	for i,v in ipairs(self.clipboard) do
		objs[i] = v:clone()
	end

	for i,v in ipairs(objs) do
		selection[i] = {"model",objs[i]}
	end

	--self:addModelInstance(objs)
	self:commitComposedCommand(
	 {"deselect_all", {}},
	 {"add_obj", {objects=objs}},
	 {"additive_select", {select_objects = selection}}
	)
end

function ProvMapEdit:canPaste()
	return #self.clipboard > 0
end

function ProvMapEdit:getObjectCentre(obj)
	assert(obj)
	local obj_type = obj[1]

	local mx,my,mz=0,0,0
	if obj_type == "model" then
		local count = #obj
		for i=2,count do
			local model = obj[i]
			local min,max = model:getBoundingBoxMinMax()

			mx,my,mz = 
				mx + (min[1] + max[1]) * 0.5,
				my + (min[2] + max[2]) * 0.5,
				mz + (min[3] + max[3]) * 0.5
		end
		mx=mx/(count-1)
		my=my/(count-1)
		mz=mz/(count-1)
		return {mx,my,mz}
	end
	if obj_type == "tile" then
		local v1,v2,v3,v4,v5,v6 = self:getTileVerts(obj[2].x,obj[2].z)
		mx = (v1[1]+v2[1]+v3[1]+v4[1]) 
		my = (v1[2]+v2[2]+v3[2]+v4[2]) 
		mz = (v1[3]+v2[3]+v3[3]+v4[3]) 
		if v5 then
			mx = mx+v5[1]+v6[1]
			my = my+v5[2]+v6[2]
			mz = mz+v5[3]+v6[3]
			mx=mx*(1/6)
			my=my*(1/6)
			mz=mz*(1/6)
		else
			mx=mx*0.25
			my=my*0.25
			mz=mz*0.25
		end
		return {mx,my,mz}
	end
	if obj_type == "wall" then
		--local v1,v2,v3,v4 = self:getWallVerts(obj[2],obj[3],obj[4])
		local v1,v2,v3,v4 = self:getWallVerts(obj[2].x,obj[2].z,obj[2].side)
		mx = (v1[1]+v2[1]+v3[1]+v4[1]) * 0.25
		my = (v1[2]+v2[2]+v3[2]+v4[2]) * 0.25
		mz = (v1[3]+v2[3]+v3[3]+v4[3]) * 0.25
		return {mx,my,mz}
	end
	if obj_type == "decal" then
		local pos=obj[2].pos
		return {pos[1],pos[2],pos[3]}
	end
end

local count = 0
function ProvMapEdit:update(dt)
	local cam = self.props.mapedit_cam
	local mode = self.props.mapedit_mode

	local nito = self.nito
	if nito then
		nito:updateAnimation(true)
	end

	gui:update(dt)
	self.viewport_input:poll()
	self.transform_input:poll()
	--self.cxtm_input:poll()
	self:interpCameraToPos(dt)
	cam:update()
	self:updateModelMatrices()

	self.granulate_transform = self.ctrl_modifier 

	self:updateTransformationMatrix()

	local map_mesh = self.props.mapedit_map_mesh
	if map_mesh and self.props.mapedit_enable_tex_anim then map_mesh:updateUvs() end

	self:updateNitori(dt)

	if self.selection_changed then
		self.selection_changed = false
		self.__cache_recalc_selection_centre = true
	end
end

function ProvMapEdit:updateTransformationMatrix()
	local trans = self.active_transform
	if not trans then return end
	local a = self:getSelectionTransformationModelMatrix(trans)
	local tile_a = self:getTileTransformationMatrix(trans)
	self.active_transform_model_mat_a = a
	self.active_transform_tile_mat_a = tile_a

	local shader = self.map_edit_shader
	shader:send("u_transform_a", "column", a)
	shader:send("u_mesh_transform_a", "column", tile_a)
end

function ProvMapEdit:isModelSelected(inst)
	for i,v in ipairs(self.active_selection) do
		--if v[1] == "model" and v[2] == inst then return true end
		if v[1] == "model" then
			for i=2,#v do
				if v[i] == inst then return true end
			end
		end
	end
	return false
end

local __tempwverts = {}
local __nilvert = {0,0,0,0,0,0,0,-1}
function ProvMapEdit:updateWallVerts(x,z)
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height

	local map_heights = self.props.mapedit_tile_heights
	local tile_shapes = self.props.mapedit_tile_shapes

	local function get_heights_triangle(x,z,direction)
		if x < 1 or x > w or z < 1 or z > h then
			return nil end

		local y = {}
		local tileh = map_heights[z][x]
		if type(tileh) == "table" then
			y[1],y[2],y[3],y[4],y[5],y[6] = tileh[1],tileh[2],tileh[3],tileh[4],tileh[5],tileh[6]
		else
			y[1],y[2],y[3],y[4],y[5],y[6] = tileh,tileh,tileh,tileh,tileh,tileh,tileh,tileh
		end

		local shape = tile_shapes[z][x]
		if shape == 0 then return y end
		if shape==1 then
			if direction=="north" or direction=="east" then
				y[1],y[3]=y[6] or y[4], y[5] or y[4] end
		elseif shape==2 then
			if direction=="north" or direction=="west" then
				y[4],y[2]=y[6] or y[3], y[5] or y[3] end
		elseif shape==3 then
			if direction=="south" or direction=="west" then
				y[1],y[3]=y[6] or y[2],y[5] or y[2] end
		else
			if direction=="south" or direction=="east" then
				y[4],y[2]=y[6] or y[1],y[5] or y[1] end
		end

		return y
	end

	local mesh = self.props.mapedit_map_mesh.mesh

	local tile_shape   = self.props.mapedit_tile_shapes[z][x]
	local tile_height  = get_heights_triangle ( x   , z   )
	local west_height  = get_heights_triangle ( x-1 , z   , "west")
	local south_height = get_heights_triangle ( x   , z+1 , "south")
	local east_height  = get_heights_triangle ( x+1 , z   , "east")
	local north_height = get_heights_triangle ( x   , z-1 , "north")

	local wall_info = Wall:getWallInfo(nil,
		tile_shape,
		tile_height,
		west_height,
		south_height,
		east_height,
		north_height)

	local function add_wall_verts(wall, side)
		local function get_wall_verts()
			if not wall then return nil end

			local wx,wy,wz = Tile.tileCoordToWorld(x,0,z)
			local u,v = Wall.u, Wall.v

			local function get_uv_v_max(side) 
				local m = -1/0
				for i=1,4 do m = math.max(side[i][2], m) end
				return m
			end

			local verts = __tempwverts
			if side == Wall.westi then
				if not wall.west then return nil end
				local vmax = get_uv_v_max(wall.west)
				for i=1,4 do
					local wallv = wall.west[i]
					verts[i] = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3]+1)*TILE_SIZE, u[i], wallv[2]-vmax,
														-1,0,0}
				end
			elseif side == Wall.southi then
				if not wall.south then return nil end
				local vmax = get_uv_v_max(wall.south)
				for i=1,4 do
					local wallv = wall.south[i]
					verts[i] = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3]+1)*TILE_SIZE, u[i], wallv[2]-vmax,
														0,0,1}
				end
			elseif side == Wall.easti then
				if not wall.east then return nil end
				local vmax = get_uv_v_max(wall.east)
				for i=1,4 do
					local wallv = wall.east[i]
					verts[i] = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3])*TILE_SIZE, u[i], wallv[2]-vmax,
														1,0,0}
				end
			elseif side == Wall.northi then
				if not wall.north then return nil end
				local vmax = get_uv_v_max(wall.north)
				for i=1,4 do
					local wallv = wall.north[i]
					verts[i] = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3])*TILE_SIZE, u[i], wallv[2]-vmax,
														0,0,-1}
				end
			elseif side == Wall.diagonali then
				if not wall.diagonal then return nil,nil,nil,nil end
				local vmax = get_uv_v_max(wall.diagonal)
				for i=1,4 do
					local wallv = wall.diagonal[i]
					verts[i] = {wx+(wallv[1])*TILE_SIZE,  wallv[2]*TILE_HEIGHT, -wz+(wallv[3])*TILE_SIZE, 1.0-u[i], wallv[2]-vmax,
														wall.diagonal_norm[1],wall.diagonal_norm[2],wall.diagonal_norm[3]}
				end
			end
			
			return verts
		end

		local verts = get_wall_verts()

		local mesh_index = self:getWallsIndexInMesh(x,z,side)

		if not verts then
			verts = __nilvert
			for i=0,3 do
				mesh:setVertex(mesh_index+i, verts)
			end
			self.props.mapedit_map_mesh.wall_exists[z][x][side] = false
		else
			for i=0,3 do
				mesh:setVertex(mesh_index+i, verts[i+1])
			end
			self.props.mapedit_map_mesh.wall_exists[z][x][side] = true
		end
	end

	add_wall_verts(wall_info,1)
	add_wall_verts(wall_info,2)
	add_wall_verts(wall_info,3)
	add_wall_verts(wall_info,4)
	add_wall_verts(wall_info,5)
end

function ProvMapEdit:interpCameraToPos(dt)
	local cam = self.props.mapedit_cam
	local pos = self.cam_move_to_pos
	if not pos then return end

	local cam_pos = cam:getPosition()

	local dx,dy,dz = pos[1]-cam_pos[1],pos[2]-cam_pos[2],pos[3]-cam_pos[3]
	if dx*dx + dy*dy + dz*dz < 1.0 then
		self.cam_move_to_pos = nil
	end

	local min = math.min
	local dt = min(dt*32.0,1.0)

	local new_pos = {
		cam_pos[1] + dx*dt,
		cam_pos[2] + dy*dt,
		cam_pos[3] + dz*dt}
	cam:setPosition(new_pos)
end

function ProvMapEdit:drawSkybox()
	local skybox_img = self.props.mapedit_skybox_img
	if not skybox_img then return false end

	Renderer.setupCanvasForSkybox()

	local sh = love.graphics.getShader()
	shadersend(sh, "skybox", skybox_img)
	shadersend(sh, "skybox_brightness", 1.0)
	self.props.mapedit_cam:pushToShader(sh)
	love.graphics.draw(Renderer.skybox_model)

	return true
end

local __id = cpml.mat4.new()
function ProvMapEdit:drawViewport()
	local map_mesh = self.props.mapedit_map_mesh
	local shader = self.map_edit_shader

	Renderer.clearDepthBuffer()

	local skybox_drawn = false
	if self.props.mapedit_skybox_enable then
		skybox_drawn = self:drawSkybox()
	end

	shadersend(shader,"u_solid_colour_enable", false) 
	love.graphics.origin()
	love.graphics.setCanvas{Renderer.scene_viewport,
		depthstencil = Renderer.scene_depthbuffer,
		depth=true, stencil=true}
	love.graphics.setDepthMode( "less", true  )
	love.graphics.setMeshCullMode("front")

	if not skybox_drawn then
		love.graphics.clear(27/255, 66/255, 140/255,1)
	end

	love.graphics.setShader(shader)
	love.graphics.setColor(1,1,1,1)

	local cam = self.props.mapedit_cam
	cam:pushToShader(shader)

	self:drawNitori(shader)
	
	shadersend(shader,"u_wireframe_colour", self.wireframe_col)
	shadersend(shader,"u_selection_colour", self.selection_col)
	shadersend(shader,"u_time",love.timer.getTime())

	if map_mesh then

		shadersend(shader,"u_model", "column", __id)
		shadersend(shader,"u_normal_model", "column", __id)
		shadersend(shader,"u_skinning", 0)
		map_mesh:pushAtlas( shader , true )

		-- draw culled faces with opacity
		love.graphics.setColor(1,1,1,0.8)
		love.graphics.setMeshCullMode("back")
		love.graphics.setDepthMode( "less", false  )
		self:invokeDrawMesh()
		love.graphics.setMeshCullMode("front")
		-- draw visible faces fully opaque
		love.graphics.setDepthMode( "lequal", true  )
		if self.props.mapedit_overlay_edit then
			love.graphics.setColor(1,1,1,0.8)
		else
			love.graphics.setColor(1,1,1,1)
		end
		love.graphics.draw(map_mesh.mesh)

		-- draw overlay
		map_mesh:attachOverlayAttributes()
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(map_mesh.mesh)
		map_mesh:attachAttributes()

		shadersend(shader,"u_uses_tileatlas", false)
		self:drawDecals(shader)

		love.graphics.setWireframe( true )
		shadersend(shader,"u_wireframe_enabled", true)
		--shadersend(shader,"u_uses_tileatlas", false)
		love.graphics.setDepthMode( "always", false  )
		self:invokeDrawMesh()
		shadersend(shader,"u_wireframe_enabled", false)

		love.graphics.setWireframe( false )
	end

	love.graphics.setDepthMode( "less", true  )
	self:drawSelectedHighlight()
	love.graphics.setDepthMode( "less", true  )

	love.graphics.setStencilTest()
	shadersend(shader,"u_solid_colour_enable", false) 
	self:drawModelsInViewport(shader)
	shadersend(shader,"u_uses_tileatlas", false)

	self:drawGroupBounds(shader)
end

function ProvMapEdit:invokeDrawMesh()
	local mesh = self.props.mapedit_map_mesh.mesh
	love.graphics.draw(mesh)
end

function ProvMapEdit:drawGroupBounds(shader)
	--if self.props.mapedit_mode ~= "viewport" then
	--	return
	--end

	love.graphics.setStencilTest()
	love.graphics.setDepthMode( "lequal", false  )
	love.graphics.setMeshCullMode("none")
	love.graphics.setWireframe( true )

	for i,group in ipairs(self.props.mapedit_model_groups) do
		local min,max = group.min,group.max
		local selected = self:isGroupSelected(group)
		if selected then
			local s_col = {self.selection_col[1]*0.8,
			               self.selection_col[2]*0.8,
			               self.selection_col[3]*0.8,
										 1.0}

			local skip = false
			if self.active_transform then
				local mat = self.active_transform_model_mat_a
				if mat then
					min,max = self:transformMinMax(min,max,mat)
				else
					skip = true
				end
			end
			if not skip then 
				guirender:draw3DCube(shader, min,max, self.selection_col, true, s_col)
			end
		else
			guirender:draw3DCube(shader, min,max, {196/255,107/255,255/255,0.5})
		end
	end
	love.graphics.setWireframe( false )
end

function ProvMapEdit:updateNitori(dt)
	self.nito_draw = false
	local nito = self.nito
	local a1,a2 = nito:getAnimator()
	if self.props.mapedit_mode == "transform" then
		--local tile,walls,models = self:getObjectTypesInSelection()
		--local exists = self:getObjectTypesInSelection()
		--if exists.wall or exists.tile then return end
		local ok = self:objectTypesSelectedLimit{"model"}
		if not ok then return end

		local c,min,max = self:getSelectionCentreAndMinMax()
		if not c then return end

		local x_dist = max[1]-min[1]
		local z_dist = max[3]-min[3]
		local height = max[2]-min[2]
		local y_off=0
		if height < 40 then
			y_off = 40-height
		end

		local mat = self.active_transform_model_mat_a
		if not mat then return end
		min,max = self:transformMinMax(min,max,mat)

		a1:playAnimation(self.nito_anim_push)
		a1:stopAnimation()
		local pos,dir
		if z_dist >= x_dist then
			pos = {max[1],  max[2]-2.5+y_off, (min[3]+max[3])*0.5}
			dir = {-1,0,0,"dir"}
			local a1 = nito:getAnimator()
			a1:setTime((-pos[1]-pos[3]*0.3)*1.4)
		else
			pos = {(max[1]+min[1])*0.5,  max[2]-2.5+y_off, min[3]}
			dir = {0,0,1,"dir"}
			local a1 = nito:getAnimator()
			a1:setTime((-pos[3]-pos[1]*0.3)*1.4)
		end

		nito:setPosition(pos)
		nito:setDirection(dir)
		nito:modelMatrix()
		self.nito_draw = true
	elseif self.props.mapedit_mode == "viewport" and self.props.mapedit_tool == "paint" then
		
		if self.__object_painted then
			if self.__object_painted[1] ~= "tile" then return end
			
			local time = self.__object_painted_time

			_________func = function(anim)
				local curr_time = getTickSmooth()
				if curr_time - self.__object_painted_time > (170-57+1)/1.7 then
					anim:stopAnimation()
					return
				end

				anim:playAnimation(self.nito_anim_paint, 57, 1.4, false, _________func)
			end

			local obj = self.__object_painted 
			local x,z,vert = obj[2].x, obj[2].z, obj[2].vert_i
			local y
			local heights = self.props.mapedit_tile_heights[z][x]
			if not heights then return end
			if type(heights) ~= "table" then
				y = heights
			else
				y = heights[vert]
			end

			local x,y,z = Tile.tileCoordToWorld(x,y,z)
			self.nito_pdest_x = x
			self.nito_pdest_y = y
			self.nito_pdest_z = z

			if not a1:isPlaying() then
				local curr_time = getTickSmooth()
				local anim_time = 0
				local anim_speed = 1.6
				if curr_time ~= time then anim_time = 57 anim_speed = 1.4 else
					nito:setPosition{x+TILE_SIZE*0.5,y,-z+TILE_SIZE*0.1}
					nito:setDirection{0,0,1,"dir"}
					nito:modelMatrix()
					a1:playAnimation(self.nito_anim_paint, anim_time, anim_speed, false, _________func)
				end
			else
				local curr_pos = nito:getPosition()
				local dx,dy,dz=curr_pos[1]-(x+TILE_SIZE*0.5),curr_pos[2]-y,curr_pos[3]-(-z+TILE_SIZE*0.35)
				local m = dt
				if m > 1.0 then m=1 end
				nito:setPosition{curr_pos[1]-dx*m*25, curr_pos[2]-dy*m*25,curr_pos[3]-dz*m*25}
				nito:setDirection{0,0,1,"dir"}
				nito:modelMatrix()
			end

			self.__object_painted = nil
			self.nito_draw = true
		else
			if a1:isPlaying() then
				self.nito_draw = true

				local curr_pos = nito:getPosition()
				local x,y,z=self.nito_pdest_x,self.nito_pdest_y,self.nito_pdest_z
				if x then
				local dx,dy,dz=curr_pos[1]-(x+TILE_SIZE*0.5),curr_pos[2]-y,curr_pos[3]-(-z+TILE_SIZE*0.1)
				local m = dt
					if m > 1.0 then m=1 end
				nito:setPosition{curr_pos[1]-dx*m*25, curr_pos[2]-dy*m*25,curr_pos[3]-dz*m*25}
				nito:setDirection{0,0,1,"dir"}
				nito:modelMatrix()
				end
			end
		end
	end
end

function ProvMapEdit:drawNitori(shader)
	if not self.nito_draw then return end

	local nito = self.nito
	if not nito then return end
	love.graphics.setDepthMode( "less", true  )
	love.graphics.setMeshCullMode("front")
	love.graphics.setColor(1,1,1,1)
	local stencil_func = function ()
		love.graphics.setColorMask( true,true,true,true )
		nito:draw(shader, true)
	end
	love.graphics.stencil(stencil_func, "replace", 1, false)
	love.graphics.setStencilTest("notequal", 1)
end

function ProvMapEdit:drawDecals(shader)
	love.graphics.setColor(1,1,1,1)
	love.graphics.setDepthMode( "lequal", true  )
	Renderer.enableDepthBias(shader,0.01)
	shadersend(shader,"u_model", "column", __id)
	shadersend(shader,"u_normal_model", "column", __id)
	shadersend(shader,"u_skinning", 0)
	shadersend(shader,"u_wireframe_enabled", false)
	shadersend(shader,"u_solid_colour_enable", false)
	shadersend(shader,"u_draw_as_contour", false)
	shadersend(shader,"u_wireframe_enabled", false)
	shadersend(shader,"u_global_coord_uv_enable", false)
	shadersend(shader,"u_highlight_pass", false)
	love.graphics.setBlendMode("alpha","alphamultiply")

	for i,v in ipairs(self.props.mapedit_decals) do
		local decal = v.decal
		love.graphics.setDepthMode( "lequal", true  )
		love.graphics.draw(decal.mesh)

		love.graphics.setDepthMode( "always", false )
		love.graphics.setWireframe( true )
		shadersend(shader,"u_wireframe_enabled", true)
		shadersend(shader,"u_wireframe_colour", {1,0,0,1})
		love.graphics.draw(decal.mesh)
		love.graphics.setWireframe( false )
		shadersend(shader,"u_wireframe_enabled", false)
		shadersend(shader,"u_wireframe_colour", self.wireframe_col)
	end

	local cam_pos = self.props.mapedit_cam:getPosition()

	love.graphics.setDepthMode( "always", false  )
	for i,v in ipairs(self.props.mapedit_decals) do
		local decal = v.decal
		local p  = v.box_pos
		local s = v.box_size
		local box_col  = v.box_col
		local box_border_col  = v.box_border_col

		local dx,dy,dz = cam_pos[1]-p[1],cam_pos[2]-p[2],cam_pos[3]-p[3]
		local dist = dx*dx + dy*dy + dz*dz
		if dist < 500*500 then
			love.graphics.setWireframe(true)
			guirender:draw3DCube(shader,p,{p[1]+s[1],p[2]+s[2],p[3]+s[3]},box_border_col,true,box_col,"fill")
			love.graphics.setWireframe(false)
		end
	end
	love.graphics.setDepthMode( "lequal", true  )
	shadersend(shader, "u_solid_colour_enable", false)

	Renderer.disableDepthBias(shader)
end

function ProvMapEdit:drawModelsInViewport(shader)
	local models = self.props.mapedit_model_insts

	local selected_models = {}
	for i,v in ipairs(self.active_selection) do
		if v[1] == "model" then
			selected_models[v[2]] = true
		end
	end

	local shader = shader or love.graphics.getShader()
	love.graphics.setColor(1,1,1,1)
	for i,v in ipairs(models) do
		if not selected_models[v] then
			shader:send("u_apply_a_transformation", false)
			v:draw(shader, false)
		else
			if self.active_transform then
				shader:send("u_apply_a_transformation", true)
			end

			love.graphics.setStencilTest()
			v:draw(shader, false)
			love.graphics.setStencilTest("notequal", 1)

			shadersend(shader, "u_solid_colour_enable", true)
			love.graphics.setDepthMode( "always", false  )
			love.graphics.setColor(self.selection_col)
			local mode, alphamode = love.graphics.getBlendMode()
			love.graphics.setBlendMode("screen","premultiplied")
			v:draw(shader, false)

			love.graphics.setColor(1,1,1,1)
			shadersend(shader, "u_solid_colour_enable", false)
			shadersend(shader,"u_wireframe_enabled", true)
			love.graphics.setWireframe( true )

			v:draw(shader, false)

			love.graphics.setDepthMode( "less", true  )
			shadersend(shader,"u_wireframe_enabled", false)
			love.graphics.setBlendMode(mode, alphamode)
			love.graphics.setWireframe( false )
		end
	end
	shader:send("u_apply_a_transformation", false)
end

function ProvMapEdit:updateModelMatrices(subset)
local subset = subset or self.props.mapedit_model_insts
for i,v in ipairs(subset) do
	v:modelMatrix()
	end
end

function ProvMapEdit:generateMeshHighlightAttributes( mesh )
	local mesh = mesh or self.props.mapedit_map_mesh.mesh

	local v_count = mesh:getVertexCount()
	local highlight_atype = {
		{"HighlightAttribute", "float", 1}
	}

	local verts = {}
	for i=1,v_count do
		verts[i] = {0.0}
	end

	self.highlight_mesh = love.graphics.newMesh(highlight_atype, verts, "triangles", "dynamic")
end

function ProvMapEdit:updateMeshTileHighlightAttribute(start_index, highlight_val)
	if highlight_val ~= 0.0 then highlight_val = 1.0 end
	local h_mesh = self.highlight_mesh
	if not h_mesh then return end
	
	for i=0,3 do
		h_mesh:setVertexAttribute(start_index+i, 1, highlight_val)
	end
end
function ProvMapEdit:updateMeshVertexHighlightAttribute(index, highlight_val)
	if highlight_val ~= 0.0 then highlight_val = 1.0 end
	local h_mesh = self.highlight_mesh
	if not h_mesh then return end
	
	h_mesh:setVertexAttribute(index, 1, highlight_val)
end

function ProvMapEdit:attachHighlightMesh()
	local h_mesh = self.highlight_mesh
	if not h_mesh then return end
	local mesh = self.props.mapedit_map_mesh.mesh
	mesh:attachAttribute("HighlightAttribute", h_mesh, "pervertex")
end
function ProvMapEdit:detachHighlightMesh()
	local mesh = self.props.mapedit_map_mesh.mesh
	mesh:attachAttribute("HighlightAttribute")
end

function ProvMapEdit:highlightTile(x,z, highlight_val)
	local i = self:getTilesIndexInMesh(x,z)
	if not i then return end

	local highlight_val = highlight_val or 1.0
	self:updateMeshTileHighlightAttribute(i, highlight_val)
end

function ProvMapEdit:highlightTileVertex(x,z, i, highlight_val)
	local index = self:getTilesIndexInMesh(x,z)
	if not index then return end

	local highlight_val = highlight_val or 1.0
	self:updateMeshVertexHighlightAttribute(index+i-1, highlight_val)
end

function ProvMapEdit:highlightWall(x,z, side, highlight_val)
	local i = self:getWallsIndexInMesh(x,z,side)
	if not i then return end

	local highlight_val = highlight_val or 1.0
	self:updateMeshTileHighlightAttribute(i, highlight_val)
end

function ProvMapEdit:highlightDecal(decal, highlight_val)
	if highlight_val == 0.0 then
		decal.box_col = self.decal_box_col
	else
		decal.box_col = self.decal_box_sel_col
	end
end

function ProvMapEdit:highlightObject(obj, highlight_val)
	local obj_type = obj[1]
	if obj_type == "tile" then
		self:highlightTileVertex(obj[2].x, obj[2].z, obj[2].vert_i, highlight_val)
	elseif obj_type == "wall" then
		self:highlightWall(obj[2].x, obj[2].z, obj[2].side, highlight_val)
	elseif obj_type == "decal" then
		self:highlightDecal(obj[2], highlight_val)
	end
end

function ProvMapEdit:selectionCount()
	return #self.active_selection
end

function ProvMapEdit:isSelectionEmpty()
	return self:selectionCount() == 0
end

function ProvMapEdit:isSelected(obj)
	for i,v in ipairs(self.active_selection) do
		if obj[2]==v[2] then return true end
	end
end

function ProvMapEdit:isGroupSelected(group)
	for i,v in ipairs(self.active_selection) do
		if v[1] == "model" then
			local model_inst = v[2]
			local g = self:isModelInAGroup(model_inst)
			if g == group then return true end
		end
	end
	return false
end

function ProvMapEdit:drawSelectedHighlight(shader)
	local shader = shader or love.graphics.getShader()
	shadersend(shader,"u_model", "column", __id)
	shadersend(shader,"u_normal_model", "column", __id)
	shadersend(shader,"u_solid_colour_enable", true)
	shadersend(shader,"u_highlight_pass", true)
	shadersend(shader,"u_uses_tileatlas", true)

	local mode, alphamode = love.graphics.getBlendMode()
	if self.active_transform then
		shader:send("u_apply_a_mesh_transformation", true)
		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.setColor(self.mesh_trans_col)
		love.graphics.setMeshCullMode("none")
	else
		love.graphics.setBlendMode("screen","premultiplied")
		love.graphics.setColor(self.selection_col)
	end

	love.graphics.setDepthMode( "always", false  )
	self:invokeDrawMesh()

	shader:send("u_apply_a_mesh_transformation", false)
	love.graphics.setBlendMode(mode, alphamode)
	shadersend(shader,"u_uses_tileatlas", false)
	love.graphics.setDepthMode( "less", true  )
	shadersend(shader,"u_highlight_pass", false)
	love.graphics.setColor(1,1,1,1)
	if self.active_transform then
		love.graphics.setMeshCullMode("front")
	end
end


function ProvMapEdit:draw()
	if self.props.mapedit_vision == "uv" then self.map_edit_shader:send("u_uv_vision", true)
	                                     else self.map_edit_shader:send("u_uv_vision", false) end
	if self.props.mapedit_vision == "normal" then self.map_edit_shader:send("u_normal_vision", true)
	                                         else self.map_edit_shader:send("u_normal_vision", false) end

	self:drawViewport()
	Renderer.renderScaledDefault()

	--love.graphics.reset()
	love.graphics.origin()
	love.graphics.setShader()
	love.graphics.setColor(1,1,1,1)
	love.graphics.setMeshCullMode("none")
	love.graphics.setDepthMode()
	love.graphics.setBlendMode("alpha")
	gui:draw()
end

local __tempdir = {}
function ProvMapEdit:mousemoved(x,y, dx,dy)
	local mode = self:getCurrentMode()
	if mode == "viewport" then
		self:viewport_mousemoved(x,y,dx,dy)
	elseif mode == "transform" then
		self:transform_mousemoved(x,y,dx,dy)
	end
end

function ProvMapEdit:viewport_mousemoved(x,y,dx,dy)
	if self.view_rotate_mode then
		if not self.rotate_cam_around_selection then
			self:rotateCameraByMouse(dx,dy)
		else
			local centre = self.rotate_cam_point
			self:rotateCameraByMouseAroundPoint(dx,dy, centre)
		end
	end
end

function ProvMapEdit:rotateCameraByMouse(dx,dy)
	local cam = self.props.mapedit_cam
	local dir = cam:getDirection()
	local scale = self.props.mapedit_cam_rotspeed
	local cos,sin = math.cos, math.sin
	local angle = atan3(dir[1], dir[3])

	local newdir = __tempdir
	newdir[1] = dir[1] - (cos(angle)*dx)*scale
	newdir[2] = dir[2] + dy*scale
	newdir[3] = dir[3] - (-sin(angle)*dx)*scale
	local length = math.sqrt(newdir[1]*newdir[1] + newdir[2]*newdir[2] + newdir[3]*newdir[3])
	if length == 0 then length = 1 end

	newdir[1] = newdir[1] / length
	newdir[2] = newdir[2] / length
	newdir[3] = newdir[3] / length

	cam:setDirection{
		newdir[1],
		newdir[2],
		newdir[3]}
end

function ProvMapEdit:rotateCameraByMouseAroundPoint(dx,dy, centre)
	-- get new camera direction
	local cam = self.props.mapedit_cam
	local dir = cam:getDirection()
	local scale = self.props.mapedit_cam_rotspeed
	local cos,sin = math.cos, math.sin
	local angle = atan3(dir[1], dir[3])

	local newdir = __tempdir
	newdir[1] = dir[1] - (cos(angle)*dx)*scale
	newdir[2] = dir[2] + dy*scale
	newdir[3] = dir[3] - (-sin(angle)*dx)*scale

	cam:setDirection(newdir)
	if not centre then return end
	
	-- move camera to new position, keeping the distance from selection centre
	-- the exact same
	local cam_pos = cam:getPosition()
	local dirn = cam:getDirection() -- same as newdir but normalized

	local dx,dy,dz = centre[1]-cam_pos[1],centre[2]-cam_pos[2],centre[3]-cam_pos[3]
	local length = math.sqrt(dx*dx + dy*dy + dz*dz)

	local newpos = {
		centre[1] - dirn[1] * length,
		centre[2] - dirn[2] * length,
		centre[3] - dirn[3] * length
	}

	cam:setPosition(newpos)
end

function ProvMapEdit:transform_mousemoved(x,y,dx,dy)
	local transform_mode = self.props.mapedit_transform_mode
	if transform_mode == "translate" then
	end
end

function ProvMapEdit:exportAndWriteToFile(filename)
	local result,log = export_map(self.props, self.props.mapedit_filename, {save_groups=true})

	love.filesystem.createDirectory("exports")

	if result then
		local fullpath = "exports/"..filename

		print(string.format("ProvMapEdit:exportAndWriteToFile(): exporting to %q",love.filesystem.getSaveDirectory() .. "/" .. fullpath))

		local file = love.filesystem.newFile(fullpath)
		local ok,err = file:open("w")
		if not ok then
			print(err)
			return false
		end

		ok,err = file:write(result)
		if not ok then
			print(err)
			file:close()
			return false
		end
		file:close()
		return true
	end
	return false
end

function ProvMapEdit:resize(w,h)
	gui:exitContextMenu()
end

function ProvMapEdit:setFileDropHook(hook_func)
	self.file_dropped_hook = hook_func
end

function ProvMapEdit:textureFileDropProcessor(file)
	local filename = file:getFilename()

	local function process_filename(str)
		local E = str:match(".*src[/\\]img[/\\](.*)")
		if not E then gui:displayPopup(str..lang[" is not in src/img/ folder."],5.8) return nil end
		return E
	end

	local img_fname = process_filename(filename)
	if not img_fname then return nil end
	img_fname = string.gsub(img_fname,"\\","/")

	local status, img = pcall(function() return Loader:getTextureReference(img_fname) end)
	if not status or not img then
		gui:displayPopup(str..lang[" failed to open."],4)
		return
	end

	self:addTexture(img_fname, img)
	gui:displayPopup(img_fname..lang[" success."],2)
	gui.texture_grid:update()
end
function ProvMapEdit:modelFileDropProcessor(file)
	local filename = file:getFilename()

	local function process_filename(str)
		local E = str:match(".*src[/\\]models[/\\](.*)")
		if not E then gui:displayPopup(str..lang[" is not in src/models/ folder."],5.8) return nil end
		return E
	end

	local mod_fname = process_filename(filename)
	if not mod_fname then return nil end
	mod_fname = string.gsub(mod_fname,"\\","/")

	local status, mod = pcall(function() return Models.loadModel(mod_fname) end)
	if not status or not mod then
		gui:displayPopup(str..lang[" failed to open."],4)
		return
	end

	self:addModelToList(mod)
	gui:displayPopup(mod_fname..lang[" success."],2)
	gui.model_grid:update()
end

function ProvMapEdit:filedropped(file)
	local hook = self.file_dropped_hook
	if hook then
		hook(file)
	end
end

function ProvMapEdit:keypressed(key,scancode,isrepeat)
	gui:keypressed(key,scancode,isrepeat)
end

function ProvMapEdit:textinput(t)
	gui:textinput(t)
end
