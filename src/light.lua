require "props.lightprops"

require "math"
local cpml = require 'cpml'
local limit = require 'syslimits'

-- THIS IS HUGE, DO SOMETHING ABOUT IT >:-[[[[[[[[[[[[[[[[[
local SHADOWMAP_SIZE = 2048*2
local STATIC_SHADOWMAP_SIZE = 1024

-- number of ticks between each shadow re-draw
SHADOW_UPDATE_FREQ = 0.0

Light = {__type = "light",
		 z_mult = 1.0 -- used to increase size of orthographic lightmap projection matrix when shadowmapping

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

	return this
end

-- returns either "directional" or "point"
function Light:getLightType()
	local w = self.props.light_pos[4]
	if w == 0 then return "directional"
	elseif w == 1 then return "point"
	else return nil end
end

function Light:allocateDepthMap(size)
	local size = size or SHADOWMAP_SIZE
	local w,h = limit.clampTextureSize(size)
	self.props.light_depthmap = love.graphics.newCanvas (w,h,{format = "depth16", readable=true})
	self.props.light_depthmap:setDepthSampleMode("greater")

	if self:getLightType() == "directional" then
		local w2, h2 = limit.clampTextureSize(STATIC_SHADOWMAP_SIZE)
		self.props.light_static_depthmap = love.graphics.newCanvas(w2,h2,{format = "depth16", readable=true})
	end
end

-- unused, use other LightSpaceMatrix functions
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

	local light_view = cpml.mat4()

	local pos_v = cpml.vec3(pos)
	local dir_v = cpml.vec3(dir)

	light_view = light_view:look_at(pos_v,
	                                pos_v + dir_v,
									cpml.vec3(0,-1,0))

	props.light_lightspace_matrix = light_proj * light_view
	return props.light_lightspace_matrix
end

function Light:generateLightSpaceMatrixFromCamera( cam )
	-- use perspective matrix with far plane very close to camera for dynamic shadowmapping
	local proj = cam:calculatePerspectiveMatrix(nil, 360)
	local mat = self:calculateLightSpaceMatrixFromFrustrum(
		cam:generateFrustrumCornersWorldSpace(proj))
	self.props.light_lightspace_matrix = mat

	-- for static shadowmapping we allocate a lightspace matrix larger than the camera's
	-- frustrum and then render the shadowmap once, only drawing static objects in the scene.
	-- whenever the camera's frustrum goes
	-- outside this lightspace matrix we generate a new one and render the shadowmap again.
	-- this way
	local static_mat, static_map_dim = self:calculateLightSpaceMatrixFromFrustrum(
		cam:generateFrustrumCornersWorldSpace(nil, nil, 1.5)
	)
	self.props.light_static_lightspace_matrix = static_mat
	self.props.light_static_lightspace_matrix_dimensions = static_map_dim
end

function Light:calculateLightSpaceMatrixFromFrustrum( frustrum_corners, frustrum_centre )
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

	for i=1,8 do
		local corner = frustrum_corners[i]
		--print(unpack(corner))
		local trf = {}
		trf = cpml.mat4.mul_vec4(trf, light_view, corner)

		min_x = math.min(min_x , trf[1])
		max_x = math.max(max_x , trf[1])
		min_y = math.min(min_y , trf[2])
		max_y = math.max(max_y , trf[2])
		min_z = math.min(min_z , trf[3])
		max_z = math.max(max_z , trf[3])
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
		min_x + pos.x,
		max_x + pos.x,
		min_y + pos.y,
		max_y + pos.y,
		min_z + pos.z,
		max_z + pos.z,
	}

	--props.light_lightspace_matrix = light_proj * light_view
	return light_proj * light_view
end

function Light:getDepthMap()
	return self.props.light_depthmap end
function Light:getStaticDepthMap()
	return self.props.light_static_depthmap end
function Light:getLightSpaceMatrix()
	return self.props.light_lightspace_matrix end

function Light:clearDepthMap()
	--love.graphics.setCanvas{self.testcanvas, depthstencil=self.props.light_depthmap}
	love.graphics.setCanvas{nil, depthstencil=self.props.light_depthmap}
	love.graphics.clear(0,0,0,0)
	love.graphics.setCanvas()
end
