require "render"

PROV = {
	grid = {},
	dirt = love.graphics.newImage("dirt.jpg"),
	mesh = love.graphics.newMesh(4, "triangles", "dynamic")
}

function PROV:load()
	local grid = PROV.grid
	for z=1,16 do
		grid[z] = {}
		for x=1,16 do
			grid[z][x] = {0,0,0,0}
		end
	end
	print("done")
end

function PROV:update(dt)
	local cam = CAM.props
	if love.keyboard.isDown("w") then
		cam.cam_z = cam.cam_z + 1000*dt
	end
	if love.keyboard.isDown("s") then
		cam.cam_z = cam.cam_z - 1000*dt
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


	CAM:transformCoords2()
	CAM:setupCanvas()

	love.graphics.clear(0,0,0)
	love.graphics.setColor(1,1,1,1)

	local mesh = PROV.mesh
	mesh:setTexture(PROV.dirt)
	local vmap = {1,2,3, 3,4,1}
	mesh:setVertexMap(vmap)

	for Z=1,16 do
		for X=1, 16 do
			square = PROV.grid[Z][X]

			local x,y,z = {},{},{}
			y[1],y[2],y[3],y[4] = square[1],square[2],square[3],square[4]

			x[1], z[1] = X*32, Z*32
			y[1]     = y[1] * 32
			x[2], z[2] = X*32+32, Z*32
			y[2]     = y[1] * 32
			x[3], z[3] = X*32+32, Z*32-32
			y[3]     = y[1] * 32
			x[4], z[4] = X*32, Z*32-32
			y[4]     = y[1] * 32

			local u = {0,1,1,0}
			local v = {0,0,1,1}

			for i=1,4 do
				local x_,y_ = cameraCoord3DScaled(x[i],y[i],z[i])
				mesh:setVertex(i, x_,y_, u[i], v[i])
			end

			for i=1,4 do
				x[i],y[i],z[i] = translateCoord3D(x[i],y[i],z[i])
			end

			local cliptest =
				clipTriangleTest({
					{x[1],y[1],z[1]},
					{x[2],y[2],z[2]},
					{x[3],y[3],z[3]}}) or
				clipTriangleTest({
					{x[3],y[3],z[3]},
					{x[4],y[4],z[4]},
					{x[1],y[1],z[1]}})
			if not cliptest then
				love.graphics.draw(mesh)
			end

			--local a,b,c,d
			--a,b = cameraCoord3DScaled(x1,y1,z1)
			--c,d = cameraCoord3DScaled(x2,y2,z2)
			--love.graphics.line(a,b,c,d)
			--a,b = cameraCoord3DScaled(x2,y2,z2)
			--c,d = cameraCoord3DScaled(x3,y3,z3)
			--love.graphics.line(a,b,c,d)
			--a,b = cameraCoord3DScaled(x3,y3,z3)
			--c,d = cameraCoord3DScaled(x4,y4,z4)
			--love.graphics.line(a,b,c,d)
			--a,b = cameraCoord3DScaled(x4,y4,z4)
			--c,d = cameraCoord3DScaled(x1,y1,z1)
			--love.graphics.line(a,b,c,d)
		end
	end

	renderScaled()

	--render_viewport()
end
