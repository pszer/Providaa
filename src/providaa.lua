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
	Textures.loadTextures()

	self.scene:loadMap(testmap)
end

function PROV:update(dt)
	UPDATE_ANIMATION = false
	self.tick_dt_counter = self.tick_dt_counter + dt
	if (self.tick_dt_counter > 1/self.tick_rate) then
		setTick(getTick()+1)
		self.tick_dt_counter = self.tick_dt_counter - 1/self.tick_rate
		self:onTickChange()
		UPDATE_ANIMATION = true
	end

	local x,y,z = CAM:getDirectionVector()
	print(x,y,z)

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
		cam.cam_roll = cam.cam_roll - 1*dt
	end

	if love.keyboard.isDown("left") then
		cam.cam_yaw = cam.cam_yaw - 1*dt
		cam.cam_roll = cam.cam_roll + 1*dt
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

	local grid = self.scene.props.scene_grid
	local gridd = self.scene.props.scene_grid.props.grid_data
	local walls = self.scene.props.scene_walls
	for Z = 1, grid.props.grid_h do
		for X = 1, grid.props.grid_w do
			--local tile = grid:queryTile(X,Z)
			local tile = gridd[Z][X]
			tile:updateMeshTexture()

			local mesh = tile.props.tile_mesh
			if mesh then
				mesh:draw()
				--love.graphics.draw(mesh)
			end

			local wall = walls[Z][X]
			if wall then
				if wall.eastmesh then wall.eastmesh:draw() end
				if wall.northmesh then wall.northmesh:draw() end
				if wall.westmesh then wall.westmesh:draw() end
				if wall.southmesh then wall.southmesh:draw() end
			end
		end
	end

	CAM:dropCanvas()

	renderScaled()
end

function PROV:onTickChange()

	local grid = self.scene.props.scene_grid
	for Z = 1, grid.props.grid_h do
		for X = 1, grid.props.grid_w do
			local tile = grid:queryTile(X,Z)
			tile:updateMeshTexture()
		end
	end
end
