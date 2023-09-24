require "props/mapeditprops"

require "map"
require "camera"
require "render"
require "angle"

local maptransform = require "mapedittransform"
local shadersend = require "shadersend"
local cpml       = require "cpml"

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

	wireframe_col = {19/255,66/255,72/255,0.8},
	selection_col = {255/255,161/255,66/255,1.0},

	active_selection = {},
	highlight_mesh = nil,

	active_transform = nil

}
ProvMapEdit.__index = ProvMapEdit

function ProvMapEdit:load(args)
	SET_ACTIVE_KEYBINDS(MAPEDIT_KEY_SETTINGS)
	if not self.mapedit_shader then
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
			if v~=b[i] then return false end
		end
		return true
	end

	coms["invertible_select"] = MapEditCom:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable{}},
		},
		function(props) -- command function
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
		 {"past_selection", "table", nil, PropDefaultTable(self.active_selection)}
		},
		function(props) -- command function
			local mapedit = self
			for i,v in ipairs(mapedit.active_selection) do
				self:highlightObject(v, 0.0)
			end
			mapedit.active_selection = {}
		end, -- command function

		function(props) -- undo command function
			local mapedit = self
			mapedit.active_selection = props.past_selection
			for i,v in ipairs(mapedit.active_selection) do
				self:highlightObject(v, 1.0)
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

function ProvMapEdit:setupInputHandling()
	--
	-- VIEWPORT MODE INPUTS
	--
	self.viewport_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_VIEW,
	                                       {"cam_forward","cam_backward","cam_left","cam_right","cam_down","cam_up",
										   "cam_rotate","cam_reset","edit_select","edit_deselect","edit_undo","edit_redo",
										   "super","toggle_anim_tex",
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
	end)
	local viewport_rotate_finish = Hook:new(function ()
		self.view_rotate_mode = false
		self:releaseMouse()
	end)
	self.viewport_input:getEvent("cam_rotate","down"):addHook(viewport_rotate_start)
	self.viewport_input:getEvent("cam_rotate","up"):addHook(viewport_rotate_finish)

	self.viewport_input:getEvent("cam_reset","down"):addHook(Hook:new(function()
		self:newCamera()
	end))

	local additive_select_obj = nil
	local viewport_select = Hook:new(function ()
		local x,y = love.mouse.getPosition()
		local obj = self:objectAtCursor( x,y , true, true, true)

		if not super_modifier then
			self:commitCommand("invertible_select", {select_objects={obj}})
			additive_select_obj = obj
			return
		end

		if not additive_select_obj then
			if obj[1] == "tile" then
				additive_select_obj = obj
			end
			self:commitCommand("additive_select", {select_objects={obj}})
			return
		end

		local x1,z1,x2,z2
		local min,max = math.min,math.max
		if obj[1] == "tile" then
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

		additive_select_obj = nil
		self:commitCommand("additive_select", {select_objects={obj}})
	end)
	self.viewport_input:getEvent("edit_select","down"):addHook(viewport_select)

	local viewport_deselect = Hook:new(function ()
		self:commitCommand("deselect_all", {}) end)
	self.viewport_input:getEvent("edit_deselect", "down"):addHook(viewport_deselect)

	local viewport_undo = Hook:new(function ()
		self:commitUndo() end)
	local viewport_redo = Hook:new(function ()
		self:commitRedo() end)
	local enable_super_hook = Hook:new(function ()
		super_modifier = true end)
	local disable_super_hook = Hook:new(function ()
		super_modifier = false end)
	local toggle_anim_tex = Hook:new(function ()
		self.props.mapedit_enable_tex_anim = not self.props.mapedit_enable_tex_anim end)

	self.viewport_input:getEvent("edit_undo","down"):addHook(viewport_undo)
	self.viewport_input:getEvent("edit_redo","down"):addHook(viewport_redo)
	self.viewport_input:getEvent("super", "down"):addHook(enable_super_hook)
	self.viewport_input:getEvent("super", "up"):addHook(disable_super_hook)
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
	CONTROL_LOCK.MAPEDIT_VIEW.close()
	CONTROL_LOCK.MAPEDIT_TRANSFORM.open()
	self.props.mapedit_mode = "transform"
	self.props.mapedit_transform_mode = transform_mode
	self.active_transform = maptransform:newTransform(transform_mode)
end

function ProvMapEdit:getCurrentMode()
	return self.props.mapedit_mode
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

	print("objectAtcursor", unpack(mesh_test or {}))
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

function ProvMapEdit:newCamera()
	self.props.mapedit_cam = Camera:new{
		["cam_position"] = {self.props.mapedit_map_width*0.5*TILE_SIZE, -128, self.props.mapedit_map_height*0.5*TILE_SIZE},
		["cam_bend_enabled"] = false,
		["cam_far_plane"] = 3000.0,
		["cam_fov"] = 75.0,
	}
end

local count = 0
function ProvMapEdit:update(dt)
	local cos,sin=math.cos,math.sin
	local cam = self.props.mapedit_cam

	local mode = self.props.mapedit_mode
	if mode == "viewport" then
		self.viewport_input:poll()
	elseif mode == "transform" then
		self.transform_input:poll()
	end
	cam:update()
	self:updateModelMatrices()

	count = count+1
	if self.active_transform and (count % 25 == 0) then
		local t = self.active_transform:getTransform(self.props.mapedit_cam)
		if t then
			print(unpack(t))
		end
	end

	local map_mesh = self.props.mapedit_map_mesh
	if map_mesh and self.props.mapedit_enable_tex_anim then map_mesh:updateUvs() end
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
			v:draw(shader, false)
		else
			v:draw(shader, false)
			shadersend(shader, "u_solid_colour_enable", true)
			love.graphics.setDepthMode( "always", false  )
			love.graphics.setColor(self.selection_col)
			local mode, alphamode = love.graphics.getBlendMode()
			love.graphics.setBlendMode("screen","premultiplied")
			v:draw(shader, false)
			shadersend(shader, "u_solid_colour_enable", false)
			love.graphics.setDepthMode( "less", true  )
			love.graphics.setBlendMode(mode, alphamode)
			love.graphics.setColor(1,1,1,1)
		end
	end
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

function ProvMapEdit:draw()
	self:drawViewport()
	Renderer.renderScaledDefault()
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
end

function ProvMapEdit:transform_mousemoved(x,y,dx,dy)
	local transform_mode = self.props.mapedit_transform_mode
	if transform_mode == "translate" then
	end
end
