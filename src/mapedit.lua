require "props/mapeditprops"

require "map"
require "camera"
require "render"
require "angle"

local shadersend = require "shadersend"
local cpml       = require "cpml"

require "mapeditcommand"

ProvMapEdit = {

	props = nil,

	map_edit_shader = nil,

	viewport_input = nil,

	view_rotate_mode = false,
	grabbed_mouse_x = 0,
	grabbed_mouse_y = 0,

	commands = {}

}
ProvMapEdit.__index = ProvMapEdit

function ProvMapEdit:load(args)
	SET_ACTIVE_KEYBINDS(MAPEDIT_KEY_SETTINGS)
	if not self.mapedit_shader then
		self.map_edit_shader = love.graphics.newShader("shader/mapedit.glsl") end
	
	local lvledit_arg = args["lvledit"]
	assert(lvledit_arg and lvledit_arg[1], "ProvMapEdit:load(): no level specified in lvl edit launch argument")

	self.props = MapEditPropPrototype()

	local map_name = lvledit_arg[1]
	self:loadMap(map_name)

	self:newCamera()
	self:setupInputHandling()
end

function ProvMapEdit:unload()
	CONTROL_LOCK.MAPEDIT_VIEW.close()
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
		{ dont_optimise=true, dont_gen_simple=true , gen_all_verts = true, gen_nil_texture = "nil.png", gen_index_map = true} )
	if map_mesh then
		self.props.mapedit_map_mesh = map_mesh
	else
		error(string.format("ProvMapEdit:load(): %s failed to load", fullpath))
	end

	local skybox_img, skybox_fname, skybox_brightness = Map.generateSkybox( map_file )
	if skybox_img then
		self.props.mapedit_skybox_img = skybox_img
	end

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

function ProvMapEdit:setupInputHandling()
	self.viewport_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_VIEW,
	                                       {"cam_forward","cam_backward","cam_left","cam_right","cam_down","cam_up",
										   "cam_rotate","cam_reset","edit_select","edit_deselect","edit_undo","edit_redo"})
	CONTROL_LOCK.MAPEDIT_VIEW.open()

	local forward_v  = {0 , 0,-1,0}
	local backward_v = {0 , 0, 1,0}
	local left_v     = {-1, 0,0,0}
	local right_v    = { 1, 0,0,0}
	local up_v       = { 0,-1,0,0}
	local down_v     = { 0, 1,0,0}

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

	local viewport_move_forward = Hook:new(function ()
		__move(forward_v, true)() end)
	self.viewport_input:getEvent("cam_forward","held"):addHook(viewport_move_forward)

	local viewport_move_backward = Hook:new(function ()
		__move(backward_v, true)() end)
	self.viewport_input:getEvent("cam_backward","held"):addHook(viewport_move_backward)

	local viewport_move_left = Hook:new(function ()
		__move(left_v, true)() end)
	self.viewport_input:getEvent("cam_left","held"):addHook(viewport_move_left)

	local viewport_move_right = Hook:new(function ()
		__move(right_v, true)() end)
	self.viewport_input:getEvent("cam_right","held"):addHook(viewport_move_right)

	local viewport_move_up = Hook:new(function ()
		__move(up_v)() end)
	self.viewport_input:getEvent("cam_up","held"):addHook(viewport_move_up)

	local viewport_move_down = Hook:new(function ()
		__move(down_v)() end)
	self.viewport_input:getEvent("cam_down","held"):addHook(viewport_move_down)

	local viewport_rotate_start = Hook:new(function ()
		love.mouse.setRelativeMode( true )
		self.view_rotate_mode = true
		self.grabbed_mouse_x = love.mouse.getX()
		self.grabbed_mouse_y = love.mouse.getY()
	end)
	self.viewport_input:getEvent("cam_rotate","down"):addHook(viewport_rotate_start)
	local viewport_rotate_finish = Hook:new(function ()
		love.mouse.setRelativeMode( false )
		self.view_rotate_mode = false
		love.mouse.setX(self.grabbed_mouse_x)
		love.mouse.setY(self.grabbed_mouse_y)
	end)
	self.viewport_input:getEvent("cam_rotate","up"):addHook(viewport_rotate_finish)

	self.viewport_input:getEvent("cam_reset","down"):addHook(Hook:new(function()
		self:newCamera()
	end))

	local viewport_select = Hook:new(function ()
		local x,y = love.mouse.getPosition()
		self:objectAtCursor( x,y )
	end)
	self.viewport_input:getEvent("edit_select","down"):addHook(viewport_select)
end

local __tempv1,__tempv2,__tempv3,__tempv4 = cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new(),cpml.vec3.new()
local __temptri1, __temptri2 = {},{}
-- returns either nil, {"tile",x,z}, {"wall",x,z,side}, {model_i}
function ProvMapEdit:objectAtCursor( x, y )
	local project = cpml.mat4.project
	local unproject = cpml.mat4.unproject
	local point_triangle = cpml.intersect.point_triangle
	local ray_triangle = cpml.intersect.ray_triangle

	local cam = self.props.mapedit_cam
	local viewproj = cam:getViewProjMatrix()
	local vw,vh = love.window.getMode()
	local viewport_xywh = {0,0,vw,vh}

	local cursor_v = cpml.vec3.new(x,y,1)
	local cam_pos = cpml.vec3.new(cam:getPosition())
	local unproject_v = unproject(cursor_v, viewproj, viewport_xywh)
	--local ray_dir_v = cpml.vec3.new(cam:getDirection())
	local ray = {position=cam_pos, direction=cpml.vec3.normalize(unproject_v - cam_pos)}
	print("ray_v", ray.position)
	print("ray_dir_v", ray.direction)

	local min_dist = 1/0
	local mesh_test = nil
	-- test against map mesh
	do
		local w,h = self.props.mapedit_map_width, self.props.mapedit_map_height

		for z=1,h do
			for x=1,w do
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

				if dist and dist < min_dist then
					mesh_test = {"tile",x,z}
					min_dist = dist
				end

				if intersect1 or intersect2 then print(x,z) end
			end
		end
	end

	print("objectAtcursor", unpack(mesh_test or {}))
	return mesh_test
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
	local w,h = self.props.map_width, self.props.map_height
	if x<1 or x>w or z<1 or z>h then
		return nil end

	assert(side==1 or side==2 or side==3 or side==4)
	local wmap = self.props.mapedit_map_mesh.wall_vert_map
	local index = vmap[z][x][side]
	return index
end

function ProvMapEdit:newCamera()
	self.props.mapedit_cam = Camera:new{
		["cam_position"] = {self.props.mapedit_map_width*0.5*TILE_SIZE, -128, self.props.mapedit_map_height*0.5*TILE_SIZE},
		["cam_bend_enabled"] = false,
		["cam_far_plane"] = 3000.0,
		["cam_fov"] = 75.0,
	}
end

function ProvMapEdit:update(dt)
	local cos,sin=math.cos,math.sin
	local cam = self.props.mapedit_cam
	self.viewport_input:poll()
	cam:update()

	local map_mesh = self.props.mapedit_map_mesh
	if map_mesh then map_mesh:updateUvs() end
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
	love.graphics.setDepthMode( "lequal", true  )
	love.graphics.setMeshCullMode("front")

	if not skybox_drawn then
		love.graphics.clear(27/255, 66/255, 140/255,1)
	end

	love.graphics.setShader(shader)
	love.graphics.setColor(1,1,1,1)

	local cam = self.props.mapedit_cam
	cam:pushToShader(shader)

	if map_mesh then

		shadersend(shader,"u_model", "column", __id)
		shadersend(shader,"u_normal_model", "column", __id)
		shadersend(shader,"u_skinning", 0)
		map_mesh:pushAtlas( shader , true )

		-- draw culled faces with opacity
		love.graphics.setColor(1,1,1,0.78)
		love.graphics.setMeshCullMode("back")
		love.graphics.draw(map_mesh.mesh)
		love.graphics.setMeshCullMode("front")
		-- draw visible faces fully opaque
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(map_mesh.mesh)


		love.graphics.setWireframe( true )
		shadersend(shader,"u_wireframe_enabled", true)
		shadersend(shader,"u_wireframe_colour", {1,1,1,0.4})
		shadersend(shader,"u_uses_tileatlas", false)
		love.graphics.setDepthMode( "always", false  )
		love.graphics.draw(map_mesh.mesh)
		shadersend(shader,"u_wireframe_enabled", false)

		love.graphics.setWireframe( false )
	end
end

function ProvMapEdit:draw()
	self:drawViewport()
	Renderer.renderScaledDefault()
end

local __tempdir = {}
function ProvMapEdit:mousemoved(x,y, dx,dy)
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
