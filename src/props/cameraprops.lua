--[[ property table prototype for camera object
--]]
--

require "prop"

CameraPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"cam_x", "number", 8.5*32, nil, "camera x position" }, -- done
	{"cam_y", "number", -128-64, nil, "camera y position" }, -- done
	{"cam_z", "number", -16, nil, "camera z position" }, -- done

	{"cam_yaw",   "number", 0, nil, "camera yaw angle" }, -- done
	{"cam_pitch", "number", -0.95, nil, "camera pitch angle" }, -- done
	{"cam_roll",  "number", 0, nil, "camera roll angle"},

	{"cam_fov", "number", 75.0, nil, "camera fov"},

	{"cam_viewport", nil, nil, nil, "camera viewport (Love2D Canvas)"},
	{"cam_viewport_w", "number", 1366, nil, "camera viewport width"},
	{"cam_viewport_h", "number", 768, nil, "camera viewport width"},
	{"cam_depthbuffer", nil, nil, nil, "depth buffer for z-testing (Love2D Canvas)"},

	{"cam_perspective_matrix", nil, nil, nil, "perspective matrix"},
	{"cam_view_matrix", nil, nil, nil, "view matrix"}

}
