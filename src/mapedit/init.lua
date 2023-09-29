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

ProvMapEdit = {

	props = nil,

	map_edit_shader = nil,

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
	wall_objs = {}
}
ProvMapEdit.__index = ProvMapEdit

function ProvMapEdit:load(args)
	SET_ACTIVE_KEYBINDS(MAPEDIT_KEY_SETTINGS)
	if not self.map_edit_shader then
		self.map_edit_shader = love.graphics.newShader("shader/mapedit.glsl") end
	
	local lvledit_arg = args["lvledit"]
	assert(lvledit_arg and lvledit_arg[1], "ProvMapEdit:load(): no level specified in lvledit launch argument")

	self.props = MapEditPropPrototype()

	local map_name = lvledit_arg[1]
	self:loadMap(map_name)

	self:newCamera()
	self:setupInputHandling()
	self:enterViewportMode()
	self:defineCommands()
	gui:init(self)
end

function ProvMapEdit:unload()
	CONTROL_LOCK.MAPEDIT_VIEW.close()
	CONTROL_LOCK.MAPEDIT_TRANSFORM.close()
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
		  gen_newvert_buffer = true, keep_textures=true} )
	if map_mesh then
		self.props.mapedit_map_mesh = map_mesh
	else
		error(string.format("ProvMapEdit:load(): %s failed to load", fullpath))
	end
	self:generateMeshHighlightAttributes()
	self:attachHighlightMesh()

	local skybox_img, skybox_fname, skybox_brightness = Map.generateSkybox( map_file )
	if skybox_img then
		self.props.mapedit_skybox_img = skybox_img
	end

	local models = Map.generateModelInstances( map_file, true )
	self.props.mapedit_model_insts = models

	self:copyPropsFromMap(map_file)
	self:allocateObjects()
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
	clone(props.mapedit_tile_map, map_file.tile_map)
	clone(props.mapedit_wall_map, map_file.wall_map)
	clone(props.mapedit_anim_tex, map_file.anim_tex)
	clone(props.mapedit_skybox, map_file.skybox)
end

function ProvMapEdit:allocateObjects()
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	for z=1,h do
		self.tilevertex_objs[z]={}
		self.wall_objs[z] = {}
		for x=1,w do
			self.tilevertex_objs[z][x]={}
			self.wall_objs[z][x]={}
			for i=1,4 do
				self.tilevertex_objs[z][x][i]=self:getTileVertexObject(x,z,i)
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
					if v == u then
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
						if v == u then
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
		 {"transform_function", nil, nil, nil}
		},
		function(props) -- command function
			local groups = {}
			local calc_mem = props.memory[1] == nil
			for i,v in ipairs(props.select_objects) do
				local o_type = v[1]

				if calc_mem then -- if memory hasn't been calculated yet
					props.memory[i] = transobj:from(v[2])
				end
					
				if o_type == "model" then
					local g = self:isModelInAGroup(v[2])
					if g then add_to_set(groups,g) end
				end
			end

			if not props.transform_function then
				--props.transform_function = self:applyActiveTransformationFunction(props.select_objects)
				props.transform_function = self:applyTransformationFunction(props.select_objects, props.transform_info)
			end
			props.transform_function()

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
			props.created_group = self:createModelGroup("Group",models)
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
				if v[1] == "model" then
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
				if v[1] == "model" then
					local old_trans = props.memory[i]
					old_trans:send(v[2])
				end
			end
		end -- undo command function
	)

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
										   "cam_zoom_in","cam_zoom_out",
										   {"super",CONTROL_LOCK.META},{"toggle_anim_tex",CONTROL_LOCK.META},{"ctrl",CONTROL_LOCK.META},{"alt",CONTROL_LOCK.META},

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
	local viewport_select = Hook:new(function ()
		local x,y = love.mouse.getPosition()
		local obj = self:objectAtCursor( x,y , true, true, true)

		if not obj then self:deselectSelection() return end

		if not self.super_modifier then
			self:commitCommand("invertible_select", {select_objects={self:decomposeObject(obj)}})
			additive_select_obj = obj
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
						--table.insert(objs_in_range, {"tile",x,z})
						table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,1)})
						table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,2)})
						table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,3)})
						table.insert(objs_in_range, {"tile",self:getTileVertexObject(x,z,4)})
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
	end)
	self.viewport_input:getEvent("edit_select","down"):addHook(viewport_select)

	local viewport_deselect = Hook:new(function ()
		if not self:selectionEmpty() then
			self:viewportRightClickAction()
		end
	end)
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

	self.viewport_input:getEvent("edit_undo","down"):addHook(viewport_undo)
	self.viewport_input:getEvent("edit_redo","down"):addHook(viewport_redo)
	self.viewport_input:getEvent("super", "down"):addHook(enable_super_hook)
	self.viewport_input:getEvent("super", "up"):addHook(disable_super_hook)
	self.viewport_input:getEvent("ctrl", "down"):addHook(enable_ctrl_hook)
	self.viewport_input:getEvent("ctrl", "up"):addHook(disable_ctrl_hook)
	self.viewport_input:getEvent("alt", "down"):addHook(enable_alt_hook)
	self.viewport_input:getEvent("alt", "up"):addHook(disable_alt_hook)
	self.viewport_input:getEvent("toggle_anim_tex", "up"):addHook(toggle_anim_tex)

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

	local tile_selected, wall_selected, model_selected = self:getObjectTypesInSelection()

	if transform_mode ~= "translate" and (tile_selected or wall_selected) then
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
	self.active_transform = maptransform:newTransform(transform_mode)
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
		for i,v in ipairs(self.insts) do
			if inst == v then return true end
		end
		return false
	end,

	addToGroup = function(self, inst)
		for i,v in ipairs(self.insts) do
			if inst == v then return end
		end
		table.insert(self.insts, inst)
	end,

	removeFromGroup = function(self, inst)
		for i,v in ipairs(self.insts) do
			if inst == v then
				table.remove(self.insts, i)
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

		centre = {0,0,0},
		min = {0,0,0},
		max = {0,0,0},
	}
	for i,v in ipairs(insts) do
		if not self:isModelInAGroup(v) then
			table.insert(group.insts, v)
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
	local name = name or "Group"
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
		print(#group.insts)
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

-- returns either nil, or {"tile",x,z}, {"wall",x,z,side}, {"model", model_i, ...}
-- it may return multiple models in case a model group is clicked
function ProvMapEdit:objectAtCursor(x, y, test_tiles, test_walls, test_models)
	local unproject = cpml.mat4.unproject

	local cam = self.props.mapedit_cam
	local viewproj = cam:getViewProjMatrix()
	local vw,vh = love.window.getMode()
	local viewport_xywh = {0,0,vw,vh}

	local cursor_v = cpml.vec3.new(x,y,1)
	local cam_pos = cpml.vec3.new(cam:getPosition())
	local unproject_v = unproject(cursor_v, viewproj, viewport_xywh)
	--local ray_dir_v = cpml.vec3.new(cam:getDirection())
	local ray = {position=cam_pos, direction=cpml.vec3.normalize(unproject_v - cam_pos)}
	--print("ray_v", ray.position)
	--print("ray_dir_v", ray.direction)

	local min_dist = 1/0
	local mesh_test = nil
	-- test against map mesh
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height

	if test_tiles then
		for z=1,h do
			for x=1,w do
				local intersect, dist, verts = self:testTileAgainstRay(ray, x,z, self.alt_modifier)
				if intersect and dist < min_dist then
					if not self.alt_modifier then
						mesh_test = {"tile",
												 self:getTileVertexObject(x,z,1),
												 self:getTileVertexObject(x,z,2),
												 self:getTileVertexObject(x,z,3),
												 self:getTileVertexObject(x,z,4)
												 }
					else
						mesh_test = {"tile"}
						for i,v in ipairs(verts) do
							mesh_test[i+1] = self:getTileVertexObject(x,z,v)
						end
					end
					min_dist = dist
				end
			end
		end
	end

	if test_walls then
		for z=1,h do
			for x=1,w do
				local intersect, dist = self:testWallSideAgainstRay(ray, x,z, 1)
				if intersect and dist < min_dist  then
					mesh_test = {"wall",self:getWallObject(x,z,1)}
					min_dist = dist
				end
				intersect, dist = self:testWallSideAgainstRay(ray, x,z, 2)
				if intersect and dist < min_dist  then
					mesh_test = {"wall",self:getWallObject(x,z,2)}
					min_dist = dist
				end
				intersect, dist = self:testWallSideAgainstRay(ray, x,z, 3)
				if intersect and dist < min_dist  then
					mesh_test = {"wall",self:getWallObject(x,z,3)}
					min_dist = dist
				end
				intersect, dist = self:testWallSideAgainstRay(ray, x,z, 4)
				if intersect and dist < min_dist  then
					mesh_test = {"wall",self:getWallObject(x,z,4)}
					min_dist = dist
				end
			end
		end
	end

	if test_models then
		for i,model in ipairs(self.props.mapedit_model_insts) do
			local intersect, dist = self:testModelAgainstRay(ray, model)
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
	end

	return mesh_test
end

local __tempv1,__tempv2,__tempv3,__tempv4 = cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new()
local __temptri1, __temptri2 = {},{}
local __tempt1,__tempt2,__tempt3,__tempt4 = {0,0,0},{0,0,0},{0,0,0},{0,0,0}
local __results_t = {{1},{2},{3},{4},{1,2},{2,3},{3,4},{4,1}}
-- returns false
--         true, dist
--         true, dist, verts
-- where verts is a table containing at least one of [1,2,3,4], corresponding
-- to the nearest vertices/edge selected, if vert_test argument is true
function ProvMapEdit:testTileAgainstRay(ray, x,z, vert_test)
	local ray_triangle = cpml.intersect.ray_triangle
	local v1,v2,v3,v4 = self:getTileVerts(x,z)
	local V1,V2,V3,V4 = __tempv1, __tempv2, __tempv3, __tempv4
	V1.x,V1.y,V1.z = v1[1],v1[2],v1[3]
	V2.x,V2.y,V2.z = v2[1],v2[2],v2[3]
	V3.x,V3.y,V3.z = v3[1],v3[2],v3[3]
	V4.x,V4.y,V4.z = v4[1],v4[2],v4[3]

	__temptri1[1], __temptri1[2], __temptri1[3] = V1, V2, V3
	__temptri2[1], __temptri2[2], __temptri2[3] = V3, V4, V1

	local intersect1, dist1 = ray_triangle(ray, __temptri1, false) 
	local intersect2, dist2 = ray_triangle(ray, __temptri2, false)

	local dist = nil
	local intersect = intersect1 or intersect2
	if intersect1 and intersect2 then
		dist = math.min(dist1,dist2)
	else
		dist = dist1 or dist2
	end

	local verts_t = nil
	if vert_test and intersect then
		local function length(v1,V) 
			local x = v1[1]-V.x
			local y = v1[2]-V.y
			local z = v1[3]-V.z
			return math.sqrt(x*x + y*y + z*z)
		end
		local edge1,edge2,edge3,edge4 = __tempt1,__tempt2,__tempt3,__tempt4
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

		local v1d = length(v1,intersect)
		local v2d = length(v2,intersect)
		local v3d = length(v3,intersect)
		local v4d = length(v4,intersect)
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
		--local __results_t = {{1},{2},{3},{4},{1,2},{2,3},{3,4},{4,1}}
		verts_t = __results_t[min_i]
	end

	return intersect, dist, verts_t
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

	local dist = nil
	local intersect = intersect1 or intersect2
	if intersect1 and intersect2 then
		dist = math.min(dist1,dist2)
	else
		dist = dist1 or dist2
	end

	return intersect, dist
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

	local tile,wall,model = self:getObjectTypesInSelection(self.active_selection)
	local obj = self:objectAtCursor( x,y , tile,wall,model )

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

	self:openSelectionContextMenu(model,tile,wall)
end

function ProvMapEdit:getSelectionContextMenu()
	local tile,wall,model = self:getObjectTypesInSelection(self.active_selection)
	if model and not tile and not wall then
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

	local tile_exists   = false
	local wall_exists   = false
	local models_exists = false
	for i,v in ipairs(selection) do
		if     v[1] == "tile"  then tile_exists = true
		elseif v[1] == "wall"  then wall_exists = true
		elseif v[1] == "model" then models_exists = true
		else error()
		end

		-- prematurely break if all types already found
		if tile_exists and wall_exists and models_exists then break end
	end
	return tile_exists, wall_exists, models_exists
end

function ProvMapEdit:getTilesIndexInMesh( x,z )
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then
		return nil end

	local vmap = self.props.mapedit_map_mesh.tile_vert_map
	local index = vmap[z][x]
	return index
end

function ProvMapEdit:getTileVerts( x,z )
	local index = self:getTilesIndexInMesh( x,z )
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

function ProvMapEdit:getTileVertex( x,z , vert_i )
	local index = self:getTilesIndexInMesh( x,z )
	if not index then return nil end
	assert(vert_i==1 or vert_i==2 or vert_i==3 or vert_i==4)

	local mesh = self.props.mapedit_map_mesh.mesh
	local x,y,z = mesh:getVertexAttribute( index+vert_i-1, 1 )

	return
		{x,y,z}
end

function ProvMapEdit:setTileVertex( x,z , vert_i , pos )
	local index = self:getTilesIndexInMesh( x,z )
	if not index then
		return false end
	assert((vert_i==1 or vert_i==2 or vert_i==3 or vert_i==4) and pos)

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

	assert(side==1 or side==2 or side==3 or side==4)
	local wmap = self.props.mapedit_map_mesh.wall_vert_map
	local index = wmap[z][x][side]
	return index
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

local __temphtable = {0,0,0,0}
function ProvMapEdit:updateTileVerts(x,z)
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then return end

	-- update mesh and surrounding walls
	local mesh = self.props.mapedit_map_mesh.mesh
	local index = self:getTilesIndexInMesh(x,z)
	local heights = __temphtable
	--local heights = {0,0,0,0}
	for i=0,3 do
		local x,y,z = mesh:getVertexAttribute(index+i, 1)
		y = y / TILE_HEIGHT
		heights[i+1] = y
	end

	local tile_heights = self.props.mapedit_tile_heights
	local stored_heights = tile_heights[z][x]
	if type(stored_heights) ~= "table" then
		tile_heights[z][x] = {unpack(heights)}
	else
		for i=1,4 do
			stored_heights[i]=heights[i]
		end
	end
end

function ProvMapEdit:updateTileVertex(x,z,i, _x,_y,_z)
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or z<1 or z>h then return end
	assert(i==1 or i==2 or i==3 or i==4)

	-- update mesh and surrounding walls
	local mesh = self.props.mapedit_map_mesh.mesh
	local index = self:getTilesIndexInMesh(x,z)
	local X,Y,Z
	if _z then
		X,Y,Z = _x,_y,_z
	else
		X,Y,Z = mesh:getVertexAttribute(index+i, 1)
	end
	local height = Y / TILE_HEIGHT

	local tile_heights = self.props.mapedit_tile_heights
	local stored_heights = tile_heights[z][x]
	if type(stored_heights) ~= "table" then
		local h = stored_heights
		local t = {0,0,0,0}
		for j=1,4 do
			t[j] = h
		end
		t[i] = height

		tile_heights[z][x] = t
	else
		stored_heights[i]=height
	end
end
-- returns a table of x-indices and z-indices
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

-- returns a table of x-indices and z-indices
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

function ProvMapEdit:updateSelectedTileWalls(objs)
	local x_t,z_t = self:getSelectedTilesFromObjs_expanded(objs)
	for i,x in ipairs(x_t) do
		local z=z_t[i]
		self:updateWallVerts(x,z)
	end
end

function ProvMapEdit:translateTileVerts(x,z, height_t)
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or y<1 or y>h then return end
	local tile_heights = self.props.mapedit_tile_heights

	if nh_arg_type == "table" then
		assert(#new_heights == 4)
		for i=1,4 do
			height_info[i] = new_heights[i]
		end
		tile_heights[z][x] = height_info
	-- if argument is only 1 number, treat it as the height for all vertices
	elseif nh_arg_type == "number" then
		for i=1,4 do
			height_info = new_heights
		end
	else
		error(string.format("ProvMapEdit:editTileVerts: invalid new_heights argument, expected table/string got %s", nh_arg_type))
	end
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
	--local t_type = transform:getTransformType()
	local t_type = info.type

	--[[local function getScaleByDist()
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
	end--]]
	local getScaleByDist = self.__getScaleByDist

	local __id = {
		1,0,0,0,
		0,1,0,0,
		0,0,1,0,
		0,0,0,1}
	for i=1,16 do
		__tempmat4tt[i] = __id[i]
	end

	local mat = __tempmat4tt
	if t_type == "translate" then

		local int = math.floor
		local g_scale=8
		local function granulate(v)
			if not self.granulate_transform then return v end
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
		granulate(translate)
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
			else
				
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
	--[[__eq = function(a,b)
		return a.x==b.x and
		       a.z==b.z and
					 a.vert_i==b.vert_i
	end--]]

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
function ProvMapEdit:getTileVertexObject(x,z,i)
	local obj = self.tilevertex_objs[z][x][i]
	if obj then return obj end

	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	--print(x,z,i,w,h)
	if x<1 or x>w or z<1 or z>h then return nil end
	assert(i==1 or i==2 or i==3 or i==4, "ProvMapEdit:getTileVertexObject(): i out of range [1,4]")

	local mapedit = self
	local tile = {
		x=x,
		z=z,
		vert_i=i,
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
	local obj = self.wall_objs[z][x][i]
	if obj then return obj end

	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	--print(x,z,i,w,h)
	if x<1 or x>w or z<1 or z>h then return nil end
	assert(side==1 or side==2 or side==3 or side==4, "ProvMapEdit:getWallObject(): i out of range [1,4]")

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

	print(dist)

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
	local obj_at_cursor = self:objectAtCursor(x,y,true,true,true)
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
			local v1,v2,v3,v4 = self:getTileVerts(v[2].x,v[2].z)
			mx = (v1[1]+v2[1]+v3[1]+v4[1]) * 0.25
			my = (v1[2]+v2[2]+v3[2]+v4[2]) * 0.25
			mz = (v1[3]+v2[3]+v3[3]+v4[3]) * 0.25

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
			error()
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
	elseif obj_type == "tile" then
		--local v1,v2,v3,v4 = self:getTileVerts(obj[2],obj[3])
		local v1,v2,v3,v4 = self:getTileVerts(obj[2].x,obj[2].z)
		mx = (v1[1]+v2[1]+v3[1]+v4[1]) * 0.25
		my = (v1[2]+v2[2]+v3[2]+v4[2]) * 0.25
		mz = (v1[3]+v2[3]+v3[3]+v4[3]) * 0.25
	elseif obj_type == "wall" then
		--local v1,v2,v3,v4 = self:getWallVerts(obj[2],obj[3],obj[4])
		local v1,v2,v3,v4 = self:getWallVerts(obj[2].x,obj[2].z,obj[2].side)
		mx = (v1[1]+v2[1]+v3[1]+v4[1]) * 0.25
		my = (v1[2]+v2[2]+v3[2]+v4[2]) * 0.25
		mz = (v1[3]+v2[3]+v3[3]+v4[3]) * 0.25
	else
		error()
	end
	return {mx,my,mz}
end

local count = 0
function ProvMapEdit:update(dt)
	local cam = self.props.mapedit_cam
	local mode = self.props.mapedit_mode

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
	local function get_heights(x,z)
		if x<1 or x>w or z<1 or z>h then return nil end
		local ht = map_heights[z][x]

		if type(ht) == "number" then
			return {ht,ht,ht,ht}
		else
			return ht
		end
	end

	local mesh = self.props.mapedit_map_mesh.mesh

	local tile_height  = get_heights ( x   , z   )
	local west_height  = get_heights ( x-1 , z   )
	local south_height = get_heights ( x   , z+1 )
	local east_height  = get_heights ( x+1 , z   )
	local north_height = get_heights ( x   , z-1 )

	local wall_info = Wall:getWallInfo(nil,
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

		--local tex_norm_id = (tex_id-1) -- this will be the index sent to the shader

		--local tex_height = textures[tex_id]:getHeight() / TILE_HEIGHT

		--local attr = { 1.0, tex_height, 0.0, 0.0, tex_norm_id }
		--for i=1,4 do
		--	attr_verts[attr_count + i] = attr
		--end
		--attr_count = attr_count + 4
	end

	add_wall_verts(wall_info,1)
	add_wall_verts(wall_info,2)
	add_wall_verts(wall_info,3)
	add_wall_verts(wall_info,4)
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

	love.graphics.origin()
	love.graphics.setCanvas{Renderer.scene_viewport,
		depthstencil = Renderer.scene_depthbuffer,
		depth=true, stencil=false}
	love.graphics.setDepthMode( "less", true  )
	love.graphics.setMeshCullMode("front")

	if not skybox_drawn then
		love.graphics.clear(27/255, 66/255, 140/255,1)
	end

	love.graphics.setShader(shader)
	love.graphics.setColor(1,1,1,1)

	local cam = self.props.mapedit_cam
	cam:pushToShader(shader)
	
	shadersend(shader,"u_wireframe_colour", self.wireframe_col)
	shadersend(shader,"u_selection_colour", self.selection_col)
	shadersend(shader,"u_time",love.timer.getTime())

	if map_mesh then

		shadersend(shader,"u_model", "column", __id)
		shadersend(shader,"u_normal_model", "column", __id)
		shadersend(shader,"u_skinning", 0)
		map_mesh:pushAtlas( shader , true )

		-- draw culled faces with opacity
		love.graphics.setColor(1,1,1,0.9)
		love.graphics.setMeshCullMode("back")
		love.graphics.setDepthMode( "less", false  )
		self:invokeDrawMesh()
		love.graphics.setMeshCullMode("front")
		-- draw visible faces fully opaque
		love.graphics.setDepthMode( "less", true  )
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(map_mesh.mesh)


		love.graphics.setWireframe( true )
		shadersend(shader,"u_wireframe_enabled", true)
		shadersend(shader,"u_uses_tileatlas", false)
		love.graphics.setDepthMode( "always", false  )
		self:invokeDrawMesh()
		shadersend(shader,"u_wireframe_enabled", false)

		love.graphics.setWireframe( false )

	end

	self:drawSelectedHighlight()
	love.graphics.setDepthMode( "less", true  )
	self:drawModelsInViewport(shader)
	shadersend(shader,"u_uses_tileatlas", false)

	self:drawGroupBounds(shader)
end

function ProvMapEdit:invokeDrawMesh()
	local mesh = self.props.mapedit_map_mesh.mesh
	love.graphics.draw(mesh)
end

function ProvMapEdit:drawGroupBounds(shader)
	if self.props.mapedit_mode ~= "viewport" then
		return
	end

	love.graphics.setDepthMode( "lequal", false  )
	love.graphics.setMeshCullMode("none")
	love.graphics.setWireframe( true )

	for i,group in ipairs(self.props.mapedit_model_groups) do
		local min,max = group.min,group.max
		--guirender:draw3DCube(shader, min,max, {196/255,107/255,255/255,1.0}, true, {196/255,107/255,255/255,0.05})
		local selected = self:isGroupSelected(group)
		if selected then
			local s_col = {self.selection_col[1]*0.8,
			               self.selection_col[2]*0.8,
			               self.selection_col[3]*0.8,
										 1.0}
			guirender:draw3DCube(shader, min,max, self.selection_col, true, s_col)
		else
			guirender:draw3DCube(shader, min,max, {196/255,107/255,255/255,0.5})
		end
	end
	love.graphics.setWireframe( false )
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

			v:draw(shader, false)
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

function ProvMapEdit:highlightObject(obj, highlight_val)
	local obj_type = obj[1]
	if obj_type == "tile" then
		self:highlightTileVertex(obj[2].x, obj[2].z, obj[2].vert_i, highlight_val)
	elseif obj_type == "wall" then
		self:highlightWall(obj[2].x, obj[2].z, obj[2].side, highlight_val)
	end
end

function ProvMapEdit:selectionCount()
	return #self:selectionCount()
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

function ProvMapEdit:resize(w,h)
	gui:exitContextMenu()
end
