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

	view_rotate_mode = false

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

	local map_mesh = Map.generateMapMesh( map_file , { dont_optimise=true, dont_gen_simple=true } )
	if map_mesh then
		self.props.mapedit_map_mesh = map_mesh
	else
		error(string.format("ProvMapEdit:load(): %s failed to load", fullpath))
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
end

function ProvMapEdit:setupInputHandling()
	self.viewport_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_VIEW,
	                                       {"cam_forward","cam_backward","cam_left","cam_right","cam_down","cam_up","cam_rotate"})
	CONTROL_LOCK.MAPEDIT_VIEW.open()

	local forward_v  = {0 , 0,-1,0}
	local backward_v = {0 , 0, 1,0}
	local left_v     = {-1, 0,0,0}
	local right_v    = { 1, 0,0,0}
	local up_v       = { 0,-1,0,0}
	local down_v     = { 0, 1,0,0}

	local function __move(dir_v)
		return function()
			local dt = love.timer.getDelta()
			local cam = self.props.mapedit_cam
			local dir = {cam:getDirectionVector(dir_v)}
			local speed = self.props.mapedit_cam_speed
			local campos = cam:getPosition()
			cam:setPosition{
				campos[1] + dir[1] * dt * speed,
				campos[2] + dir[2] * dt * speed,
				campos[3] + dir[3] * dt * speed}
		end
	end

	local viewport_move_forward = Hook:new(function ()
		__move(forward_v)() end)
	self.viewport_input:getEvent("cam_forward","held"):addHook(viewport_move_forward)

	local viewport_move_backward = Hook:new(function ()
		__move(backward_v)() end)
	self.viewport_input:getEvent("cam_backward","held"):addHook(viewport_move_backward)

	local viewport_move_left = Hook:new(function ()
		__move(left_v)() end)
	self.viewport_input:getEvent("cam_left","held"):addHook(viewport_move_left)

	local viewport_move_right = Hook:new(function ()
		__move(right_v)() end)
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
	end)
	self.viewport_input:getEvent("cam_rotate","down"):addHook(viewport_rotate_start)
	local viewport_rotate_finish = Hook:new(function ()
		love.mouse.setRelativeMode( false )
		self.view_rotate_mode = false
	end)
	self.viewport_input:getEvent("cam_rotate","up"):addHook(viewport_rotate_finish)
end

function ProvMapEdit:newCamera()
	self.props.mapedit_cam = Camera:new{
		["cam_position"] = {self.props.mapedit_map_width*0.5*TILE_SIZE, -320, self.props.mapedit_map_height*0.5*TILE_SIZE},
		["cam_bend_enabled"] = false,
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

local __id = cpml.mat4.new()
function ProvMapEdit:drawViewport()
	local map_mesh = self.props.mapedit_map_mesh
	local shader = self.map_edit_shader

	Renderer.clearDepthBuffer()

	love.graphics.origin()
	love.graphics.setCanvas{Renderer.scene_viewport,
		depthstencil = Renderer.scene_depthbuffer,
		depth=true, stencil=false}
	love.graphics.setDepthMode( "less", true  )
	love.graphics.setMeshCullMode("front")

	love.graphics.clear(27/255, 66/255, 140/255,1)	

	love.graphics.setShader(shader)
	love.graphics.setColor(1,1,1,1)

	local cam = self.props.mapedit_cam
	cam:pushToShader(shader)

	if map_mesh then

		shadersend(shader,"u_model", "column", __id)
		shadersend(shader,"u_normal_model", "column", __id)
		shadersend(shader,"u_skinning", 0)
		map_mesh:pushAtlas( shader , true )
		love.graphics.draw(map_mesh.mesh)

		love.graphics.setWireframe( true )
		shadersend(shader,"u_wireframe_enabled", true)
		shadersend(shader,"u_wireframe_colour", {1,1,1,1})
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
