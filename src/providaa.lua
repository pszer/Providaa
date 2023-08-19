local matrix = require "matrix"
local cpml = require "cpml"

require "render"
require "map"
require "tick"

PROV = {
	grid = {},

	tick_dt_counter = 0,
	tick_rate = 60
}

function PROV:load()
	Textures.loadTextures()
end

local testmap = require "maps.test"
TESTGRID = Map.loadMap(testmap)
TESTGRID:generateMesh()
TESTGRID:optimizeMesh()

function PROV:update(dt)
	self.tick_dt_counter = self.tick_dt_counter + dt
	if (self.tick_dt_counter > 1/self.tick_rate) then
		setTick(getTick()+1)
		self.tick_dt_counter = self.tick_dt_counter - 1/self.tick_rate
	end

	local cam = CAM.props
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
	end

	if love.keyboard.isDown("left") then
		cam.cam_yaw = cam.cam_yaw - 1*dt
	end

	if love.keyboard.isDown("down") then
		cam.cam_pitch = cam.cam_pitch - 1*dt
	end

	if love.keyboard.isDown("up") then
		cam.cam_pitch = cam.cam_pitch + 1*dt
	end
end

function PROV:draw()

	local clipz = calculateHorizon()
	local cliptz = (clipz+CAM.props.cam_z) / 32
	cliptz = cliptz

	CAM:setupCanvas()
	CAM:generateViewMatrix()

	love.graphics.clear(0.1,0.1,0.1,1)
	love.graphics.setColor(1,1,1,0.5)
	love.graphics.setColor(1,1,1,1)

	local grid = TESTGRID
	for Z = 1, grid.props.grid_h do
		for X = 1, grid.props.grid_w do
			local tile = grid:queryTile(X,Z)
			tile:updateTextureAnimation()

			local mesh = tile.props.tile_mesh
			if mesh then
				local x,y,z = mesh:getVertex(1)
				love.graphics.draw(mesh)
			end
		end
	end


	CAM:dropCanvas()

	renderScaled()
end
