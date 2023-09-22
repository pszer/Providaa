require "props/mapeditprops"

require "map"
require "camera"
require "render"

local shadersend = require "shadersend"
local cpml       = require "cpml"

require "mapeditcommand"

ProvMapEdit = {

	props = nil,

	map_edit_shader = nil,

	viewport_input = nil

}
ProvMapEdit.__index = ProvMapEdit

function ProvMapEdit:load(args)
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

	local map_mesh = Map.generateMapMesh( map_file )
	if map_mesh then
		self.props.mapedit_map_mesh = map_mesh
	else
		error(string.format("ProvMapEdit:load(): %s failed to load", fullpath))
	end
end

function ProvMapEdit:setupInputHandling()
	self.viewport_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_VIEW,
	                                       {"move_left","move_right","move_up","move_down"})
	CONTROL_LOCK.MAPEDIT_VIEW.open()

	local forward_v  = {0 , 0,-1,0}
	local backward_v = {0 , 0, 1,0}
	local left_v     = {-1, 0,0,0}
	local right_v    = { 1, 0,0,0}
	local up_v       = { 0,-1,0,0}
	local down_v     = { 0, 1,0,0}

	local viewport_move_forward = Hook:new(function ()
		local dt = love.timer.getDelta()
		local cam = self.props.mapedit_cam
		local dir = cam:getDirectionVector(forward_v)
		local campos = cam:getPosition()
		cam:setPosition{
			cam[1] + dir[1] * dt,
			cam[2] + dir[2] * dt,
			cam[3] + dir[3] * dt}
	end)

	--[[local viewport_move_forward = Hook:new(function ()
		local dt = love.timer.getDelta()
		local cam = self.props.mapedit_cam
		local dir = cam:getDirectionVector(forward_v)
		local campos = cam:getPosition()
		cam:setPosition{
			cam[1] + dir[1] * dt,
			cam[2] + dir[2] * dt,
			cam[3] + dir[3] * dt}
	end)--]]
end

function ProvMapEdit:newCamera()
	self.props.mapedit_cam = Camera:new{
		["cam_rotation"] = {0,1.6,0},
		["cam_bend_enabled"] = false,
		["cam_fov"] = 75.0,
	}
end

function ProvMapEdit:update(dt)
	local cos,sin=math.cos,math.sin
	local cam = self.props.mapedit_cam
	cam:setPosition{1028,-200,1028}
	--cam:setRotation{0.25,getTickSmooth()/200,0.25}
	local time = getTickSmooth() / 150
	cam:setDirection{cos(time),0.5,-sin(time)}
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
		love.graphics.draw(map_mesh.mesh)
		shadersend(shader,"u_wireframe_enabled", false)

		love.graphics.setWireframe( false )
	end
end

function ProvMapEdit:draw()
	self:drawViewport()
	Renderer.renderScaledDefault()
end
