require "props/mapeditprops"

require "map"
require "camera"
require "render"
require "angle"
require "assetloader"

local maptransform = require "mapedittransform"
local shadersend   = require "shadersend"
local cpml         = require "cpml"
local transobj     = require "transobj"

local guirender   = require 'mapeditguidraw'
local contextmenu = require 'mapeditcontext'
local popup       = require 'mapeditpopup'

require "mapeditcommand"

ProvMapEdit = {

	props = nil,

	map_edit_shader = nil,

	viewport_input = nil,
	transform_input = nil,

	view_rotate_mode = false,
	grabbed_mouse_x = 0,
	grabbed_mouse_y = 0,

	commands = {},
	context_menus = {},

	wireframe_col = {19/255,66/255,72/255,0.8},
	selection_col = {255/255,161/255,66/255,1.0},

	active_selection = {},
	highlight_mesh = nil,

	active_transform = nil,
	active_transform_mesh_mat = nil,
	active_transform_model_mat_a = nil,
	active_transform_model_mat_b = nil,

	-- if non-nil, the camera will fly over to cam_move_to_pos coordinate
	-- and rotate its direction to cam_rot_to_dir
	cam_move_to_pos = nil,
	--cam_rot_to_dir  = nil -- not implemented
	--
	__cache_selection_centre = nil,
	__cache_selection_min = nil,
	__cache_selection_max = nil,
	__cache_recalc_selection_centre = false,

	selection_changed = false,

	rotate_cam_around_selection = false,
	rotate_cam_point = nil,

	super_modifier = false,
	ctrl_modifier  = false,

	curr_context_menu = nil,
	curr_popup = nil,

	clipboard = {}

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

	guirender:initAssets()

	self:newCamera()
	self:setupInputHandling()
	self:enterViewportMode()
	self:defineCommands()
	self:defineContextMenus()
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
		  gen_newvert_buffer = true} )
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
end

function ProvMapEdit:copyPropsFromMap(map_file)
	local function clone(dest, t, clone)
		for i,v in pairs(t) do
			local typ = type(v)
			if type ~= "table" then
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

function ProvMapEdit:defineCommands()
	coms = self.commands

	local function table_eq(a,b)
		for i,v in ipairs(a) do
			if v~=b[i] then return false end end
		return true
	end

	coms["invertible_select"] = MapEditCom:define(
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
					if table_eq(v,u) then
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
						if table_eq(v,u) then
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
					if table_eq(v,u) then
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
						if table_eq(v,u) then
							table.remove(active_selection, j)
							self:highlightObject(v,0.0)
							break
						end
					end
				end
			end -- undo command function
		end) 

	coms["additive_select"] = MapEditCom:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable{}}
		},
		function(props) -- command function
			self.selection_changed = true
			local mapedit = self
			local active_selection = mapedit.active_selection

			local obj_count = #props.select_objects
			for i=obj_count,1,-1 do
				v = props.select_objects[i]
				local unique = true
				for j,u in ipairs(active_selection) do
					if table_eq(v,u) then

						-- we remove any objects that have already been selected from the
						-- additive select object list, this action is not reversed in the undo
						-- operation
						table.remove(props.select_objects, i)

						unique = false
						break
					end
				end

				if unique then
					table.insert(active_selection, v)
					self:highlightObject(v,1.0)
				end
			end
		end, -- command function

		function(props) -- undo command function
			self.selection_changed = true
			local mapedit = self
			local active_selection = mapedit.active_selection
			for i,v in ipairs(props.select_objects) do
				for j,u in ipairs(active_selection) do
					if table_eq(v,u) then
						table.remove(active_selection, j)
						self:highlightObject(v,0.0)
						break
					end
				end
			end -- undo command function
		end)

	coms["deselect_all"] = MapEditCom:define(
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

	coms["delete_obj"] = MapEditCom:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable(self.active_selection)},
		 --{"object_memory", "table", nil, PropDefaultTable()},
		},
		function (props) -- command function
			local insts = {}
			for i,v in ipairs(props.select_objects) do
				local obj_type = v[1]
				if obj_type == "model" then
					local inst = v[2]
					--local transf = transobj:from(inst)
					--table.insert(props.object_memory, {inst, transf})
					table.insert(insts, inst)
				else
					error()
				end
			end
			-- collecting the models into a table first to 
			-- pass into removeModel should be more efficient for
			-- large delete operations
			self:removeModelInstance(insts)
		end, -- command function
		function (props) -- undo command function
			local insts = {}
			for i,v in ipairs(props.select_objects) do
				local obj_type = v[1]
				if obj_type == "model" then
					local inst = v[2]
					--local transf = transobj:from(inst)
					--table.insert(props.object_memory, {inst, transf})
					table.insert(insts, inst)
				else
					error()
				end
			end

			self:addModelInstance(insts)
		end -- undo command function
	)

	coms["transform"] = MapEditCom:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable(self.active_selection)},
		 {"memory", "table", nil, PropDefaultTable{}},
		 {"transform_function", nil, nil, nil}
		},
		function(props) -- command function
			if props.memory[1] == nil then -- if memory hasn't been calculated yet
				for i,v in ipairs(props.select_objects) do
					local o_type = v[1]
					if o_type == "model" then
						props.memory[i] = transobj:from(v[2])
					end
				end
			end

			if not props.transform_function then
				props.transform_function = self:applyActiveTransformationFunction(props.select_objects)
			end
			props.transform_function()
		end, -- command function
		function(props) -- undo command function
			for i,v in ipairs(props.select_objects) do
				local o_type = v[1]
				if o_type == "model" then
					local memory = props.memory[i]
					memory:send(v[2])
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

function ProvMapEdit:defineContextMenus()
	local context = self.context_menus

	context["select_models_context"] = 
		contextmenu:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable{}},
		},
		 {"Copy",      action=function(props) print("cop") end, icon = "mapedit/icon_copy.png"},

		 {"Duplicate", action=function(props) print("dup") end, icon = "mapedit/icon_dup.png"},

		 {"~(orange)~bDelete", action=function(props) self:commitCommand("delete_obj") end,
		 	icon = "mapedit/icon_del.png"},

		 {"--Transform--"},
		 {"Flip", suboptions = function(props)
		 	return {
			 {"... by ~b~(lred)X~r axis", action=function() print("flipx") end},
			 {"... by ~b~(lgreen)Y~r axis", action=function() print("flipy") end},
			 {"... by ~b~(lblue)Z~r axis", action=function() print("flipz") end},
			}
		 	end}
		 )
end

function ProvMapEdit:openContextMenu(context_name, props)
	local context_table = self.context_menus
	local context_def = context_table[context_name]
	assert(context_def, string.format("No context menu %s defined", context_name))
	local context = context_def:new(props)
	assert(context)

	CONTROL_LOCK.MAPEDIT_CONTEXT.open()

	self.curr_context_menu = context
	return context
end

function ProvMapEdit:exitContextMenu()
	if self.curr_context_menu then
		self.curr_context_menu:release()
		self.curr_context_menu = nil
	end
	CONTROL_LOCK.MAPEDIT_CONTEXT.close()
end

function ProvMapEdit:setupInputHandling()
	--
	-- CONTEXT MENU MODE INPUTS
	--
	self.cxtm_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_CONTEXT,
	                                   {"cxtm_select","cxtm_scroll_up","cxtm_scroll_down"})

	local cxtm_select_option = Hook:new(function ()
		local cxtm = self.curr_context_menu
		if not cxtm then
			self:exitContextMenu()
			return end
		local hovered_opt = cxtm:getCurrentlyHoveredOption()
		if not hovered_opt then
			self:exitContextMenu()
			return end
		local action = hovered_opt.action
		if action then action() end
		self:exitContextMenu()
	end)
	self.cxtm_input:getEvent("cxtm_select", "down"):addHook(cxtm_select_option)

	--
	-- VIEWPORT MODE INPUTS
	--
	self.viewport_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_VIEW,
	                                       {"cam_forward","cam_backward","cam_left","cam_right","cam_down","cam_up",
										   "cam_rotate","cam_reset","cam_centre","edit_select","edit_deselect","edit_undo","edit_redo",
										   "cam_zoom_in","cam_zoom_out",
										   {"super",CONTROL_LOCK.META},{"toggle_anim_tex",CONTROL_LOCK.META},{"ctrl",CONTROL_LOCK.META},

										   "transform_move","transform_rotate","transform_scale"})

	local forward_v  = {0 , 0,-1}
	local backward_v = {0 , 0, 1}
	local left_v     = {-1, 0,0}
	local right_v    = { 1, 0,0}
	local up_v       = { 0,-1,0}
	local down_v     = { 0, 1,0}

	local super_modifier = false

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
	end)
	local viewport_rotate_finish = Hook:new(function ()
		self.view_rotate_mode = false
		self:releaseMouse()
		self.viewport_input:unlockAll()
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

		if not obj then self:deselectSelection() end

		if not self.super_modifier then
			self:commitCommand("invertible_select", {select_objects={obj}})
			additive_select_obj = obj
			return
		end

		if not additive_select_obj then
			if obj[1] == "tile" then
				additive_select_obj = obj
			else
				additive_select_obj = nil
			end
			self:commitCommand("additive_select", {select_objects={obj}})
			return
		end

		local x1,z1,x2,z2
		local min,max = math.min,math.max
		if obj[1] == "tile" then
			if self:isSelected(additive_select_obj) then
				x1 = min(obj[2], additive_select_obj[2])
				z1 = min(obj[3], additive_select_obj[3])
				x2 = max(obj[2], additive_select_obj[2])
				z2 = max(obj[3], additive_select_obj[3])

				local objs_in_range = {}
				for x=x1,x2 do
					for z=z1,z2 do
						table.insert(objs_in_range, {"tile",x,z})
					end
				end

				self:commitCommand("additive_select", {select_objects=objs_in_range})
				additive_select_obj = nil
				return
			end
			self:commitCommand("additive_select", {select_objects=obj})
		end

		additive_select_obj = nil
		self:commitCommand("additive_select", {select_objects={obj}})
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
	local toggle_anim_tex = Hook:new(function ()
		self.props.mapedit_enable_tex_anim = not self.props.mapedit_enable_tex_anim end)

	self.viewport_input:getEvent("edit_undo","down"):addHook(viewport_undo)
	self.viewport_input:getEvent("edit_redo","down"):addHook(viewport_redo)
	self.viewport_input:getEvent("super", "down"):addHook(enable_super_hook)
	self.viewport_input:getEvent("super", "up"):addHook(disable_super_hook)
	self.viewport_input:getEvent("ctrl", "down"):addHook(enable_ctrl_hook)
	self.viewport_input:getEvent("ctrl", "up"):addHook(disable_ctrl_hook)
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
		--self:applyActiveTransformation()
		if not self:selectionEmpty() then
			self:commitCommand("transform", {})
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
			self:displayPopup("Tiles cannot be rotated")
		else
			self:displayPopup("Tiles cannot be scaled")
		end
		--print("Tiles/walls cannot be rotated.")
		return
	end

	CONTROL_LOCK.MAPEDIT_TRANSFORM.open()
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

function ProvMapEdit:applyTransformObjOntoModel(model, t_obj)
	local pos = t_obj.position
	local rot = t_obj.rotation
	local scl = t_obj.scale
	model:setPosition(pos)
	model:setRotation(rot)
	model:setScale(scl)
end

-- returns either nil, {"tile",x,z}, {"wall",x,z,side}, {model_i}
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
				local intersect, dist = self:testTileAgainstRay(ray, x,z)
				if intersect and dist < min_dist then
					mesh_test = {"tile",x,z}
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
					mesh_test = {"wall",x,z,1}
					min_dist = dist
				end
				intersect, dist = self:testWallSideAgainstRay(ray, x,z, 2)
				if intersect and dist < min_dist  then
					mesh_test = {"wall",x,z,2}
					min_dist = dist
				end
				intersect, dist = self:testWallSideAgainstRay(ray, x,z, 3)
				if intersect and dist < min_dist  then
					mesh_test = {"wall",x,z,3}
					min_dist = dist
				end
				intersect, dist = self:testWallSideAgainstRay(ray, x,z, 4)
				if intersect and dist < min_dist  then
					mesh_test = {"wall",x,z,4}
					min_dist = dist
				end
			end
		end
	end

	if test_models then
		for i,model in ipairs(self.props.mapedit_model_insts) do
			local intersect, dist = self:testModelAgainstRay(ray, model)
			if intersect and dist < min_dist then
				mesh_test = {"model", model}
				min_dist = dist
			end
		end
	end

	return mesh_test
end

local __tempv1,__tempv2,__tempv3,__tempv4 = cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new()
local __temptri1, __temptri2 = {},{}
function ProvMapEdit:testTileAgainstRay(ray, x,z)
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

	return intersect, dist
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
	-- context menu creation here
	if model and not tile and not wall then
		self:openContextMenu("select_models_context", {select_objects=self.active_selection})
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

function ProvMapEdit:editTileVerts(x,z, new_heights)
	local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height
	if x<1 or x>w or y<1 or y>h then return end

	-- first, update height info the tile heights table
	local tile_heights = self.props.mapedit_tile_heights
	local height_info = {}
	local nh_arg_type = type(new_heights)
	-- fill out new heights info
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

	-- update mesh and surrounding walls
	local mesh = self.props.mapedit_map_mesh.mesh
	local index = self:getTilesIndexInMesh(x,z)
	for i=0,3 do
		local x,y,z = mesh:getVertexAttribute(index+i, 1)
		local y = height_info[i+1] * TILE_HEIGHT
		mesh:setVertexAttribute(index+i, 1, x,y,z)
	end
end

local __tempmat4tt = cpml.mat4.new()
local __tempvec3tt = cpml.vec3.new()
local __temptablett = {0,0,0,"dir"}
function ProvMapEdit:getBaseMatrixFromMapEditTransformation(transform)
	local info = transform:getTransform(self.props.mapedit_cam)
	--local t_type = transform:getTransformType()
	local t_type = info.type

	local function getScaleByDist()
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
		local translate = __tempvec3tt
		local s = getScaleByDist()
		translate.x = info[1]*s
		translate.y = info[2]*s
		translate.z = info[3]*s
		mat:translate(mat, translate)
		return mat, info
	end

	if t_type == "rotate" then
		local quat = info[1]
		return cpml.mat4.from_quaternion(quat), info
	end

	if t_type == "scale" or t_type == "flip" then
		local scale = __tempvec3tt
		local s = 1.0
		scale.x = info[1]*s
		scale.y = info[2]*s
		scale.z = info[3]*s
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

function ProvMapEdit:applyActiveTransformationFunction(objs)
	if next(objs) == nil then return end
	if self:selectionEmpty() then return end
	local trans = self.active_transform
	if not trans then return end

	local mat,info = self:getSelectionTransformationModelMatrix(trans)

	local __m = cpml.mat4.new()
	for i=1,16 do __m[i] = mat[i] end
	local __i = info

	return function()
		for i,v in ipairs(objs) do
			local o_type = v[1]
			if o_type == "model" then
				self:applyMapEditTransformOntoModel(v[2], trans, __m, __i)
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

	local t_vec = __tempvec3T
	local mat = __tempmat4T
	local info = transform:getTransform(self.props.mapedit_cam)
	-- tiles can only move up and down
	t_vec.x = 0
	t_vec.y = info[2]
	t_vec.z = 0
	mat:translate(t_vec)
	return mat
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

	local x,y,z = 0,0,0

	local min_x,min_y,min_z = 1/0,1/0,1/0
	local max_x,max_y,max_z = -1/0,-1/0,-1/0

	local min = math.min
	local max = math.max

	local count = 0
	for i,v in ipairs(self.active_selection) do
		local obj_type = v[1]

		local mx,my,mz
		if obj_type == "model" then
			local model = v[2]

			local min,max = model:getBoundingBoxMinMax()

			mx,my,mz = 
				(min[1] + max[1]) * 0.5,
				(min[2] + max[2]) * 0.5,
				(min[3] + max[3]) * 0.5
		elseif obj_type == "tile" then
			local v1,v2,v3,v4 = self:getTileVerts(v[2],v[3])
			mx = (v1[1]+v2[1]+v3[1]+v4[1]) * 0.25
			my = (v1[2]+v2[2]+v3[2]+v4[2]) * 0.25
			mz = (v1[3]+v2[3]+v3[3]+v4[3]) * 0.25
		elseif obj_type == "wall" then
			local v1,v2,v3,v4 = self:getWallVerts(v[2],v[3],v[4])
			mx = (v1[1]+v2[1]+v3[1]+v4[1]) * 0.25
			my = (v1[2]+v2[2]+v3[2]+v4[2]) * 0.25
			mz = (v1[3]+v2[3]+v3[3]+v4[3]) * 0.25
		end

		x,y,z = x + mx, y + my, z + mz
		count = count + 1

		min_x = min(min_x, mx)
		min_y = min(min_y, my)
		min_z = min(min_z, mz)
		max_x = max(max_x, mx)
		max_y = max(max_y, my)
		max_z = max(max_z, mz)
	end

	if count == 0 then return nil end
	x = x / count
	y = y / count
	z = z / count
	self.__cache_selection_centre, self.__cache_selection_min, self.__cache_selection_max =
		{x,y,z}, {min_x,min_y,min_z}, {max_x,max_y,max_z}
	return self.__cache_selection_centre, self.__cache_selection_min, self.__cache_selection_max
end

function ProvMapEdit:getObjectCentre(obj)
	assert(obj)
	local obj_type = obj[1]

	local mx,my,mz
	if obj_type == "model" then
		local model = obj[2]
		local min,max = model:getBoundingBoxMinMax()

		mx,my,mz = 
			(min[1] + max[1]) * 0.5,
			(min[2] + max[2]) * 0.5,
			(min[3] + max[3]) * 0.5
	elseif obj_type == "tile" then
		local v1,v2,v3,v4 = self:getTileVerts(obj[2],obj[3])
		mx = (v1[1]+v2[1]+v3[1]+v4[1]) * 0.25
		my = (v1[2]+v2[2]+v3[2]+v4[2]) * 0.25
		mz = (v1[3]+v2[3]+v3[3]+v4[3]) * 0.25
	elseif obj_type == "wall" then
		local v1,v2,v3,v4 = self:getWallVerts(obj[2],obj[3],obj[4])
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
	self.viewport_input:poll()
	self.transform_input:poll()
	self.cxtm_input:poll()
	self:interpCameraToPos(dt)
	cam:update()
	self:updateModelMatrices()

	count = count+1
	if self.active_transform and (count % 25 == 0) then
		local t = self.active_transform:getTransform(self.props.mapedit_cam)
		if t then
			--print(t)
		end
	end
	self:updateTransformationMatrix()

	local map_mesh = self.props.mapedit_map_mesh
	if map_mesh and self.props.mapedit_enable_tex_anim then map_mesh:updateUvs() end

	if self.selection_changed then
		self.selection_changed = false
		self.__cache_recalc_selection_centre = true
	end

	self:updateContextMenu()
	self:updatePopupMenu()
end

function ProvMapEdit:updateTransformationMatrix()
	local trans = self.active_transform
	if not trans then return end
	local a = self:getSelectionTransformationModelMatrix(trans)
	self.active_transform_model_mat_a = a
	--self.active_transform_model_mat_b = b

	local shader = self.map_edit_shader
	shader:send("u_transform_a", "column", a)
	--shader:send("u_transform_b", "column", b)
end

function ProvMapEdit:isModelSelected(inst)
	for i,v in ipairs(self.active_selection) do
		if v[1] == "model" and v[2] == inst then return true end
	end
	return false
end

function ProvMapEdit:updateContextMenu()
	if not self.curr_context_menu then
		self.context_menu_hovered = false
		return
	end
	local x,y = love.mouse.getX(), love.mouse.getY()
	self.context_menu_hovered = self.curr_context_menu:updateHoverInfo(x,y)
end

function ProvMapEdit:displayPopup(str, ...)
	self.curr_popup = popup:throw(str, ...)
end

function ProvMapEdit:updatePopupMenu()
	if not self.curr_popup then return end
	local p = self.curr_popup
	if p:expire() then
		p:release()
		self.curr_popup = nil
	end
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

end

function ProvMapEdit:invokeDrawMesh()
	local mesh = self.props.mapedit_map_mesh.mesh
	love.graphics.draw(mesh)
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
			shader:send("u_apply_ab_transformation", false)
			v:draw(shader, false)
		else
			if self.active_transform then
				shader:send("u_apply_ab_transformation", true)
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
	shader:send("u_apply_ab_transformation", false)
end

function ProvMapEdit:updateModelMatrices(subset)
local subset = subset or self.props.mapedit_model_insts
for i,v in ipairs(subset) do
	v:modelMatrix()
	end
end

function ProvMapEdit:drawSpecificTile(x,z)
	local mesh_start_index = self:getTilesIndexInMesh(x,z)
	local mesh = self.props.mapedit_map_mesh.mesh
	local vmap_length = #mesh:getVertexMap()

	local vmap_start_i = 6*((mesh_start_index-1)/4)+1
	mesh:setDrawRange(vmap_start_i, 6)
	love.graphics.draw(mesh)
	mesh:setDrawRange(1,vmap_length)
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

function ProvMapEdit:updateMeshHighlightAttribute(start_index, highlight_val)
	if highlight_val ~= 0.0 then highlight_val = 1.0 end
	local h_mesh = self.highlight_mesh
	if not h_mesh then return end
	
	for i=0,3 do
		h_mesh:setVertexAttribute(start_index+i, 1, highlight_val)
	end
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
	self:updateMeshHighlightAttribute(i, highlight_val)
end

function ProvMapEdit:highlightWall(x,z, side, highlight_val)
	local i = self:getWallsIndexInMesh(x,z,side)
	if not i then return end

	local highlight_val = highlight_val or 1.0
	self:updateMeshHighlightAttribute(i, highlight_val)
end

function ProvMapEdit:highlightObject(obj, highlight_val)
	local obj_type = obj[1]
	if obj_type == "tile" then
		self:highlightTile(obj[2], obj[3], highlight_val)
	elseif obj_type == "wall" then
		self:highlightWall(obj[2], obj[3], obj[4], highlight_val)
	end
end

function ProvMapEdit:selectionCount()
	return #self:selectionCount()
end

function ProvMapEdit:isSelectionEmpty()
	return self:selectionCount() == 0
end

function ProvMapEdit:isSelected(obj)
	local function table_eq(a,b)
		for i,v in ipairs(a) do
			if v~=b[i] then return false end end
		return true
	end
	assert_type(obj, "table")
	for i,v in ipairs(self.active_selection) do
		if table_eq(obj,v) then return true end
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
	love.graphics.setBlendMode("screen","premultiplied")

	love.graphics.setColor(self.selection_col)
	love.graphics.setDepthMode( "always", false  )
	--for i,v in ipairs(self.active_selection) do
	--	if v[1] == "tile" then
	--		self:drawSpecificTile(v[2],v[3])
	--	end
	--end
	self:invokeDrawMesh()

	love.graphics.setBlendMode(mode, alphamode)
	shadersend(shader,"u_uses_tileatlas", false)
	love.graphics.setDepthMode( "less", true  )
	shadersend(shader,"u_highlight_pass", false)
	love.graphics.setColor(1,1,1,1)
end

function ProvMapEdit:drawContextMenu()
	local cxtm = self.curr_context_menu
	if not cxtm then return end
	cxtm:draw()
end
function ProvMapEdit:drawPopup()
	local p = self.curr_popup
	if not p then return end
	p:draw()
end

function ProvMapEdit:draw()
	self:drawViewport()
	Renderer.renderScaledDefault()

	love.graphics.setCanvas()
	love.graphics.setShader()
	love.graphics.origin()
	love.graphics.setColor(1,1,1,1)
	love.graphics.setDepthMode( "always", false  )
	self:drawContextMenu()
	self:drawPopup()
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
	self:exitContextMenu()
end
