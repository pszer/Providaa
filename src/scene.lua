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
