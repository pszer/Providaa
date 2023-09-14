require 'math'

require "props.sceneprops"
require "light"
require "tick"
require "boundingbox"

local shadersend = require 'shadersend'
local matrix     = require 'matrix'
local cpml       = require 'cpml'
local Renderer   = require 'render'

Scene = {__type = "scene"}
Scene.__index = Scene

function Scene:new(props)
	local this = {
		props = ScenePropPrototype(props),

		shadow_last_update = 0,
		static_models = {},
		dynamic_models = {},

		pushed_static_lights = false
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
	self:fitNewModelPartitionSpace()
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

function Scene:removeModelInstance(inst)
	self.model_bins:remove(inst)

	local function r(inst, collection)
		for i,v in ipairs(collection) do
			if inst == v then table.remove(collection, i) return end
		end
	end
	r(inst, self:getModelInstances())
	if inst:isStatic() then
		r(inst, self:getStaticModelInstances())
	else
		r(inst, self:getDynamicModelInstances())
	end
end

function Scene:getCamera()
	return self.props.scene_camera end
	
function Scene:getModelInstances()
	return self.props.scene_models end
function Scene:getStaticModelInstances()
	return self.static_models end
function Scene:getDynamicModelInstances()
	return self.dynamic_models end

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

function Scene:pushFog(sh)
	sh:send("fog_start", self.props.scene_fog_start)
	sh:send("fog_end", self.props.scene_fog_end)
	sh:send("fog_colour", self.props.scene_fog_colour)
end

function Scene:pushAmbience(sh)
	sh:send("ambient_col", self.props.scene_ambient_col)
end

function Scene:drawGridMap()
	local meshes = self.props.scene_meshes
	for i,v in ipairs(meshes) do
		v:drawAsEnvironment()
	end
end

function Scene:drawGridMapForShadowMapping()
	local props = self.props
	props.scene_generic_mesh:drawGeneric()
end

function Scene:drawModels(update_anims, draw_outlines, model_subset)
	prof.push("draw_models")
	local models = model_subset or self.props.scene_models
	for i,v in ipairs(models) do
		v:draw(nil, update_anims, draw_outlines)
	end
	prof.pop("draw_models")
end

function Scene:drawStaticModels()
	for i,v in ipairs(self.static_models) do
		v:draw(nil, nil, nil)
	end
end

function Scene:cameraUpdate()
	local cam = self.props.scene_camera
	cam:update()
end

function Scene:update()
	self:cameraUpdate()
	prof.push("update_model_partition_space")
	self:updateModelPartitionSpace()
	prof.pop("update_model_partition_space")
end

function Scene:draw(cam)
	cam = cam or self.props.scene_camera

	--self:cameraUpdate()

	--Renderer.setupCanvasFor3D()
	love.graphics.setCanvas{depthstencil = Renderer.scene_depthbuffer}
	love.graphics.clear(0,0,0,0)

	prof.push("skybox")
	self:drawSkybox()
	prof.pop("skybox")

	prof.push("bullshit")
	for i,v in ipairs(self.dynamic_models) do
		v:fillOutBoneMatrices("Walk", getTickSmooth())
	end
	prof.pop("bullshit")

	prof.push("shadowpass")
	self:shadowPass( cam )
	prof.pop("shadowpass")

	prof.push("shaderpushes")
	local sh = Renderer.setupCanvasFor3D()
	self:pushShadowMaps(sh)
	self:pushFog(sh)
	self:pushAmbience(sh)
	self.props.scene_camera:pushToShader(sh)
	prof.pop("shaderpushes")

	prof.push("drawgrid")
	self:drawGridMap()
	prof.pop("drawgrid")
	prof.push("drawmodels")
	local models = self:getModelsInViewFrustrum()
	self:drawModels(false, true, models)
	prof.pop("drawmodels")

	Renderer.dropCanvas()
end

function Scene:shadowPass( cam )
	prof.push("lightspace_mat_gen")
	self.props.scene_lights[1]:generateLightSpaceMatrixFromCamera(cam)
	prof.pop("lightspace_mat_gen")

	local shader = Renderer.shadow_shader
	love.graphics.setDepthMode( "less", true )
	love.graphics.setMeshCullMode("front")
	love.graphics.setShader(Renderer.shadow_shader)

	local props = self.props
	-- dynamic shadow mapping
	prof.push("dyn_shadow_map")
	for i,light in ipairs(props.scene_lights) do
		light:clearDepthMap(true)
		Renderer.setupCanvasForShadowMapping(light, "dynamic", true)

		local light_matrix = light:getLightSpaceMatrix()
		shadersend(shader, "u_lightspace", "column", matrix(light_matrix))

		--love.graphics.setMeshCullMode("front")
		prof.push("dyn_models")
		self:drawModels(false, false)
		prof.pop("dyn_models")

		--love.graphics.setMeshCullMode("front")
		prof.push("dyn_grid")
		self:drawGridMapForShadowMapping()
		prof.pop("dyn_grid")

	end
	prof.pop("dyn_shadow_map")

	-- static shadow mapping
	prof.push("static_shadow_map")
	for i,light in ipairs(props.scene_lights) do
		if light.props.light_static_depthmap_redraw_flag then
			light.props.light_static_depthmap_redraw_flag = false
			light:clearStaticDepthMap(true)
			Renderer.setupCanvasForShadowMapping(light, "static", "true")

			local light_matrix = light:getStaticLightSpaceMatrix()
			shadersend(shader, "u_lightspace", "column", matrix(light_matrix))

			love.graphics.setMeshCullMode("front")
			self:drawStaticModels()

			love.graphics.setMeshCullMode("front")
			self:drawGridMapForShadowMapping()
		end
	end
	--Renderer.dropCanvas()
	prof.pop("static_shadow_map")
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
	--if not self.pushed_static_lights then
		shadersend(shader, "u_dir_static_lightspace", "column", matrix(dir_static_lightspace_mat))
		shadersend(shader, "dir_static_shadow_map", dir_static_shadow_map)
	--end
	shadersend(shader, "dir_shadow_map", dir_shadow_map)
	shadersend(shader, "dir_light_dir", dir_light_dir)
	shadersend(shader, "dir_light_col", dir_light_col)

	self.pushed_static_lights = true
end

-- returns true if skybox drawn
-- otherwise nil
function Scene:drawSkybox(cam)
	local props = self.props
	local skybox_tex_fname = props.scene_skybox
	if skybox_tex_fname == "" then return nil end

	local skybox_img = Textures.queryTexture(props.scene_skybox)
	if not skybox_img then return nil end
	if skybox_img.props.texture_type ~= "cube" then
		print(skybox_img.props.texture_name, " is not a cube image (drawSkybox))",skybox_img.props.texture_type)
		return nil
	end

	Renderer.setupCanvasForSkybox()

	prof.push("skybox_push")
	local sh = love.graphics.getShader()
	shadersend(sh, "skybox", skybox_img:getImage())
	shadersend(sh, "skybox_brightness", props.scene_skybox_hdr_brightness)
	self.props.scene_camera:pushToShader(sh)
	prof.pop("skybox_push")

	prof.push("skybox_draw")
	love.graphics.draw(Renderer.skybox_model)
	prof.pop("skybox_draw")

	--Renderer.dropCanvas()

	return true
end

function Scene:fitNewModelPartitionSpace()
	local scenew, sceneh = self.props.scene_width, self.props.scene_height
	local w = (scenew+2) * TILE_SIZE
	local h = (sceneh+2) * TILE_SIZE
	local x = -TILE_SIZE
	local y = -(sceneh)*TILE_SIZE - TILE_SIZE

	self.model_bins = GridPartition:new(x,y,w,h, 16, 16)
end

function Scene:updateModelPartitionSpace()
	local models = self:getModelInstances()
	local bins = self.model_bins
	for _,model in ipairs(models) do
		if not model:usesModelInstancing() and model:areBoundsChanged() then
			--print("whOOp", model.props.model_i_reference.props.model_name)
			bins:remove(model)
			local pos, size = model:getBoundingBoxPosSize()
			--print(pos[1], pos[2], pos[3],"size", size[1], size[2], size[3])
			bins:insert(model, pos[1], pos[3], size[1], size[3])
			model:informNewBoundsAreHandled()
		end
	end
end

function Scene:getModelsInViewFrustrum()
	local cam = self.props.scene_camera

	local min = { 1/0,  1/0,  1/0}
	local max = {-1/0, -1/0, -1/0}

	local frustrum_corners = cam:generateFrustrumCornersWorldSpace()

	for i=1,8 do
		local vec = frustrum_corners[i]
		if vec[1] < min[1] then min[1] = vec[1] end
		if vec[2] < min[2] then min[2] = vec[2] end
		if vec[3] < min[3] then min[3] = vec[3] end

		if vec[1] > max[1] then max[1] = vec[1] end
		if vec[2] > max[2] then max[2] = vec[2] end
		if vec[3] > max[3] then max[3] = vec[3] end
	end

	local x,y,w,h = min[1], min[3], max[1]-min[1], max[3]-min[3]

	local models, outside_models = self.model_bins:getInsideRectangle(x,y,w,h)
	for _,m in ipairs(outside_models) do
		local pos,size = m:getBoundingBoxPosSize()
		local is_inside = testRectInRectPosSize(x,y,w,h,
		  pos[1], pos[3], size[1], size[3])

		if is_inside then
			table.insert(models, m)
		end
	end

	-- for now, we just render ALL instancing-using models
	for _,m in ipairs(self.props.scene_models) do
		if m:usesModelInstancing() then
			table.insert(models, m)
		end
	end

	return models
end
