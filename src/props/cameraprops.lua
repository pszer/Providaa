--[[ property table prototype for camera object
--]]
--

require "prop"

CameraPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"cam_x", "number", 8*32, nil, nil, "camera x position" }, -- done
	{"cam_y", "number", -64, nil, nil, "camera y position" }, -- done
	{"cam_z", "number", -16, nil, nil, "camera z position" }, -- done

	{"cam_yaw",   "number", 0, nil, nil, "camera z position" }, -- done
	{"cam_pitch", "number", 0, nil, nil, "camera z position" }, -- done

	{"cam_viewport", nil, nil, nil, "camera viewport (Love2D Canvas)"},
	{"cam_viewport_w", "number", 1366, nil, "camera viewport width"},
	{"cam_viewport_h", "number", 768, nil, "camera viewport width"}

}
