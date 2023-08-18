local matrix = require "matrix"
local cpml = require "cpml"

require "render"
require "grid"

PROV = {
	grid = {},
	dirt = love.graphics.newImage("dirt.jpg"),
	mesh = love.graphics.newMesh(4, "triangles", "dynamic")
}

function PROV:load()
	local grid = PROV.grid
	for z=1,60 do
		grid[z] = {}
		for x=1,16 do
			grid[z][x] = {0,0,0,0}
		end
	end

	for i=1,25 do
		local x = math.floor(math.random()*14)+1
		local z = math.floor(math.random()*58)+1

		grid[z][x][2] = grid[z][x][2] - 25
		grid[z][x+1][1] = grid[z][x+1][1] - 25
		grid[z+1][x][3] = grid[z+1][x][3] - 25 
		grid[z+1][x+1][4] = grid[z+1][x+1][4] - 25
	end
	print("done")
end

function PROV:update(dt)
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

	--CAM:transformCoords()
	--love.graphics.setCanvas(CAM.props.cam_viewport)
	--
	--
	
	CAM:setupCanvas()

	love.graphics.setMeshCullMode( "front" )

	love.graphics.clear(0.1,0.1,0.1,1)
	love.graphics.setColor(1,1,1,0.5)
	love.graphics.setColor(1,1,1,1)
	--love.graphics.line(-10000,0,10000,0)
	--love.graphics.line(0,-10000,0,10000)

	local atypes = {
	  {"VertexPosition", "float", 3},
	  {"VertexTexCoord", "float", 2},
	}

	local mesh = PROV.mesh
	local testmesh = love.graphics.newMesh(atypes, 4, "triangles", "dynamic")

	local vmap = {1,2,3, 3,4,1}
	local vmap2 = {1,2,3, 3,4,1}
	mesh:setTexture(PROV.dirt)
	mesh:setVertexMap(vmap)

	testmesh:setTexture(PROV.dirt)
	testmesh:setVertexMap(vmap2)
	testmesh:setDrawRange(1,8)

	local proj = CAM:generatePerspectiveMatrix()
	local view = CAM:generateViewMatrix()

	love.graphics.setShader(Renderer.vertex_shader)

	Renderer.vertex_shader:send("u_proj", "column", matrix(CAM.props.cam_perspective_matrix))
	Renderer.vertex_shader:send("u_view", "column", matrix(CAM.props.cam_view_matrix))

	for Z=math.min(48,48-math.ceil(cliptz)),1,-1 do
	--for Z=1,48 do
		for X=1, 16 do
			square = PROV.grid[Z][X]

			local x,y,z = {},{},{}
			y[1],y[2],y[3],y[4] = square[1],square[2],square[3],square[4]

			x[1], z[1] = X*32, -Z*32
			y[1]     = y[1] * 1
			x[2], z[2] = X*32+32, -Z*32
			y[2]     = y[2] * 1
			x[3], z[3] = X*32+32, -Z*32+32
			y[3]     = y[3] * 1
			x[4], z[4] = X*32, -Z*32+32
			y[4]     = y[4] * 1

			local u = {0,1,1,0}
			local v = {0,0,1,1}

			for i=1,4 do
				--local x_,y_ = cameraCoord3DScaled(x[i],y[i],z[i])
				--mesh:setVertex(i, x_,y_, u[i], v[i])

				testmesh:setVertex(i, x[i], y[i], z[i], u[i], v[i])

				local V = cpml.vec3(x[i],y[i],z[i])
				V = (view * V)
				local P = cpml.vec3(x[i],y[i],z[i])
				P = proj * (view * P)
				--print(view:to_string(view))
				--print(x[i],y[i],z[i], V:to_string(V), P:to_string(P))
			end

			--for i=1,4 do
			--	x[i],y[i],z[i] = translateCoord3D(x[i],y[i],z[i])
			--end

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
				--love.graphics.draw(mesh)
			end

			love.graphics.draw(testmesh)

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

	love.graphics.setMeshCullMode("none")
	love.graphics.setShader()

	renderScaled()

	--render_viewport()
end
