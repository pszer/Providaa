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

	{"cam_perspective_matrix", nil, nil, nil, "perspective matrix"},
	{"cam_view_matrix", nil, nil, nil, "view position matrix"},
	{"cam_rot_matrix", nil, nil, nil, "view rotation matrix"},
	{"cam_rotview_matrix", nil, nil, nil, "view position matrix"},

	{"cam_bend_enabled", "boolean", false, nil,           "when enabled, things further away from the camera decrease in y value"},
	{"cam_bend_coefficient", "number", 8048, PropMin(1), "the lower the number, the more exaggerated the bend effect"}

}
