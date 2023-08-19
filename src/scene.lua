require "props.sceneprops"

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
	props.scene_grid, props.scene_walls =
		Map.loadMap(map)
	props.scene_width = map.width
	props.scene_height = map.height

	self:generateGridMesh()
	self:generateWallMesh()
	self:fitTextures()

	--[[for z=1,map.height do
		for x=1,map.width do
			local tile = props.scene_grid:queryTile(x,z)
			local mesh = tile.props.tile_mesh
			if mesh then mesh:translateTexture(-0.75,0) end
			if mesh then mesh:scaleTexture(2) end
		end
	end]]
end

function Scene:generateGridMesh()
	local props = self.props
	props.scene_grid:generateMesh()
	props.scene_grid:optimizeMesh()
end

function Scene:generateWallMesh()
	local props = self.props
	local walls = props.scene_walls
	local height = props.scene_height
	local width = props.scene_width

	local function genWall(z,x)
		local wall = walls[z][x]

		if not wall then return end

		local wx,wy,wz = Tile.tileCoordToWorld(x,0,width - z + 1)
		local u,v = Wall.u, Wall.v

		if wall.west then
			local vert = {}
			local mesh = wall.westmesh
			for i=1,4 do
				local wallv = wall.west[i]
				vert = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+wallv[3]*TILE_SIZE}

				mesh.mesh:setVertex(i, vert[1],vert[2],vert[3],u[i],-wallv[2])
			end
		end

		if wall.south then
			local vert = {}
			local mesh = wall.southmesh
			for i=1,4 do
				local wallv = wall.south[i]
				vert = {wx+wallv[1]*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+wallv[3]*TILE_SIZE}

				mesh.mesh:setVertex(i, vert[1],vert[2],vert[3],u[i],-wallv[2])
			end
		end

		if wall.east then
			local vert = {}
			local mesh = wall.eastmesh
			for i=1,4 do
				local wallv = wall.east[i]
				vert = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+(wallv[3]-1)*TILE_SIZE}

				mesh.mesh:setVertex(i, vert[1],vert[2],vert[3],u[i],-wallv[2])
			end
		end

		if wall.north then
			local vert = {}
			local mesh = wall.northmesh
			for i=1,4 do
				local wallv = wall.north[i]
				vert = {wx+(wallv[1]+1)*TILE_SIZE,  wallv[2]*TILE_HEIGHT, wz+(wallv[3]-1)*TILE_SIZE}

				mesh.mesh:setVertex(i, vert[1],vert[2],vert[3],u[i],-wallv[2])
			end
		end
	end

	for z=1,props.scene_height do
		for x=1,props.scene_width do
			local wall = walls[z][x]

			genWall(z,x)
		end
	end
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
