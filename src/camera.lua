local cpml = require 'cpml'
local matrix = require 'matrix'

require "resolution"
local shadersend = require 'shadersend'

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
	shadersend(sh, "u_proj", "column", matrix(props.cam_perspective_matrix))
	shadersend(sh, "u_view", "column", matrix(props.cam_view_matrix))
	shadersend(sh, "u_rot", "column", matrix(props.cam_rot_matrix))

 	shadersend(sh, "curve_flag", props.cam_bend_enabled)
	shadersend(sh, "curve_coeff", props.cam_bend_coefficient)
end

function Camera:getPosition()
	local props = self.props
	return props.cam_x,props.cam_y,props.cam_z
end

-- generates and returns perspective matrix
function Camera:generatePerspectiveMatrix(aspect_ratio)
	local aspect_ratio = aspect_ratio or RESOLUTION_ASPECT_RATIO
	self.__last_aspect = aspect_ratio

	local props = self.props
	props.cam_perspective_matrix = cpml.mat4.from_perspective(
		props.cam_fov, aspect_ratio, 0.5, 2500)

	--props.cam_perspective_matrix = cpml.mat4.from_ortho(
	--	-1000*aspect_ratio, 1000*aspect_ratio, 1000, -1000, 1.0, 1000)

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

-- returns corners of camera`s view frustrum in world space,
-- also returns the vector in the middle of this frustrum
function Camera:generateFrustrumCornersWorldSpace(proj, view)
	local props = self.props
	local proj = proj or props.cam_perspective_matrix
	local view = view or props.cam_rot_matrix * props.cam_view_matrix

	local inv_m = cpml.mat4.new()
	inv_m:invert(proj * view)

	local corners = {}

	-- used to find vector in the centre
	local sum_x, sum_y, sum_z = 0.0, 0.0, 0.0

	local X = {-1,1}
	local Y = {-1,1}
	local Z = {-1,1}

	for x=1,2 do
		for y=1,2 do
			for z=1,2 do
				--[[local point = {
					2.0 * x - 1.0,
					2.0 * y - 1.0,
					2.0 * z - 1.0,
					1.0 }]]
				local point = {
					X[x],Y[y],Z[z],1.0
				}
				cpml.mat4.mul_vec4(point, inv_m, point)

				-- perform perspective division by w component
				point[1] = point[1]/point[4]
				point[2] = point[2]/point[4]
				point[3] = point[3]/point[4]
				--point[4] = point[4]/point[4]
				point[4] = 1.0

				sum_x = sum_x + point[1]
				sum_y = sum_y + point[2]
				sum_z = sum_z + point[3]

				table.insert(corners, point)
			end
		end
	end

	sum_x = sum_x / 8.0
	sum_y = sum_y / 8.0
	sum_z = sum_z / 8.0
	local centre = {sum_x, sum_y, sum_z}

	props.cam_frustrum_corners = corners
	props.cam_frustrum_centre  = centre
	return corners, centre
end

function Camera:getFrustrumCornersWorldSpace()
	local props = self.props
	if not props.cam_frustrum_corners then
		self:generateFrustrumCornersWorldSpace()
	end
	return props.cam_frustrum_corners, props.cam_frustrum_centre
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
