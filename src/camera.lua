local cpml = require 'cpml'
local matrix = require 'matrix'

require "resolution"

require "props/cameraprops"

Camera = {__type = "camera"}
Camera.__index = Camera

function Camera:new(props)
	local this = {
		props = CameraPropPrototype(props),

		__viewport_w_half=0,
		__viewport_h_half=0
	}

	setmetatable(this,Camera)
	this:createCanvas()

	return this
end

function Camera:createCanvas()
	local w,h = get_resolution()
	local props = self.props

	if props.cam_viewport then props.cam_viewport:release() end
	props.cam_viewport    = love.graphics.newCanvas (w,h, {format = "rgba8"})
	props.cam_depthbuffer = love.graphics.newCanvas (w,h, {format = "depth24"})
	props.cam_viewport_w = w
	props.cam_viewport_h = h
	self.__viewport_w_half = w/2
	self.__viewport_h_half = h/2

	self:generatePerspectiveMatrix()
	self:generateViewMatrix()
end

function Camera:transformCoords()
	local w,h = self.props.cam_viewport_w, self.props.cam_viewport_h
	love.graphics.origin()
	love.graphics.translate(w/2,h/2)
end

function Camera:transformCoords2()
	local w,h = self.props.cam_viewport_w, self.props.cam_viewport_h
	love.graphics.origin()
	love.graphics.scale(w/2,h/2)
	love.graphics.translate(1,1)
end

function Camera:setupCanvas()
	local props = self.props

	love.graphics.setCanvas{props.cam_viewport, depthstencil = props.cam_depthbuffer, depth=true}
	love.graphics.setDepthMode( "less", true  )
	love.graphics.setMeshCullMode("front")

	love.graphics.setShader(Renderer.vertex_shader)
	Renderer.vertex_shader:send("u_proj", "column", matrix(props.cam_perspective_matrix))
	Renderer.vertex_shader:send("u_view", "column", matrix(props.cam_view_matrix))
	Renderer.vertex_shader:send("u_rot", "column", matrix(props.cam_rot_matrix))

	Renderer.vertex_shader:send("curve_flag", props.cam_bend_enabled)
	Renderer.vertex_shader:send("curve_coeff", props.cam_bend_coefficient)

	love.graphics.origin()
	self:transformCoords2()
end

function Camera:dropCanvas()
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.setDepthMode()
	love.graphics.setMeshCullMode("none")
	love.graphics.origin()
end

-- generates and returns perspective matrix
function Camera:generatePerspectiveMatrix()
	local props = self.props
	props.cam_perspective_matrix = cpml.mat4.from_perspective(
		props.cam_fov, props.cam_viewport_w / props.cam_viewport_h, 0.1, 10000)
	return props.cam_perspective_matrix
end

-- generates and returns view,rot matrix
function Camera:generateViewMatrix()
	local props = self.props
	local v = cpml.mat4():identity()
	local m = cpml.mat4()

	local position = cpml.vec3(props.cam_x, props.cam_y, props.cam_z)

	v:rotate(v, props.cam_pitch, cpml.vec3.unit_x)
	v:rotate(v, props.cam_yaw, cpml.vec3.unit_y)
	v:rotate(v, props.cam_roll, cpml.vec3.unit_z)

	m:translate(m, -position)

	props.cam_view_matrix = m
	props.cam_rot_matrix  = v
	return props.cam_view_matrix, props.cam_rot_matrix
end

function Camera:getDirectionVector()
	local unit = {0,0,0,0}
	local rot = self.props.cam_rot_matrix
	if rot then
		unit = cpml.mat4.mul_vec4(unit, rot, {0,0,-1,0})
		return unit[1], unit[2], unit[3]
	else
		return 0,0,-1
	end
end

function Camera:getViewportCoords()
	return self.__viewport_w_half, self.__viewport_h_half
end

function Camera:map3DCoords(x,y)
	if RESOLUTION_ASPECT == "16:9" then
		return x*self.__viewport_w_half,
		       y*self.__viewport_h_half
	else
		return x*self.__viewport_w_half * 0.875,
		       y*self.__viewport_h_half
	end
end
