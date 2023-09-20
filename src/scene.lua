require 'math'

require "props.sceneprops"
require "light"
require "tick"
require "boundingbox"
require "animthread"

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

		pushed_static_lights = false,
		
		force_redraw_static_shadow = false,

		map_mesh = nil

		--animthreads = AnimThreads:new(4)
	}

	setmetatable(this,Scene)

	return this
end

function Scene:loadMap(map)
	self.map_mesh = Map.generateMapMesh(map)

	--local props = self.props
	--local gridsets, wallsets

	--[[props.scene_grid, props.scene_walls, props.scene_wall_tiles, gridsets, wallsets =
		Map.loadMap(map)
	props.scene_width = map.width
	props.scene_height = map.height

	self:generateMeshes(map, props.scene_grid, props.scene_walls, gridsets, wallsets)--]]
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
	inst:releaseModel()
end

-- dangerous function
function Scene:__removeAllModels()
	local models = self.props.scene_models
	local count = #models
	for i = count,1,-1 do
		self.model_bins:remove(models[i])
		models[i]:releaseModel()
		models[i] = nil
	end

	self.static_models = {}
	self.dynamic_models = {}
end

-- returns a list of all models in this scene
function Scene:listAllModels()
	local set = require "set"
	local model_set = set:new()

	for i,v in ipairs(self:getModelInstances()) do
		local model = v:getModel()
		model_set:add(v)
	end

	return model_set
end

function Scene:getCamera()
	return self.props.scene_camera end
	
function Scene:getModelInstances()
	return self.props.scene_models end
function Scene:getStaticModelInstances()
	return self.static_models end
function Scene:getDynamicModelInstances()
	return self.dynamic_models end

--[[function Scene:generateMeshes(map, grid, walls, gridsets, wallsets)
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

	props.scene_generic_mesh = Mesh.mergeMeshes(Textures.loadTexture("nil.png"), meshes)
end--]]

function Scene:pushFog(sh)
	sh:send("fog_start", self.props.scene_fog_start)
	sh:send("fog_end", self.props.scene_fog_end)
	sh:send("fog_colour", self.props.scene_fog_colour)
	sh:send("skybox_brightness", self.props.scene_skybox_hdr_brightness)
end

function Scene:pushAmbience(sh)
	sh:send("ambient_col", self.props.scene_ambient_col)
end

local __id = cpml.mat4.new()
function Scene:drawGridMap()
	--local meshes = self.props.scene_meshes
	--for i,v in ipairs(meshes) do
	--	v:drawAsEnvironment()
	--end
	local shader = love.graphics.getShader()
	shadersend(shader,"texture_animated", false)

	shadersend(shader,"u_uses_tileatlas", true)
	shadersend(shader,"u_tileatlas_uv", unpack(self.map_mesh.uvs))
	shadersend(shader,"u_model", "column", __id)
	shadersend(shader,"u_normal_model", "column", __id)

	shadersend(shader,"u_skinning", 0)
	love.graphics.draw(self.map_mesh.mesh)
	shadersend(shader,"u_uses_tileatlas", false)
end

function Scene:drawGridMapForShadowMapping()
	local props = self.props
	--props.scene_generic_mesh:drawGeneric()
	local shader = love.graphics.getShader()
	shadersend(shader,"u_model", "column", __id)
	shadersend(shader,"u_normal_model", "column", __id)
	--shadersend(shader,"u_uses_tileatlas", false)
	love.graphics.draw(self.map_mesh.simple_mesh)
end

function Scene:drawModels(update_anims, is_main_pass, model_subset)
	prof.push("draw_models")
	local models = model_subset or self.props.scene_models
	--print("models, ", #models)
	for i,v in ipairs(models) do
		v:draw(nil, update_anims, is_main_pass)
	end
	prof.pop("draw_models")
end

function Scene:drawStaticModels(model_subset)
	if model_subset then		
		for i,v in ipairs(model_subset) do
			if v:isStatic() then
				v:draw(nil, nil, nil)
			end
		end
		return
	end

	for i,v in ipairs(self.static_models) do
		v:draw(nil, nil, nil)
	end
end

function Scene:cameraUpdate()
	local cam = self.props.scene_camera
	cam:update()
end

function Scene:update()
	prof.push("update_model_partition_space")
	self:updateModelPartitionSpace()
	self:cameraUpdate()
	prof.pop("update_model_partition_space")
end

function Scene:updateModelMatrices()
	for i,v in ipairs(self.props.scene_models) do
		v:modelMatrix()
	end
end

function Scene:updateLights( cam )
	for i,v in ipairs(self.props.scene_lights) do
		v:generateMatrices(cam)
		--v:generateLightSpaceMatrixFromCamera(cam)
	end
end

local count = 0
function Scene:draw(cam)
	if count == 1 then
		self:redrawStaticMaps()
	end
	count = count+1

	cam = cam or self.props.scene_camera

	prof.push("scene_update")
	self:update()
	prof.pop("scene_update")

	--Renderer.setupCanvasFor3D()
	love.graphics.setCanvas{depthstencil = Renderer.scene_depthbuffer}
	love.graphics.clear(0,0,0,0)

	prof.push("skybox")
	self:drawSkybox()
	prof.pop("skybox")

	prof.push("shadowpass")
	self:updateLights( cam )
	self:shadowPass( cam )
	prof.pop("shadowpass")

	self:updateModelAnimatedFaces()

	prof.push("shaderpushes")
	local sh = Renderer.setupCanvasFor3D()
	prof.push("pushshadowmaps")
	self:pushShadowMaps(sh)
	prof.pop("pushshadowmaps")
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

function Scene:dirDynamicShadowPass( shader , light )
	light:clearDepthMap(false)
	Renderer.setupCanvasForDirShadowMapping(light, "dynamic", true)

	local light_matrix = light:getLightSpaceMatrix()
	shadersend(shader, "u_lightspace", "column", matrix(light_matrix))
	shader:send("point_light", false)

	local dims_min, dims_max = light:getLightSpaceMatrixGlobalDimensionsMinMax()
	local in_view = self:getModelsInViewFrustrum(dims_min, dims_max)

	--love.graphics.setMeshCullMode("front")
	prof.push("dyn_models")
	self:drawModels(false, false, in_view)
	prof.pop("dyn_models")

	--love.graphics.setMeshCullMode("front")
	prof.push("dyn_grid")
	self:drawGridMapForShadowMapping()
	prof.pop("dyn_grid")
end

function Scene:dirStaticShadowPass( shader , light )
	light.props.light_static_depthmap_redraw_flag = false
	light:clearStaticDepthMap(false)
	Renderer.setupCanvasForDirShadowMapping(light, "static", true)

	local light_matrix = light:getStaticLightSpaceMatrix()
	shadersend(shader, "u_lightspace", "column", matrix(light_matrix))
	shader:send("point_light", false)

	local dims_min, dims_max = light:getStaticLightSpaceMatrixGlobalDimensionsMinMax()
	local in_view = self:getModelsInViewFrustrum(dims_min, dims_max)

	--love.graphics.setMeshCullMode("front")
	self:drawStaticModels(in_view)

	--love.graphics.setMeshCullMode("front")
	self:drawGridMapForShadowMapping()
end

local __temp_pos = {}
function Scene:pointStaticShadowPass( shader , light )
	light.props.light_static_depthmap_redraw_flag = false
	light:clearStaticDepthMap(false)

	local mats = light:getPointLightSpaceMatrices()

	local pos = light:getLightPosition()
	local far_plane = light.props.light_cube_lightspace_far_plane

	__temp_pos[1] = pos[1]
	__temp_pos[2] = pos[2]
	__temp_pos[3] = pos[3]
	shader:send("light_pos",__temp_pos)
	shader:send("far_plane", far_plane)
	shader:send("point_light", true)

	for i=1,6 do
		Renderer.setupCanvasForPointShadowMapping(light, i, true)
		shadersend(shader, "u_lightspace", "column", matrix(mats[i]))

		--love.graphics.setMeshCullMode("front")
		--self:drawStaticModels()
		--self:drawModels(false, false)
		self:drawStaticModels()

		--love.graphics.setMeshCullMode("front")
		self:drawGridMapForShadowMapping()
	end
end

function Scene:shadowPass( )

	local shader = Renderer.shadow_shader
	love.graphics.setDepthMode( "less", true )
	love.graphics.setMeshCullMode("front")
	love.graphics.setShader(Renderer.shadow_shader)

	local props = self.props
	-- dynamic shadow mapping
	prof.push("dyn_shadow_map")
	for i,light in ipairs(props.scene_lights) do
		if light:isDirectional() then
			self:dirDynamicShadowPass( shader , light)
		end

	end
	prof.pop("dyn_shadow_map")

	-- static shadow mapping
	prof.push("static_shadow_map")
	for i,light in ipairs(props.scene_lights) do
		local isdir = light:isDirectional()
		local ispoint = light:isPoint()
		if (isdir and light.props.light_static_depthmap_redraw_flag) or
		   (isdir and self.force_redraw_static_shadow)
		then
			self:dirStaticShadowPass( shader , light )
		elseif ispoint and light:isStatic() and light.props.light_static_depthmap_redraw_flag then
			self:pointStaticShadowPass( shader , light )
		else
			--print(ispoint , light:isStatic() , light.props.light_static_depthmap_redraw_flag )
		end
	end
	self.force_redraw_static_shadow = false
	--Renderer.dropCanvas()
	prof.pop("static_shadow_map")
end

-- pushes lights and shadow maps to shader
local point_light_max   = 9
local point_light_pos = {}
for i=1,point_light_max do point_light_pos[i] = {0,0,0,0} end
local point_light_col = {}
local point_light_has_shadow_map = {}
local point_light_shadow_maps = {}
local point_light_far_planes = {}
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
	--
	local point_light_count = 0
	local point_light_shadowmap_count = 0

	--local point_light_pos = {}
	--local point_light_col = {}
	--local point_light_has_shadow_map = {}
	--local point_light_shadow_maps = {}
	--local point_light_far_planes = {}
	--local point_light_shadow_map_index = {}

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
				print("pushShadowMaps(): multiple directional lights, ignoring")
			end
			--shadow_maps[i] = light.props.light_static_depthmap
			--lightspace_mats[i] = matrix(light.props.light_static_lightspace_matrix)
		elseif light_type == "point" then
			point_light_count = point_light_count + 1

			if point_light_count > point_light_max then
				print(string.format("pushShadowMaps(): point light count exceeds maximum limit of %s", point_light_max))
			else
				local col = light:getLightColour()
				local pos = light:getLightPosition()
				local size = light:getLightSize()
				--local pos_to_shader = {pos[1], pos[2], pos[3], size}

				if light:isStatic() then
					point_light_shadowmap_count = point_light_shadowmap_count + 1
	
					local cubemap = light:getCubeMap()
					local farplane = light.props.light_cube_lightspace_far_plane

					--point_light_shadow_map_index[point_light_count] = point_light_shadowmap_count - 1
					--point_light_shadow_maps[point_light_shadowmap_count] = cubemap
					--point_light_far_planes[point_light_shadowmap_count] = farplane
					point_light_shadow_maps[point_light_count] = cubemap
					point_light_far_planes[point_light_count] = farplane
					point_light_has_shadow_map[point_light_count] = true
				else
					local farplane = light.props.light_cube_lightspace_far_plane
					point_light_shadow_map_index[point_light_count] = -1
					point_light_shadow_maps[point_light_count] = Renderer.nil_cubemap
					point_light_far_planes[point_light_count] = farplane
					point_light_has_shadow_map[point_light_count] = false
				end

				point_light_pos[point_light_count][1] = pos[1]
				point_light_pos[point_light_count][2] = pos[2]
				point_light_pos[point_light_count][3] = pos[3]
				point_light_pos[point_light_count][4] = size
				point_light_col[point_light_count] = col
			end
		end
	end

	shadersend(shader, "u_dir_lightspace", "column", matrix(dir_lightspace_mat))
	shadersend(shader, "u_dir_static_lightspace", "column", matrix(dir_static_lightspace_mat))
	shadersend(shader, "dir_static_shadow_map", dir_static_shadow_map)
	shadersend(shader, "dir_shadow_map", dir_shadow_map)
	shadersend(shader, "dir_light_dir", dir_light_dir)
	shadersend(shader, "dir_light_col", dir_light_col)

	shadersend(shader, "u_point_light_count", point_light_count)
	if point_light_count > 0 then
		shadersend(shader, "point_light_pos", unpack(point_light_pos))
		shadersend(shader, "point_light_col", unpack(point_light_col))
		--shadersend(shader, "point_light_shadow_map_index", unpack(point_light_shadow_map_index))
		shadersend(shader, "point_light_has_shadow_map", unpack(point_light_has_shadow_map))
		shadersend(shader, "point_light_shadow_maps", unpack(point_light_shadow_maps))
		shadersend(shader, "point_light_far_planes", unpack(point_light_far_planes))
	end

	self.pushed_static_lights = true
end

-- returns true if skybox drawn
-- otherwise nil
function Scene:drawSkybox(cam)
	local props = self.props
	local skybox_tex_fname = props.scene_skybox
	if skybox_tex_fname == "" then return nil end

	local skybox_img = Textures.loadTexture(props.scene_skybox)
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

--[[function Scene:pushModelAnimationsThreaded()
	for i,model in ipairs(self.dynamic_models) do
		if model:isAnimated() then
			local model_ref = model.props.model_i_reference
			local frame1, frame2, parents, interp = model_ref:getAnimationFramesDataForThread("Walk", getTickSmooth())

			if not frame1 then
				model:defaultPose()
			else
				self.animthreads:addToQueue(model, frame1, frame2, parents, interp)
			end
		end
	end
	self.animthreads:startProcess()
end]]

function Scene:updateModelAnimatedFaces()
	if not refreshRateLimiter() then return end

	for i,model in ipairs(self.dynamic_models) do
		local decors = model.props.model_i_decorations
		for i,decor in ipairs(decors) do
			decor:compositeFace()
		end
	end
end

function Scene:updateModelAnimationsUnthreaded()
	for i,v in ipairs(self.dynamic_models) do
		v:updateAnimation()
		--v:fillOutBoneMatrices()
	end
end

function Scene:finishModelAnimationsThreaded()
	self.animthreads:finishProcess()
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

function Scene:redrawStaticMaps()
	for i,v in ipairs(self.props.scene_lights) do
		v:redrawStaticMap()
	end
end

local __tempmin={1/0,1/0,1/0}
local __tempmax={-1/0,-1/0,-1/0}
function Scene:getModelsInViewFrustrum(min, max)
	prof.push("view_culling")
	local cam = self.props.scene_camera

	local min,max = min,max
	if min == nil or max == nil then

		--min = { 1/0,  1/0,  1/0}
		--max = {-1/0, -1/0, -1/0}
		min = __tempmin
		min[1] = 1/0
		min[2] = 1/0
		min[3] = 1/0
		max = __tempmax
		max[1] = -1/0
		max[2] = -1/0
		max[3] = -1/0

		prof.push("genfrustrum")
		local frustrum_corners = cam:generateFrustrumCornersWorldSpace()
		prof.pop("genfrustrum")

		for i=1,8 do
			local vec = frustrum_corners[i]
			if vec[1] < min[1] then min[1] = vec[1] end
			if vec[2] < min[2] then min[2] = vec[2] end
			if vec[3] < min[3] then min[3] = vec[3] end

			if vec[1] > max[1] then max[1] = vec[1] end
			if vec[2] > max[2] then max[2] = vec[2] end
			if vec[3] > max[3] then max[3] = vec[3] end
		end

	end

	local x,y,w,h = min[1], min[3], max[1]-min[1], max[3]-min[3]

	prof.push("getinsiderectangle")
	local models, outside_models = self.model_bins:getInsideRectangle(x,y,w,h)
	prof.pop("getinsiderectangle")
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

	prof.pop("view_culling")
	return models
end
