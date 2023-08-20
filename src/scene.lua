require "props.sceneprops"
require "math"

Scene = {__type = "scene"}
Scene.__index = Scene

function Scene:new(props)
	local this = {
		props = ScenePropPrototype(props),
	}

	setmetatable(this,Scene)

	return this
end

function Scene:loadMap(map)
	local props = self.props
	local gridsets, wallsets

	props.scene_grid, props.scene_walls, gridsets, wallsets =
		Map.loadMap(map)
	props.scene_width = map.width
	props.scene_height = map.height

	self:generateMeshes(map, props.scene_grid, props.scene_walls, gridsets, wallsets)
end

function Scene:generateMeshes(map, grid, walls, gridsets, wallsets)
	local props = self.props

	local wallmeshes = Map.getWallMeshes(map, props.scene_walls, wallsets)
	local gridmeshes = Map.getGridMeshes(map, props.scene_grid, gridsets)

	for i,mesh in ipairs(wallmeshes) do
		table.insert(self.props.scene_meshes,mesh) end
	for i,mesh in ipairs(gridmeshes) do
		table.insert(self.props.scene_meshes,mesh) end
end

function Scene:generateGridMesh()
	local props = self.props
	return props.scene_grid:generateMesh()
	--props.scene_grid:optimizeMesh()
end

function Scene:generateWallMesh()
	local props = self.props
	local walls = props.scene_walls
	local height = props.scene_height
	local width = props.scene_width

	local meshes = {}
	local mesh_count = 1

	local function genWall(z,x)
		local wall = walls[z][x]

		if not wall then return end

		local wx,wy,wz = Tile.tileCoordToWorld(x,0,z)
		local u,v = Wall.u, Wall.v

		if wall.west then
			local vert = {}
			local mesh = wall.westmesh
			for i=1,4 do
				local wallv = wall.west[i]
				--vert = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+wallv[3]*TILE_SIZE}
				vert[i] = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+wallv[3]*TILE_SIZE, u[i], -wallv[2]}

				--mesh.mesh:setVertex(i, vert[1],vert[2],vert[3],u[i],-wallv[2])
			end
			--mesh:calculateNormal()
			mesh:setRectangle(1,vert[1],vert[2],vert[3],vert[4])
			mesh:fitTexture(TILE_SIZE, -TILE_HEIGHT)
			meshes[mesh_count] = mesh
			mesh_count = mesh_count + 1
		end

		if wall.south then
			local vert = {}
			local mesh = wall.southmesh
			for i=1,4 do
				local wallv = wall.south[i]
				vert[i] = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+wallv[3]*TILE_SIZE, u[i], -wallv[2]}

				--mesh.mesh:setVertex(i, vert[1],vert[2],vert[3],u[i],-wallv[2])
			end
			--mesh:calculateNormal()
			mesh:setRectangle(1,vert[1],vert[2],vert[3],vert[4])
			mesh:fitTexture(TILE_SIZE, -TILE_HEIGHT)
			meshes[mesh_count] = mesh
			mesh_count = mesh_count + 1
		end

		if wall.east then
			local vert = {}
			local mesh = wall.eastmesh
			for i=1,4 do
				local wallv = wall.east[i]
				vert[i] = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+(wallv[3]-1)*TILE_SIZE, u[i], -wallv[2]}

				--mesh.mesh:setVertex(i, vert[1],vert[2],vert[3],u[i],-wallv[2])
			end
			--mesh:calculateNormal()
			mesh:setRectangle(1,vert[1],vert[2],vert[3],vert[4])
			mesh:fitTexture(TILE_SIZE, -TILE_HEIGHT)
			meshes[mesh_count] = mesh
			mesh_count = mesh_count + 1
		end

		if wall.north then
			local vert = {}
			local mesh = wall.northmesh
			for i=1,4 do
				local wallv = wall.north[i]
				vert[i] = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+(wallv[3]-1)*TILE_SIZE, u[i], -wallv[2]}

				--mesh.mesh:setVertex(i, vert[1],vert[2],vert[3],u[i],-wallv[2])
			end
			--mesh:calculateNormal()
			mesh:setRectangle(1,vert[1],vert[2],vert[3],vert[4])
			mesh:fitTexture(TILE_SIZE, -TILE_HEIGHT)
			meshes[mesh_count] = mesh
			mesh_count = mesh_count + 1
		end
	end

	for z=1,props.scene_height do
		for x=1,props.scene_width do
			local wall = walls[z][x]
			genWall(z,x)
		end
	end

	local tex = Textures.queryTexture("wall.png")
	local newmesh = Mesh.mergeMeshes(tex, meshes)
	return newmesh
end

function Scene:fitTextures()
	local props = self.props
	for z=1,props.scene_height do
		for x=1,props.scene_width do
			local tile = props.scene_grid:queryTile(x,z)
			local tilemesh = tile.props.tile_mesh

			if tilemesh then
				tilemesh:fitTexture(TILE_SIZE, TILE_SIZE)
			end

			local wall = props.scene_walls[z][x]
			if wall then
				if wall.westmesh then wall.westmesh:fitTexture(TILE_SIZE, -TILE_HEIGHT) end
				if wall.eastmesh then wall.eastmesh:fitTexture(TILE_SIZE, -TILE_HEIGHT) end
				if wall.northmesh then wall.northmesh:fitTexture(TILE_SIZE, -TILE_HEIGHT) end
				if wall.southmesh then wall.southmesh:fitTexture(TILE_SIZE, -TILE_HEIGHT) end
			end
		end
	end
end

function Scene:pushFog()
	local sh = love.graphics.getShader()
	sh:send("fog_start", self.props.scene_fog_start)
	sh:send("fog_end", self.props.scene_fog_end)
	sh:send("fog_colour", self.props.scene_fog_colour)
end

function Scene:draw(cam)

	cam:setupCanvas()
	cam:generateViewMatrix()
	self:pushFog()

	local props = self.props

	local fog = props.scene_fog_colour
	local fog_end = props.scene_fog_end
	love.graphics.clear(fog[1],fog[2],fog[3],1)
	--love.graphics.setColor(1,1,1,0.5)
	--love.graphics.setColor(1,1,1,1)

	local grid = props.scene_grid
	local gridd = props.scene_grid.props.grid_data
	local walls = props.scene_walls

	local dirx,diry,dirz = cam:getDirectionVector()
	local camx,camy,camz = cam:getPosition()

	for i,v in ipairs(self.props.scene_meshes) do
		v:draw()
	end

	cam:dropCanvas()
end
