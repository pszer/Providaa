require 'math'
local cpml = require 'cpml'

require "camera"

SCALE_3D = 24
CLIP_FRONT_Z = 8
CURVE_COEFF = 1280

function screenCoord3D(x,y,z)
	return x/z, y/z
end

function cameraCoord3D(x,y,z, cam)
	cam = cam or CAM
	local Z = z - cam.props.cam_z
	return (x - cam.props.cam_x)/Z, (y - cam.props.cam_y)/Z
end

function translateCoord3D(x,y,z, cam)
	cam = cam or CAM
	local props = cam.props

	local X,Y,Z = x - props.cam_x,
		y - props.cam_y,
		z - props.cam_z

	Y = Y + (Z*Z)/CURVE_COEFF

	local yawsin, yawcos = math.sin(props.cam_yaw), math.cos(props.cam_yaw)
	local pitchsin, pitchcos = math.sin(props.cam_pitch), math.cos(props.cam_pitch)

	local X2 = yawcos*X - yawsin*Z
	local Z2 = yawsin*X + yawcos*Z

	local Y2 = pitchcos*Y + pitchsin*Z2
	local Z3 = -pitchsin*Y + pitchcos*Z2

	return X2, Y2, Z3
end

function calculateHorizon(camy)
	camy = camy or CAM.props.cam_y
	if CURVE_COEFF == 0 then return 100000000 end
	local c = -4 * camy / CURVE_COEFF
	if c < 0 then return 1000000000 end
	c = math.sqrt(c) * CURVE_COEFF/2
	return c
end

function cameraCoord3DScaled(x,y,z, cam, scale)
	scale = scale or SCALE_3D
	cam = cam or CAM
	local X,Y,Z = translateCoord3D(x,y,z, cam)

	Z = Z/SCALE_3D
	return SCALE_3D*X/Z, SCALE_3D*Y/Z
end

function clipTriangleTest(v)
	local x1,y1,z1 = v[1][1], v[1][2], v[1][3]	
	local x2,y2,z2 = v[2][1], v[2][2], v[2][3]
	local x3,y3,z3 = v[3][1], v[3][2], v[3][3]

	if z1 < CLIP_FRONT_Z or z2 < CLIP_FRONT_Z or z3 < CLIP_FRONT_Z then
		return true
	end

	local r = RESOLUTION_ASPECT_RATIO
	if math.abs(x1) > z1*r or math.abs(y1) > z1*r then
		return true
	end
	if math.abs(x2) > z2*r or math.abs(y2) > z2*r then
		return true
	end
	if math.abs(x3) > z3*r or math.abs(y3) > z3*r then
		return true
	end

	return false
end
