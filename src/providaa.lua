local matrix = require "matrix"
local cpml = require "cpml"

require "render"
require "map"
require "tick"
require "scene"
require "model"

local testmap = require "maps.test"

PROV = {
	grid = {},
	scene = Scene:new(),
}
PROV.__index = PROV

function PROV:load()
	self.scene:loadMap(testmap)
	self.scene.props.scene_lights = {
		Light:new{
			["light_pos"] = {800,-700,-800,0},
			--["light_dir"] = {0.5,1.0,-0.5},
			["light_dir"] = {0.0,1.0,0.01},
			["light_col"] = {240/255, 233/255, 226/255, 1.0}
		}
	}

	alekin = Model.openFilename("alekin.iqm", "models/alekin.png", true)
	instance = ModelInstance:newInstance(alekin)
	instances = {}
	--for i=1,25 do
	--	instances[i] = ModelInstance:newInstance(alekin)
	--end
	self.scene.props.scene_models = { instance , unpack(instances) }
end

function PROV:update(dt)
	stepTick(dt)
	if tickChanged() then
		self:onTickChange()
	end

	local cam = PROV.scene.props.scene_camera.props
	if love.keyboard.isDown("w") then
		cam.cam_z = cam.cam_z - 100*dt
	end
	if love.keyboard.isDown("s") then
		cam.cam_z = cam.cam_z + 100*dt
	end
	if love.keyboard.isDown("a") then
		cam.cam_x = cam.cam_x - 100*dt
	end
	if love.keyboard.isDown("d") then
		cam.cam_x = cam.cam_x + 100*dt
	end
	if love.keyboard.isDown("space") then
		cam.cam_y = cam.cam_y - 50*dt
	end
	if love.keyboard.isDown("lctrl") then
		cam.cam_y = cam.cam_y + 50*dt
	end

	if love.keyboard.isDown("right") then
		cam.cam_yaw = cam.cam_yaw + 1*dt
		--cam.cam_roll = cam.cam_roll - 1*dt
	end

	if love.keyboard.isDown("left") then
		cam.cam_yaw = cam.cam_yaw - 1*dt
		--cam.cam_roll = cam.cam_roll + 1*dt
	end

	if love.keyboard.isDown("down") then
		cam.cam_pitch = cam.cam_pitch - 1*dt
	end

	if love.keyboard.isDown("up") then
		cam.cam_pitch = cam.cam_pitch + 1*dt
	end

	instance.props.model_i_position = {cam.cam_x+80*math.sin(cam.cam_yaw),cam.cam_y+80,cam.cam_z-100*math.cos(cam.cam_yaw)}
	--instance.props.model_i_rotation[2] = getTick()/60
end

function PROV:draw()
	self.scene:draw()

	Renderer.renderScaled(Renderer.skybox_viewport, {hdr_enabled=false})
	Renderer.renderScaled(nil, {hdr_enabled=true, exposure=0.30})

	--love.graphics.origin()
	--Renderer.renderScaled(self.scene.props.scene_lights[1].testcanvas)
	--love.graphics.setColor(1,0,0,1)
	--love.graphics.rectangle("line",0,0,1024,1024)
	--love.graphics.setColor(1,1,1,1)
	--love.graphics.draw(self.scene.props.scene_lights[1].testcanvas)
end

function PROV:onTickChange()
	local meshes = self.scene.props.scene_meshes
	for _,mesh in ipairs(meshes) do
		mesh:updateTexture()
	end
end
