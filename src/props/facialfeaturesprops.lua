--[[ property table prototype for eye object
--]]
--

require "prop"

EyesDataPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"eyes_filename", "string", "", nil, "name of texture to use as eyes_source"},
	{"eyes_source", nil, nil, nil, "source image containing the eye's components and poses" },

	{"eyes_dimensions", "table", nil, PropDefaultTable{0,0}, "the width and height in pixels for each eye component"},
	{"eyes_pose_count", "number", 0 , nil, "number of eye poses"},

	{"eyes_iris"     , nil, nil, nil,                    "eyes iris component"},
	{"eyes_highlight", nil, nil, nil,                    "eyes highlight component"},
	{"eyes_poses" , "table", nil, PropDefaultTable{} , [[table of eye pose, each pose is a table containing entries
	                                                      name (string),
														  base,
														  sclera,
														  iris,
														  highlight.
														  the iris and highlight entries are optional overrides for the source
														  image's iris and highlight]]},

	{"eyes_look_max", "number", 8, nil, "the maximum distance in pixels the iris can be translated"},

	{"eyes_pose_map", "table", nil, PropDefaultTable{}, "map's eye pose name to index in eyes_poses"},

	--{"eyes_right_canvas", nil, nil, nil, "canvas where right eye is composited together"},
	--{"eyes_left_canvas" , nil, nil, nil, "canvas where left eye is composited together"},

	{"eyes_radius", "number", 12, nil,   "approximate radius of the eye"}

}
