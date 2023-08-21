local cpml = require 'cpml'
local matrix = require 'matrix'

require "resolution"

require "props/cameraprops"

Camera = {__type = "camera"}
Camera.__index = Camera

function Camera:new(props)
	local this = {
		props = CameraPropPrototype(props),

		__last_aspect = 16/9
	}

	setmetatable(this,Camera)

	this:generatePerspectiveMatrix()
	this:generateViewMatrix()

	return this
end

function Camera:pushToShader(sh)
	local props = self.props

	sh = sh or love.graphics.getShader()
	sh:send("u_proj", "column", matrix(props.cam_perspective_matrix))
	if sh:hasUniform( "u_view" ) then sh:send("u_view", "column", matrix(props.cam_view_matrix)) end
	sh:send("u_rot", "column", matrix(props.cam_rot_matrix))

 	if sh:hasUniform( "curve_flag" ) then sh:send("curve_flag", props.cam_bend_enabled) end
	if sh:hasUniform( "curve_coeff" ) then sh:send("curve_coeff", props.cam_bend_coefficient) end
end

function Camera:getPosition()
	local props = self.props
	return props.cam_x,props.cam_y,props.cam_z
end

-- generates and returns perspective matrix
function Camera:generatePerspectiveMatrix(aspect_ratio)
	aspect_ratio = aspect_ratio or RESOLUTION_ASPECT_RATIO
	self.__last_aspect = aspect_ratio

	local props = self.props
	props.cam_perspective_matrix = cpml.mat4.from_perspective(
		props.cam_fov, aspect_ratio, 0.1, 10000)
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

	local rotview = cpml.mat4()
	cpml.mat4.mul(rotview, v, m)
	props.cam_rotview_matrix = rotview

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

function Camera:update()
	if RESOLUTION_ASPECT_RATIO ~= self.__last_aspect then
		self:generatePerspectiveMatrix()
	end
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
