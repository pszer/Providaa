--[[ property table prototype for light object
--]]
--

require "prop"

LightPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"light_pos", "table", nil, PropDefaultTable{0,0,0,0}, "light position, if w component is 0 then light is directional, otherwise its a point light" },
	{"light_dir", "table", nil, PropDefaultTable(0,-1,0), "light direction (each component is a rotation around that axis)"},

	{"light_col", "table", nil, PropDefaultTable{1,1,1,1}, "light's colour; alpha channel determines light`s strength"},

	{"light_depthmap", nil, nil, nil,          "light's depthbuffer for shadow mapping dynamic objects"},
	{"light_static_depthmap", nil, nil, nil,   "light's depthbuffer for shadow mapping static objects"},

	{"light_lightspace_matrix", nil, nil, nil, "matrix for moving points to the space for this light"},

	{"light_static_lightspace_matrix", nil, nil, nil, "matrix for moving points to the space for this light`s (for static shadowmapping)."},
	{"light_static_lightspace_matrix_dimensions", nil, nil, nil, "min_x,max_x,min_y,max_y,min_z,max_z for static_lightspace_matrix projection."},
	{"light_static_depthmap_redraw_flag", "boolean", false, nil, [[set to true whenever a new static lightspace matrix is generated.
	                                                               set it to false after rendering a new static shadowmap!]]}

	{"light_static", "boolean", true, nil,     "true if light is never expected to change in property"}

}
