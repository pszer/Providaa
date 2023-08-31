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
			--["light_dir"] = {-1.0,0.0,0.0},
			["light_dir"] = {0.5,1.0,-0.5},
			["light_col"] = {240/255, 233/255, 226/255, 1.0}
		}
	}

	alekin = Model.openFilename("alekin.iqm", "models/alekin.png", true)
	self.scene.props.scene_models = {alekin}
end

function PROV:update(dt)
	stepTick(dt)
	if tickChanged() then
		self:onTickChange()
	end

	local cam = PROV.scene.props.scene_camera.props
	if love.keyboard.isDown("w") then
		cam.cam_z = cam.cam_z - 500*dt
	end
	if love.keyboard.isDown("s") then
		cam.cam_z = cam.cam_z + 500*dt
	end
	if love.keyboard.isDown("a") then
		cam.cam_x = cam.cam_x - 1000*dt
	end
	if love.keyboard.isDown("d") then
		cam.cam_x = cam.cam_x + 1000*dt
	end
	if love.keyboard.isDown("space") then
		cam.cam_y = cam.cam_y - 250*dt
	end
	if love.keyboard.isDown("lctrl") then
		cam.cam_y = cam.cam_y + 250*dt
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

	alekin.props.model_position = {cam.cam_x+80*math.sin(cam.cam_yaw),cam.cam_y+80,cam.cam_z-100*math.cos(cam.cam_yaw)}
	--alekin.props.model_position = {600,-1000,-600}
	alekin.props.model_rotation[2] = getTick()/60
end

function PROV:draw()
	self.scene:draw()

	Renderer.renderScaled()
	love.graphics.origin()
	--Renderer.renderScaled(self.scene.props.scene_lights[1].testcanvas)
end

function PROV:onTickChange()
	local meshes = self.scene.props.scene_meshes
	for _,mesh in ipairs(meshes) do
		mesh:updateTexture()
	end
end
