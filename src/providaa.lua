local matrix = require "matrix"
local cpml = require "cpml"

require "render"
require "map"
require "tick"
require "scene"

local testmap = require "maps.test"

PROV = {
	grid = {},
	scene = Scene:new(),

	tick_dt_counter = 0,
	tick_rate = 60
}

function PROV:load()

	Renderer.vertex_shader = love.graphics.newShader("shader/vertex.glsl")

	self.scene:loadMap(testmap)
end

function PROV:update(dt)
	UPDATE_ANIMATION = false
	self.tick_dt_counter = self.tick_dt_counter + dt
	if (self.tick_dt_counter > 1/self.tick_rate) then
		UPDATE_ANIMATION = true

		setTick(getTick()+1)
		self.tick_dt_counter = self.tick_dt_counter - 1/self.tick_rate
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
end

function PROV:draw()
	self.scene:draw()

	Renderer.renderScaled()
end

function PROV:onTickChange()
	local meshes = self.scene.props.scene_meshes
	for _,mesh in ipairs(meshes) do
		mesh:updateTexture()
	end
end
