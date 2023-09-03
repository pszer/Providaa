require "props.lightprops"

require "math"
local cpml = require 'cpml'

-- THIS IS HUGE, DO SOMETHING ABOUT IT >:-[[[[[[[[[[[[[[[[[
local SHADOWMAP_SIZE = 8192

Light = {__type = "light",
		 z_mult = 1.0 -- used to increase size of orthographic lightmap projection matrix when shadowmapping

}
Light.__index = Light

function Light:new(props)
	local this = {
		props = LightPropPrototype(props),
		testcanvas
	}

	setmetatable(this,Light)

	this:allocateDepthMap()
	--this:generateLightSpaceMatrix()

	return this
end

function Light:allocateDepthMap()
	self.props.light_depthmap = love.graphics.newCanvas (SHADOWMAP_SIZE,SHADOWMAP_SIZE,{format = "depth16", readable=true})
	--self.props.light_depthmap = love.graphics.newCanvas (SHADOWMAP_SIZE,SHADOWMAP_SIZE,3,{type="array", format = "depth16", readable=true})
	self.props.light_depthmap:setDepthSampleMode("greater")
	--self.testcanvas = love.graphics.newCanvas(SHADOWMAP_SIZE,SHADOWMAP_SIZE)
end

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
	local mat = 
	self:calculateLightSpaceMatrixFromFrustrum(
		cam:getFrustrumCornersWorldSpace())
	self.props.light_lightspace_matrix = mat
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


	--print(min_x, max_x, max_y, min_y, min_z, max_z)
	local light_proj = cpml.mat4.from_ortho(min_x, max_x, max_y, min_y, min_z, max_z)
	--print(light_proj)
	props.light_lightspace_matrix = light_proj * light_view
	return light_proj * light_view
end

function Light:getDepthMap()
	return self.props.light_depthmap end
function Light:getLightSpaceMatrix()
	return self.props.light_lightspace_matrix end

function Light:clearDepthMap()
	--love.graphics.setCanvas{self.testcanvas, depthstencil=self.props.light_depthmap}
	love.graphics.setCanvas{nil, depthstencil=self.props.light_depthmap}
	love.graphics.clear(0,0,0,0)
	love.graphics.setCanvas()
end
