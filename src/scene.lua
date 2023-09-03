require 'math'

require "props.sceneprops"
require "light"

local shadersend = require 'shadersend'
local matrix     = require 'matrix'
local cpml       = require 'cpml'

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
		table.insert(props.scene_meshes,mesh) end
	for i,mesh in ipairs(gridmeshes) do
		table.insert(props.scene_meshes,mesh) end

	self:generateGenericMesh(map, props.scene_meshes)
	--props.scene_generic_mesh = Mesh.mergeMeshes(Textures.queryTexture("nil.png"), props.scene_meshes)

	props.scene_grid:applyAttributes()
	--Wall.applyAttributes(props.scene_walls)
	WallTile.applyAttributes(props.scene_wall_tiles, props.scene_width, props.scene_height)
end

function Scene:generateGenericMesh(map, scene_meshes)
	local props = self.props
	local bottom_mesh = Map.generateBottomMesh(map)
	local meshes = {bottom_mesh, unpack(scene_meshes)}

	props.scene_generic_mesh = Mesh.mergeMeshes(Textures.queryTexture("dirt.png"), meshes)
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
	--sh:send("light_dir", self.props.scene_light_dir)
	sh:send("light_dir", self.props.scene_lights[1].props.light_dir)
	sh:send("ambient_col", self.props.scene_ambient_col)
	--sh:send("ambient_str", self.props.scene_ambient_str)
end

function Scene:drawGridMap()
	local props = self.props
	for i,v in ipairs(props.scene_meshes) do
		v:drawAsEnvironment()
	end
	--props.scene_generic_mesh:drawGeneric()
end

function Scene:drawGridMapForShadowMapping()
	local props = self.props
	props.scene_generic_mesh:drawGeneric()
end

function Scene:drawModels(updateAnims)
	for i,v in ipairs(self.props.scene_models) do
		v:draw(nil, updateAnims)
	end
end

function Scene:draw(cam)
	cam = cam or self.props.scene_camera

	--self.props.scene_light_dir[1] = math.sin(getTick()/50)/2
	--self.props.scene_light_dir[3] = math.cos(getTick()/50)/2
	--
	--self.props.scene_lights[1].props.light_dir[3] = -math.cos(getTick()/45)*2
	--self.props.scene_lights[1].props.light_dir[1] = math.sin(getTick()/45)*2
	--self.props.scene_lights[1]:generateLightSpaceMatrix()

	cam:update()
	cam:generateViewMatrix()
	cam:generateFrustrumCornersWorldSpace()

	self.props.scene_lights[1]:generateLightSpaceMatrixFromCamera(cam)

	--local corners = cam:getFrustrumCornersWorldSpace()

	Renderer.setupCanvasFor3D()
	love.graphics.clear(0,0,0,0)

	local skybox_drawn = self:drawSkybox()

	for i,v in ipairs(self.props.scene_models) do
		v:fillOutBoneMatrices("Walk", getTickSmooth())
	end

	--self.props.scene_camera:pushToShader()
	self:shadowPass()

	Renderer.setupCanvasFor3D()

	self:pushFog()
	self:pushAmbience()
	self.props.scene_camera:pushToShader()
	self:pushShadowMaps()

	local props = self.props

	local fog = props.scene_fog_colour
	local fog_end = props.scene_fog_end
	if not skybox_drawn then love.graphics.clear(fog[1],fog[2],fog[3],1) end

	self:drawGridMap()
	self:drawModels(false)
	
	--for i,v in ipairs(self.props.scene_models) do
	--	v:draw(nil, false)
	--end

	Renderer.dropCanvas()
end

function Scene:shadowPass()
	local props = self.props
	for i,light in ipairs(props.scene_lights) do
		light:clearDepthMap()
		Renderer.setupCanvasForShadowMapping(light)
		local shader = love.graphics.getShader()

		local light_matrix = light:getLightSpaceMatrix()
		shadersend(shader, "u_lightspace", "column", matrix(light_matrix))

		love.graphics.setMeshCullMode("back")
		self:drawModels(false)

		love.graphics.setMeshCullMode("back")
		--self:drawGridMap()
		self:drawGridMapForShadowMapping()

		love.graphics.setMeshCullMode("front")
		Renderer.dropCanvas()
	end
end

function Scene:pushShadowMaps(shader)
	local lights = self.props.scene_lights
	local light_count = #lights
	local shader = shader or love.graphics.getShader()

	local lightspace_mats = {}
	local shadow_maps = {}

	for i,light in ipairs(lights) do
		shadow_maps[i] = light.props.light_depthmap
		lightspace_mats[i] = matrix(light.props.light_lightspace_matrix)
	end
	
	shadersend(shader, "u_lightspaces", "column", unpack(lightspace_mats))
	shadersend(shader, "shadow_maps", unpack(shadow_maps))
	shadersend(shader, "LIGHT_COUNT", light_count)
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
	shadersend(sh, "skybox", skybox_img:getImage())
	shadersend(sh, "skybox_brightness", self.props.scene_skybox_hdr_brightness)
	self.props.scene_camera:pushToShader(sh)

	love.graphics.draw(Renderer.skybox_model)

	Renderer.dropCanvas()

	return true
end
