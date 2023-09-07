local matrix = require "matrix"
local cpml = require "cpml"

require "render"
require "map"
require "tick"
require "scene"
require "modelmanager"

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
			["light_pos"] = {0,0,0,0},
			--["light_dir"] = {0.5,1.0,-0.5},
			["light_dir"] = {-1.0,1.5,-1.0},
			["light_col"] = {255/255, 235/255, 224/255, 10}
		}
	}
	self.scene.props.scene_skybox_hdr_brightness = 10

	pianko = Models.queryModel("pianko.iqm")
	sphere = Models.queryModel("Sphere.iqm")
	crate = Models.queryModel("shittycrate.iqm")
	instance = ModelInstance:newInstance(pianko)
	instance.props.model_i_outline_flag = true
	crate_i = ModelInstance:newInstance(crate, {model_i_position = {300,-24,-240}, model_i_static = true})

	--local insts = {}
	--for i=1,10000 do
	--	insts[i] = ModelInfo.new({0,-i*1,-i*1,},{0,0,i/10.0}, 1.0)
	--end
	--crate_inst = ModelInstance:newInstances(crate,
	--	{
	--		ModelInfo.new({300,-60,-256},{0,0,0},1),
	--		ModelInfo.new({256,-300,-700},{0,1,1},1),
	--		ModelInfo.new({256,-48,-350},{0,0,0},2)
	--	}
	--)

	sphere = ModelInstance:newInstance(sphere)
	self.scene:addModelInstance{ sphere, instance, crate_i }
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

	instance.props.model_i_position = {cam.cam_x+80*math.sin(cam.cam_yaw),cam.cam_y+60,cam.cam_z-100*math.cos(cam.cam_yaw)}
	--instance.props.model_i_rotation[2] = -getTick()/60
	--instance.props.model_i_rotation[1] = getTick()/120
	--sphere.props.model_i_rotation[1] = getTick()/60
	--
end

function PROV:draw()
	self.scene:draw()

	--Renderer.renderScaled(Renderer.skybox_viewport, {hdr_enabled=false})
	Renderer.renderScaled(nil, {hdr_enabled=true})
end

function PROV:onTickChange()
	local meshes = self.scene.props.scene_meshes
	for _,mesh in ipairs(meshes) do
		mesh:updateTexture()
	end
end
