require 'math'

require "props.sceneprops"
require "light"
require "tick"

local shadersend = require 'shadersend'
local matrix     = require 'matrix'
local cpml       = require 'cpml'

Scene = {__type = "scene"}
Scene.__index = Scene

function Scene:new(props)
	local this = {
		props = ScenePropPrototype(props),

		shadow_last_update = 0,
		static_models = {},
		dynamic_models = {}
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

-- argument can be a model instance or a table of model instances
function Scene:addModelInstance(inst)

	if provtype(inst) == "modelinstance" then

		table.insert(self.props.scene_models, inst)
		if inst.props.model_i_static then
			table.insert(self.static_models, inst)
		else
			table.insert(self.dynamic_models, inst)
		end

	elseif type(inst) == "table" then
	
		for i,inst in ipairs(inst) do
			self:addModelInstance(inst)
		end

	end
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

	props.scene_grid:applyAttributes()
	WallTile.applyAttributes(props.scene_wall_tiles, props.scene_width, props.scene_height)
end

function Scene:generateGenericMesh(map, scene_meshes)
	local props = self.props
	local bottom_mesh = Map.generateBottomMesh(map)
	local meshes = {bottom_mesh, unpack(scene_meshes)}
	--local meshes = scene_meshes

	props.scene_generic_mesh = Mesh.mergeMeshes(Textures.queryTexture("nil.png"), meshes)
end

function Scene:pushFog()
	local sh = love.graphics.getShader()
	sh:send("fog_start", self.props.scene_fog_start)
	sh:send("fog_end", self.props.scene_fog_end)
	sh:send("fog_colour", self.props.scene_fog_colour)
end

function Scene:pushAmbience()
	local sh = love.graphics.getShader()
	sh:send("ambient_col", self.props.scene_ambient_col)
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

function Scene:drawModels(update_anims, draw_outlines)
	for i,v in ipairs(self.props.scene_models) do
		v:draw(nil, update_anims, draw_outlines)
	end
end

function Scene:drawStaticModels()
	for i,v in ipairs(self.static_models) do
		v:draw(nil, nil, nil)
	end
end

function Scene:draw(cam)
	cam = cam or self.props.scene_camera

	cam:update()
	cam:generateViewMatrix()
	--cam:generateFrustrumCornersWorldSpace()

	Renderer.setupCanvasFor3D()
	love.graphics.clear(0,0,0,0)

	self:drawSkybox()

	for i,v in ipairs(self.props.scene_models) do
		v:fillOutBoneMatrices("Reference Pose", getTickSmooth())
	end

	--self.props.scene_lights[1].props.light_dir[3] = -math.cos(getTick()/45)*2
	--self.props.scene_lights[1].props.light_dir[1] = -math.cos(getTick()/45)*3
	self:shadowPass( cam )

	Renderer.setupCanvasForContour()
	self.props.scene_camera:pushToShader()

	Renderer.setupCanvasFor3D()
	self:pushShadowMaps()

	self:pushFog()
	self:pushAmbience()
	self.props.scene_camera:pushToShader()

	self:drawGridMap()
	self:drawModels(false, true)

	Renderer.dropCanvas()
end

function Scene:shadowPass( cam )
	self.props.scene_lights[1]:generateLightSpaceMatrixFromCamera(cam)

	local props = self.props
	-- dynamic shadow mapping
	for i,light in ipairs(props.scene_lights) do
		light:clearDepthMap()
		Renderer.setupCanvasForShadowMapping(light)

		local shader = love.graphics.getShader()
		local light_matrix = light:getLightSpaceMatrix()
		shadersend(shader, "u_lightspace", "column", matrix(light_matrix))

		love.graphics.setMeshCullMode("front")
		self:drawModels(false, false)

		love.graphics.setMeshCullMode("front")
		self:drawGridMapForShadowMapping()

		Renderer.dropCanvas()
	end

	-- static shadow mapping
	for i,light in ipairs(props.scene_lights) do
		if light.props.light_static_depthmap_redraw_flag then
			light.props.light_static_depthmap_redraw_flag = false
			light:clearStaticDepthMap()
			Renderer.setupCanvasForShadowMapping(light, "static")

			local shader = love.graphics.getShader()
			local light_matrix = light:getStaticLightSpaceMatrix()
			shadersend(shader, "u_lightspace", "column", matrix(light_matrix))

			love.graphics.setMeshCullMode("front")
			self:drawStaticModels()

			love.graphics.setMeshCullMode("front")
			self:drawGridMapForShadowMapping()

			Renderer.dropCanvas()
		end
	end
end

function Scene:pushShadowMaps(shader)
	local lights = self.props.scene_lights
	local light_count = #lights
	local shader = shader or love.graphics.getShader()

	local dir_light_found = false
	local dir_lightspace_mat
	local dir_static_lightspace_mat
	local dir_shadow_map
	local dir_static_shadow_map
	local dir_light_dir
	local dir_light_col

	--local point_shadow_maps = {}

	for i,light in ipairs(lights) do
		local light_type = light:getLightType()

		if light_type == "directional" then
			if not dir_light_found then
				dir_light_found = true
				dir_lightspace_mat = light:getLightSpaceMatrix()
				dir_static_lightspace_mat = light:getStaticLightSpaceMatrix()
				dir_shadow_map = light:getDepthMap()
				dir_static_shadow_map = light:getStaticDepthMap()
				dir_light_dir = light:getLightDirection()
				dir_light_col = light:getLightColour()
			else
				print("MULTIPLE DIRECTIONAL LIGHTS, IGNORING")
			end
			--shadow_maps[i] = light.props.light_static_depthmap
			--lightspace_mats[i] = matrix(light.props.light_static_lightspace_matrix)
		else

		end
	end
	
	--shadersend(shader, "u_lightspaces", "column", unpack(lightspace_mats))
	--shadersend(shader, "shadow_maps", unpack(shadow_maps))
	--shadersend(shader, "LIGHT_COUNT", light_count)
	shadersend(shader, "u_dir_lightspace", "column", matrix(dir_lightspace_mat))
	shadersend(shader, "u_dir_static_lightspace", "column", matrix(dir_static_lightspace_mat))
	shadersend(shader, "dir_shadow_map", dir_shadow_map)
	shadersend(shader, "dir_static_shadow_map", dir_static_shadow_map)
	shadersend(shader, "dir_light_dir", dir_light_dir)
	shadersend(shader, "dir_light_col", dir_light_col)
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
