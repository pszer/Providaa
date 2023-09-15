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

function Light:allocateDepthMap(size, staticsize)
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
	end
end

-- unused, use other LightSpaceMatrix functions
local __tempmat4 = cpml.mat4.new()
local __tempvec3up = cpml.vec3.new(0,-1,0)
local __tempvec3_1 = cpml.vec3.new()
local __tempvec3_2 = cpml.vec3.new()
function Light:generateLightSpaceMatrix()
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
end

function Light:generatePointLightSpaceMatrix()

end

function Light:generateLightSpaceMatrixFromCamera( cam )
	if not self:isDirectional() then return end
	if not self:checkIfUpdateMatrix() then return end

	if self:getLightType() == "directional" then
		-- use perspective matrix with far plane very close to camera for dynamic shadowmapping
		local proj = cam:calculatePerspectiveMatrix(nil, 350)
		local mat, dim, g_dim = self:calculateLightSpaceMatrixFromFrustrum(
			cam:generateFrustrumCornersWorldSpace(proj))
		self.props.light_lightspace_matrix = mat
		self.props.light_lightspace_matrix_dimensions = dim
		self.props.light_lightspace_matrix_global_dimensions = g_dim
		print(unpack(g_dim))

		-- for static shadowmapping we allocate a larger lightspace matrix
		-- and then render the shadowmap once, only drawing static objects in the scene.
		-- whenever the camera's frustrum goes
		-- outside this lightspace matrix we generate a new one and render the shadowmap again.
		-- this way
		local proj = cam:calculatePerspectiveMatrix(nil, cam.props.cam_far_plane)
		local corners, centre = cam:generateFrustrumCornersWorldSpace(proj)
		
		if self:testNeedForNewStaticLightmapMatrix(corners, self.props.light_static_lightspace_matrix_dimensions) then
			local static_mat, static_map_dim, static_global_dim = self:calculateLightSpaceMatrixFromFrustrum(
				corners, centre, 700)

			self.props.light_static_lightspace_matrix = static_mat
			self.props.light_static_lightspace_matrix_dimensions = static_map_dim
			self.props.light_static_lightspace_matrix_global_dimensions = static_global_dim
			self.props.light_static_depthmap_redraw_flag = true
		end
	end
end

function Light:testNeedForNewStaticLightmapMatrix(corners, dimensions)
	if not self:isDirectional() then return false end
	if self.props.light_static_lightspace_matrix == nil then return true end

	local view_mat = dimensions.view_matrix
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

-- returns matrix, local_dimensions, global_dimensions
function Light:calculateLightSpaceMatrixFromFrustrum( frustrum_corners, frustrum_centre , padding_size )
	if not self:isDirectional() then return nil, nil end

	local padding_size = padding_size or 0
	local props = self.props

	local pos = cpml.vec3(frustrum_centre)
	local dir = cpml.vec3(self.props.light_dir)

	local light_view = cpml.mat4()
	light_view = light_view:look_at(pos,
	                                pos + dir,
									cpml.vec3(0,-1,0))

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

		--print(unpack(corner))
		local trf = {}
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
		["view_matrix"] = light_view
	}
	local global_dimensions = {
		g_min_x, g_max_x, g_min_y, g_max_y, g_min_z, g_max_z }

	--props.light_lightspace_matrix = light_proj * light_view
	return light_proj * light_view, dimensions, global_dimensions
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
end

function Light:getLightDirection()
	return self.props.light_dir end
function Light:getLightColour()
	return self.props.light_col end
