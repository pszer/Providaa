--[[ property table prototype for eye object
--]]
--

require "prop"

EyesDataPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"eyes_source", nil, nil, nil, "source image containing the eye's components and poses" },

	{"eyes_dimensions", "table", nil, PropDefaultTable{0,0}, "the width and height in pixels for each eye component"},
	{"eyes_pose_count", "number", 0 , nil, "number of eye poses"},

	{"eyes_iris"     , nil, nil, nil,                    "eyes iris component (stored as love2d quad)"},
	{"eyes_highlight", nil, nil, nil,                    "eyes highlight component (stored as love2d quad)"},
	{"eyes_poses" , "table", nil, PropDefaultTable{} , [[table of eye pose, each pose is a table containing entries
	                                                      name (string),
														  base (love2D quad),
														  sclera (love 2Dquad),
														  iris (Texture),
														  highlight (Texture).
														  the iris and highlight entries are optional overrides for the source
														  image's iris and highlight]]},

	{"eyes_look_max", "table", nil, PropDefaultTable{8,8}, "the maximum distance in pixels the iris can be translated in the +x and +y direction"},
	{"eyes_look_min", "table", nil, PropDefaultTable{8,8}, "the maximum distance in pixels the iris can be translated in the -x and -y direction"}

}
