require "props.lightprops"
require "cfg.gfx"
require "tick"

require "math"
local cpml = require 'cpml'
local limit = require 'syslimits'

-- number of ticks between each shadow re-draw
SHADOW_UPDATE_FREQ = 0.0

Light = {__type = "light",
		 z_mult = 1.0, -- used to increase size of orthographic lightmap projection matrix when shadowmapping
		checkIfUpdateMatrix = periodicUpdate(10)
}
Light.__index = Light

function Light:new(props)
	local this = {
		props = LightPropPrototype(props),

		recalc_point_matrices = true,
		static_lightspace_generated = false,

		dyn_lightspace_view_mat = nil,
		static_lightspace_view_mat = nil,
	}

	setmetatable(this,Light)

	this:allocateDepthMap()
	--this:generateLightSpaceMatrix()
	--
	if this.props.light_pos[4] == 0 and not this.props.light_static then
		error("dynamic directional lights are not supported")
	elseif this.props.light_pos[4] ~= 0.0 and this.props.light_pos[4] ~= 1.0 then
		error("Light:new(): light_pos w component is "..tostring(this.props.light_pos[4])..", neither 0 or 1, ill defined light")
	end

	this.props.light_lightspace_matrix = cpml.mat4.new()
	this.props.light_lightspace_matrix_dimensions = {}
	this.props.light_lightspace_matrix_global_dimensions = {}

	this.props.light_static_lightspace_matrix = cpml.mat4.new()
	this.props.light_static_lightspace_matrix_dimensions = {}
	this.props.light_static_lightspace_matrix_global_dimensions = {}
	
	this.dyn_lightspace_view_mat = cpml.mat4.new()
	this.static_lightspace_view_mat = cpml.mat4.new()

	return this
end

-- returns either "directional" or "point"
function Light:getLightType()
	local w = self.props.light_pos[4]
	if w == 0 then return "directional"
	elseif w == 1 then return "point"
	else return nil end
end
function Light:isDirectional()
	return self.props.light_pos[4] == 0 end
function Light:isPoint()
	return self.props.light_pos[4] == 1 end
function Light:isStatic()
	return self.props.light_static end

function Light:allocateDepthMap(size, staticsize)
	if not self:isStatic() then return end

	local size = size or gfxSetting("shadow_map_size")
	local w,h = limit.clampTextureSize(size)

	if self:isDirectional() then
		self.props.light_depthmap = love.graphics.newCanvas (w,h,{format = "depth16", readable=true})
		self.props.light_depthmap:setDepthSampleMode("greater")

		local staticsize = staticsize or gfxSetting("static_shadow_map_size")
		local w2, h2 = limit.clampTextureSize(staticsize)
		self.props.light_static_depthmap = love.graphics.newCanvas(w2,h2,{format = "depth16", readable=true})
		self.props.light_static_depthmap:setDepthSampleMode("greater")
	elseif self:isPoint() then
		self.props.light_cubemap = love.graphics.newCanvas (w,h,{format = "depth16", type="cube", readable=true})
		--self.props.light_cubemap:setDepthSampleMode("greater")
	end
end

-- deprecated, use other LightSpaceMatrix functions
--local __tempmat4 = cpml.mat4.new()
--local __tempvec3up = cpml.vec3.new(0,-1,0)
--local __tempvec3_1 = cpml.vec3.new()
--local __tempvec3_2 = cpml.vec3.new()
--[[function Light:generateLightSpaceMatrix()
	if not self:isStatic() or not self:isDirectional() then return end

	local props = self.props
	if props.light_static and self.props.light_lightspace_matrix then
		return props.light_lightspace_matrix
	end

	local pos = self.props.light_pos
	local dir = self.props.light_dir

	local light_proj = nil
	if pos[4] == 0 then -- if directional light
		light_proj = cpml.mat4.from_ortho(-1500,1500,1500,-1500,1.0,3000)
	else -- if point light
		light_proj = nil -- implement for point light
	end

	--local light_view = cpml.mat4()
	local light_view = __tempmat4

	--local pos_v = cpml.vec3(pos)
	--local dir_v = cpml.vec3(dir)
	local pos_v = __tempvec3_1
	local pos_plus_dir_v = __tempvec3_2

	pos_v.x = pos[1]
	pos_v.y = pos[2]
	pos_v.z = pos[3]

	pos_plus_dir_v.x = pos[1] + dir[1]
	pos_plus_dir_v.y = pos[2] + dir[2]
	pos_plus_dir_v.z = pos[3] + dir[3]


	light_view = light_view:look_at(pos_v,
	                                pos_v + dir_v,
									__tempvec3up)

	--props.light_lightspace_matrix = light_proj * light_view
	props.light_lightspace_matrix:mul(light_proj , light_view)
	return props.light_lightspace_matrix
end--]]

function Light:generateMatrices(cam)
	if not self:isStatic() then
		return
	end

	if self:isDirectional() then
		self:generateLightSpaceMatrixFromCamera(cam)
	elseif self:isPoint() then
		self:generatePointLightSpaceMatrix()
	end
end

local __tempvec3 = cpml.vec3.new(0,0,0)
local __tempvec3_2 = cpml.vec3.new(0,0,0)
local __tempvec3_up = cpml.vec3.new(0,-1,0)
local __tempvec3_up2 = cpml.vec3.new(0,0,-1)
--TEMP_PROJ = {}
--TEMP_VIEW = {}
function Light:generatePointLightSpaceMatrix()
	if not self:isStatic() or not self:isPoint() then return end
	if not self.recalc_point_matrices then return end

	local size = self.props.light_size

	local far_plane = size*1
	local proj_mat4 = cpml.mat4.from_perspective(90.0, 1.0, 1.0, far_plane)
	self.props.light_cube_lightspace_far_plane = far_plane

	local sides = {}
	local dirs = {
		{ 1.0 , 0.0 , 0.0 },
		{-1.0 , 0.0 , 0.0 },
		{ 0.0 , 1.0 , 0.0 },
		{ 0.0 ,-1.0 , 0.0 },
		{ 0.0 , 0.0 , 1.0 },
		{ 0.0 , 0.0 ,-1.0 }}
	local pos = self.props.light_pos
	__tempvec3.x = pos[1]
	__tempvec3.y = pos[2]
	__tempvec3.z = pos[3]

	for i=1,6 do
		local mat = cpml.mat4.new()

		__tempvec3_2.x = pos[1] + dirs[i][1]
		__tempvec3_2.y = pos[2] + dirs[i][2]
		__tempvec3_2.z = pos[3] + dirs[i][3]
		if i~=3 and i~=4 then
			mat = mat:look_at(__tempvec3, __tempvec3_2, __tempvec3_up)
		else
			mat = mat:look_at(__tempvec3, __tempvec3_2, __tempvec3_up2)
		end

		--TEMP_VIEW[i] = cpml.mat4.new()
		--TEMP_PROJ[i] = cpml.mat4.new()
		--for j=1,16 do TEMP_VIEW[i][j] = mat[j] end
		--for j=1,16 do TEMP_PROJ[i][j] = proj_mat4[j] end

		mat = mat:mul(proj_mat4, mat)
		sides[i] = mat
	end

	self.props.light_cube_lightspace_matrices = sides
	self.recalc_point_matrices = false
end

function Light:generateLightSpaceMatrixFromCamera( cam )
	if not self:isDirectional() then return end
	if not self:checkIfUpdateMatrix() then return end

	local function iclone(to, from) for i,v in ipairs(from) do to[i]=v end end

	if self:isDirectional() then
		-- use perspective matrix with far plane very close to camera for dynamic shadowmapping
		local proj = cam:calculatePerspectiveMatrix(nil, 350)
		local mat, dim, g_dim, view = self:calculateLightSpaceMatrixFromFrustrum(
			cam:generateFrustrumCornersWorldSpace(proj))
		--self.props.light_lightspace_matrix = mat
		--self.props.light_lightspace_matrix_dimensions = dim
		--self.props.light_lightspace_matrix_global_dimensions = g_dim
		iclone(self.props.light_lightspace_matrix, mat)
		iclone(self.props.light_lightspace_matrix_dimensions, dim)
		iclone(self.props.light_lightspace_matrix_global_dimensions, g_dim)
		iclone(self.dyn_lightspace_view_mat, view)

		-- for static shadowmapping we allocate a larger lightspace matrix
		-- and then render the shadowmap once, only drawing static objects in the scene.
		-- whenever the camera's frustrum goes
		-- outside this lightspace matrix we generate a new one and render the shadowmap again.
		-- this way
		local proj = cam:calculatePerspectiveMatrix(nil, cam.props.cam_far_plane * 0.66)
		local corners, centre = cam:generateFrustrumCornersWorldSpace(proj)
		
		if self:testNeedForNewStaticLightmapMatrix(corners, self.props.light_static_lightspace_matrix_dimensions) then
			local static_mat, static_map_dim, static_global_dim, static_view = self:calculateLightSpaceMatrixFromFrustrum(
				corners, centre, 700)

			--self.props.light_static_lightspace_matrix = static_mat
			iclone(self.props.light_static_lightspace_matrix, static_mat)
			iclone(self.props.light_static_lightspace_matrix_dimensions, static_map_dim)
			iclone(self.props.light_static_lightspace_matrix_global_dimensions, static_global_dim)
			iclone(self.static_lightspace_view_mat, static_view)
			--self.props.light_static_lightspace_matrix_dimensions = static_map_dim
			--self.props.light_static_lightspace_matrix_global_dimensions = static_global_dim
			self.props.light_static_depthmap_redraw_flag = true
		end
	elseif self:isPoint() then
		if not self:isStatic() then return end
	end
end

function Light:testNeedForNewStaticLightmapMatrix(corners, dimensions)
	if not self:isDirectional() then return false end
	if not self.static_lightspace_generated then return true end
	self.static_lightspace_generated = true

	--local view_mat = dimensions.view_matrix
	local view_mat = self.static_lightspace_view_mat
	local min_x,max_x = dimensions[1], dimensions[2]
	local min_y,max_y = dimensions[3], dimensions[4]
	local min_z,max_z = dimensions[5], dimensions[6]

	for i,v in ipairs(corners) do
		local xyzw = {v[1],v[2],v[3],1.0}
		--print(unpack(xyzw))
		--print(view_mat)
		local trf  = {}
		trf = cpml.mat4.mul_vec4(trf, view_mat, xyzw)
		local x,y,z = trf[1],trf[2],trf[3]
		--print("["..tostring(i).."]",x,y,z, min_x,max_x,min_y,max_y,min_z,max_z)
		local inside =
		 min_x < x and max_x > x and
		 min_y < y and max_y > y and
		 min_z < z and max_z > z 
		 if not inside then return true end
	end

	return false
end

-- returns matrix, local_dimensions, global_dimensions, view_mat
local __temp_trf = {}
local __temp_mat4 = cpml.mat4.new()
local __temp_pos = cpml.vec3.new()
local __temp_dir = cpml.vec3.new()
local __temp_upvec = cpml.vec3(0,-1,0)
function Light:calculateLightSpaceMatrixFromFrustrum( frustrum_corners, frustrum_centre , padding_size )
	if not self:isDirectional() then return nil, nil end

	local padding_size = padding_size or 0
	local props = self.props

	--local pos = cpml.vec3(frustrum_centre)
	local pos = __temp_pos
	pos.x = frustrum_centre[1]
	pos.y = frustrum_centre[2]
	pos.z = frustrum_centre[3]
	local dir = cpml.vec3(self.props.light_dir)
	--local dir = __temp_dir
	local light_dir = self.props.light_dir
	dir.x = light_dir[1] + pos.x
	dir.y = light_dir[2] + pos.y
	dir.z = light_dir[3] + pos.z

	local light_view = __temp_mat4
	--local light_view = cpml.mat4.new()
	light_view = light_view:look_at(pos,
	                                dir,
									__temp_upvec)

	--print(light_view)

	local min_x =  1/0
	local max_x = -1/0
	local min_y =  1/0
	local max_y = -1/0
	local min_z =  1/0
	local max_z = -1/0

	local g_min_x =  1/0
	local g_max_x = -1/0
	local g_min_y =  1/0
	local g_max_y = -1/0
	local g_min_z =  1/0
	local g_max_z = -1/0

	for i=1,8 do
		local corner = frustrum_corners[i]

		g_min_x = math.min(g_min_x , corner[1] - padding_size )
		g_max_x = math.max(g_max_x , corner[1] + padding_size )
		g_min_y = math.min(g_min_y , corner[2] - padding_size )
		g_max_y = math.max(g_max_y , corner[2] + padding_size )
		g_min_z = math.min(g_min_z , corner[3] - padding_size )
		g_max_z = math.max(g_max_z , corner[3] + padding_size )

		local trf = __temp_trf
		trf = cpml.mat4.mul_vec4(trf, light_view, corner)

		min_x = math.min(min_x , trf[1] - padding_size )
		max_x = math.max(max_x , trf[1] + padding_size )
		min_y = math.min(min_y , trf[2] - padding_size )
		max_y = math.max(max_y , trf[2] + padding_size )
		min_z = math.min(min_z , trf[3] - padding_size )
		max_z = math.max(max_z , trf[3] + padding_size )
	end


	--print(min_x, max_x, max_y, min_y, min_z, max_z)

	local z_mult = Light.z_mult
	if min_z < 0 then
		min_z = min_z * z_mult
	else
		min_z = min_z / z_mult
	end

	if max_z < 0 then
		min_z = min_z / z_mult
	else
		min_z = min_z * z_mult
	end


	local light_proj = cpml.mat4.from_ortho(min_x, max_x, max_y, min_y, min_z, max_z)
	local dimensions = {
		min_x ,
		max_x ,
		min_y ,
		max_y ,
		min_z ,
		max_z ,
		--["view_matrix"] = light_view
	}
	local global_dimensions = {
		g_min_x, g_max_x, g_min_y, g_max_y, g_min_z, g_max_z }

	--props.light_lightspace_matrix = light_proj * light_view
	return light_proj * light_view, dimensions, global_dimensions, light_view
end

function Light:getDepthMap()
	return self.props.light_depthmap end
function Light:getStaticDepthMap()
	return self.props.light_static_depthmap end
function Light:getCubeMap()
	return self.props.light_cubemap end

function Light:getLightSpaceMatrix()
	return self.props.light_lightspace_matrix end
function Light:getStaticLightSpaceMatrix()
	return self.props.light_static_lightspace_matrix end
function Light:getPointLightSpaceMatrices()
	return self.props.light_cube_lightspace_matrices end

function Light:getLightSpaceMatrixDimensionsMinMax()
	local dim = self.props.light_lightspace_matrix_dimensions
	local min = {dim[1],dim[3],dim[5]}
	local max = {dim[2],dim[4],dim[6]}
	return min , max
end

function Light:getLightSpaceMatrixGlobalDimensionsMinMax()
	local dim = self.props.light_lightspace_matrix_global_dimensions
	local min = {dim[1],dim[3],dim[5]}
	local max = {dim[2],dim[4],dim[6]}
	return min , max
end

function Light:getStaticLightSpaceMatrixDimensionsMinMax()
	local dim = self.props.light_static_lightspace_matrix_dimensions
	local min = {dim[1],dim[3],dim[5]}
	local max = {dim[2],dim[4],dim[6]}
	return min , max
end

function Light:getStaticLightSpaceMatrixGlobalDimensionsMinMax()
	local dim = self.props.light_static_lightspace_matrix_global_dimensions
	local min = {dim[1],dim[3],dim[5]}
	local max = {dim[2],dim[4],dim[6]}
	return min , max
end

function Light:clearDepthMap(opt)
	if self.props.light_depthmap then
		love.graphics.setCanvas{nil, depthstencil=self.props.light_depthmap}
		love.graphics.clear(0,0,0,0)
	end
	if self.props.light_cubemap then
		love.graphics.setCanvas{nil, depthstencil=self.props.light_depthmap}
		love.graphics.clear(0,0,0,0)
	end
	if not opt then love.graphics.setCanvas() end
end
function Light:clearStaticDepthMap(opt)
	if self.props.light_static_depthmap then
		love.graphics.setCanvas{nil, depthstencil=self.props.light_static_depthmap}
		love.graphics.clear(0,0,0,0)
		if not opt then love.graphics.setCanvas() end
	end

	if self.props.light_cubemap then
		love.graphics.setCanvas{nil, depthstencil=self.props.light_cubemap}
		love.graphics.clear(0,0,0,0)
		if not opt then love.graphics.setCanvas() end
	end
end

function Light:setColor(r,g,b)
	local col = self.props.light_col
	local max = math.max
	if type(r) ~= "table" then
		col[1] = max(r,0)
		col[2] = max(g,0)
		col[3] = max(b,0)
	elseif type(r) == "table" then
		col[1] = max(r[1],0)
		col[2] = max(r[2],0)
		col[3] = max(r[3],0)
	end
end

function Light:setBrightness( val )
	local col = self.props.light_col
	local max = math.max
	col[4] = max(val, 0)
end

-- sets flag to redraw static maps for this light next frame
function Light:redrawStaticMap()
	self.props.light_static_depthmap_redraw_flag = true
end

function Light:getLightDirection()
	return self.props.light_dir end
function Light:getLightColour()
	return self.props.light_col end
function Light:getLightPosition()
	return self.props.light_pos end
function Light:getLightSize()
	return self.props.light_size end
function Light:getLightColour()
	return self.props.light_col end
