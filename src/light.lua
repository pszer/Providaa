require "props.lightprops"

local cpml = require 'cpml'

local SHADOWMAP_SIZE = 8192

Light = {__type = "light"}
Light.__index = Light

function Light:new(props)
	local this = {
		props = LightPropPrototype(props),
		testcanvas
	}

	setmetatable(this,Light)

	this:allocateDepthMap()
	this:generateLightSpaceMatrix()

	return this
end

function Light:allocateDepthMap()
	self.props.light_depthmap = love.graphics.newCanvas (SHADOWMAP_SIZE,SHADOWMAP_SIZE,{format = "depth24", readable=true})
	self.testcanvas = love.graphics.newCanvas(SHADOWMAP_SIZE,SHADOWMAP_SIZE)
end

function Light:generateLightSpaceMatrix()
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
	--local up_v = cpml.vec3.cross(dir_v, cpml.vec3.cross(cpml.vec3(0,-1,0),dir_v))
	--light_view:translate(light_view, -pos_v)
	--light_dir:rotate(light_dir, dir[1], cpml.vec3.unit_x)
	--light_dir:rotate(light_dir, dir[2], cpml.vec3.unit_y)
	--light_dir:rotate(light_dir, dir[3], cpml.vec3.unit_z)

	light_view = light_view:look_at(pos_v,
	                                pos_v + dir_v,
									cpml.vec3(0,-1,0))

	--self.props.light_lightspace_matrix = light_proj * (light_dir * light_view)
	self.props.light_lightspace_matrix = light_proj * light_view
--	self.props.light_proj_matrix = light_proj
--	self.props.light_view_matrix = light_view
--	self.props.light_rot_matrix  = light_dir
	return self.props.light_lightspace_matrix
end

function Light:getDepthMap()
	return self.props.light_depthmap end
function Light:getLightSpaceMatrix()
	return self.props.light_lightspace_matrix end

function Light:clearDepthMap()
	love.graphics.setCanvas{self.testcanvas, depthstencil=self.props.light_depthmap}
	love.graphics.clear(0,0,0,0)
	love.graphics.setCanvas()
end

-- returns normalized vector with lights direction
function Light:getDirectionVector()
	
end
