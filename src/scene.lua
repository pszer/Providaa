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

	props.scene_grid, props.scene_walls, props.scene_wall_tiles, gridsets, wallsets =
		Map.loadMap(map)
	props.scene_width = map.width
	props.scene_height = map.height

	self:generateMeshes(map, props.scene_grid, props.scene_walls, gridsets, wallsets)
end

function Scene:generateMeshes(map, grid, walls, gridsets, wallsets)
	local props = self.props

	local gridmeshes = Map.getGridMeshes(map, props.scene_grid, gridsets)
	local wallmeshes = Map.getWallMeshes(map, props.scene_walls, wallsets, props.scene_wall_tiles)

	for i,mesh in ipairs(wallmeshes) do
		table.insert(self.props.scene_meshes,mesh) end
	for i,mesh in ipairs(gridmeshes) do
		table.insert(self.props.scene_meshes,mesh) end

	props.scene_grid:applyAttributes()
	--Wall.applyAttributes(props.scene_walls)
	WallTile.applyAttributes(props.scene_wall_tiles, props.scene_width, props.scene_height)
end

function Scene:pushFog()
	local sh = love.graphics.getShader()
	sh:send("fog_start", self.props.scene_fog_start)
	sh:send("fog_end", self.props.scene_fog_end)
	sh:send("fog_colour", self.props.scene_fog_colour)
end

function Scene:pushAmbience()
	local sh = love.graphics.getShader()
	sh:send("light_col", self.props.scene_light_col)
	sh:send("light_dir", self.props.scene_light_dir)
	sh:send("ambient_col", self.props.scene_ambient_col)
	sh:send("ambient_str", self.props.scene_ambient_str)
end

function Scene:draw(cam)
	cam = cam or self.props.scene_camera

	cam:update()
	cam:generateViewMatrix()


	Renderer.setupCanvasFor3D()
	love.graphics.clear(0,0,0,1)

	local skybox_drawn = self:drawSkybox()

	Renderer.setupCanvasFor3D()

	self:pushFog()
	self:pushAmbience()
	self.props.scene_camera:pushToShader()

	local props = self.props

	local fog = props.scene_fog_colour
	local fog_end = props.scene_fog_end
	if not skybox_drawn then love.graphics.clear(fog[1],fog[2],fog[3],1) end

	local grid = props.scene_grid
	local gridd = props.scene_grid.props.grid_data
	local walls = props.scene_walls

	local dirx,diry,dirz = cam:getDirectionVector()
	local camx,camy,camz = cam:getPosition()

	for i,v in ipairs(self.props.scene_meshes) do
		v:draw()
	end

	Renderer.dropCanvas()
end

-- returns true if skybox drawn
-- otherwise nil
function Scene:drawSkybox(cam)
	local skybox_tex_fname = self.props.scene_skybox
	if skybox_tex_fname == "" then return nil end

	local skybox_img = Textures.queryTexture(self.props.scene_skybox)
	if not skybox_img then return nil end
	if skybox_img.props.texture_type ~= "cube" then
		print(skybox_img.props.texture_name, " is not a cube image (drawSkybox))",skybox_img.props.texture_type)
		return nil
	end

	Renderer.setupCanvasForSkybox()

	local sh = love.graphics.getShader()
	sh:send("skybox", skybox_img:getImage())
	self.props.scene_camera:pushToShader(sh)

	love.graphics.draw(Renderer.skybox_model)

	Renderer.dropCanvas()

	return true
end
