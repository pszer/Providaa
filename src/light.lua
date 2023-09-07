require "props.lightprops"
require "cfg.gfx"

require "math"
local cpml = require 'cpml'
local limit = require 'syslimits'

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

function Light:allocateDepthMap(size, staticsize)
	local size = size or gfxSetting("shadow_map_size")
	local w,h = limit.clampTextureSize(size)
	self.props.light_depthmap = love.graphics.newCanvas (w,h,{format = "depth16", readable=true})
	self.props.light_depthmap:setDepthSampleMode("greater")

	if self:getLightType() == "directional" then
		local staticsize = staticsize or gfxSetting("static_shadow_map_size")
		local w2, h2 = limit.clampTextureSize(staticsize)
		self.props.light_static_depthmap = love.graphics.newCanvas(w2,h2,{format = "depth16", readable=true})
		self.props.light_static_depthmap:setDepthSampleMode("greater")
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
	if self:getLightType() == "directional" then
		-- use perspective matrix with far plane very close to camera for dynamic shadowmapping
		local proj = cam:calculatePerspectiveMatrix(nil, 360)
		local mat = self:calculateLightSpaceMatrixFromFrustrum(
			cam:generateFrustrumCornersWorldSpace(proj))
		self.props.light_lightspace_matrix = mat

		-- for static shadowmapping we allocate a larger lightspace matrix
		-- and then render the shadowmap once, only drawing static objects in the scene.
		-- whenever the camera's frustrum goes
		-- outside this lightspace matrix we generate a new one and render the shadowmap again.
		-- this way
		local proj = cam:calculatePerspectiveMatrix(nil, cam.props.cam_far_plane)
		local corners, centre = cam:generateFrustrumCornersWorldSpace(proj)
		
		if self:testNeedForNewStaticLightmapMatrix(corners, self.props.light_static_lightspace_matrix_dimensions) then
			local static_mat, static_map_dim = self:calculateLightSpaceMatrixFromFrustrum(
				corners, centre, 700)

			self.props.light_static_lightspace_matrix = static_mat
			self.props.light_static_lightspace_matrix_dimensions = static_map_dim
			self.props.light_static_depthmap_redraw_flag = true
		end
	end
end

function Light:testNeedForNewStaticLightmapMatrix(corners, dimensions)
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

function Light:calculateLightSpaceMatrixFromFrustrum( frustrum_corners, frustrum_centre , padding_size )
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

	for i=1,8 do
		local corner = frustrum_corners[i]
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

	--props.light_lightspace_matrix = light_proj * light_view
	return light_proj * light_view, dimensions
end

function Light:getDepthMap()
	return self.props.light_depthmap end
function Light:getStaticDepthMap()
	return self.props.light_static_depthmap end

function Light:getLightSpaceMatrix()
	return self.props.light_lightspace_matrix end
function Light:getStaticLightSpaceMatrix()
	return self.props.light_static_lightspace_matrix end

function Light:clearDepthMap()
	love.graphics.setCanvas{nil, depthstencil=self.props.light_depthmap}
	love.graphics.clear(0,0,0,0)
	love.graphics.setCanvas()
end

function Light:getLightDirection()
	return self.props.light_dir end
function Light:getLightColour()
	return self.props.light_col end

function Light:clearStaticDepthMap()
	if self.props.light_static_depthmap then
		love.graphics.setCanvas{nil, depthstencil=self.props.light_static_depthmap}
		love.graphics.clear(0,0,0,0)
		love.graphics.setCanvas()
	end
end
