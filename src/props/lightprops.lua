--[[ property table prototype for light object
--]]
--

require "prop"

LightPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"light_pos", "table", nil, PropDefaultTable{0,0,0,0}, "light position, if w component is 0 then light is directional, otherwise its a point light" },
	{"light_dir", "table", nil, PropDefaultTable{0,-1,0, "rot"}, "light direction"},

	{"light_size", "number", 500, nil,                     "light's size, only applies for point lights"},
	{"light_col", "table", nil, PropDefaultTable{1,1,1,1}, "light's colour; alpha channel determines light`s strength"},

	--[[
	{"light_depthmap", nil, nil, nil,          "light's depthbuffer for shadow mapping dynamic objects"},
	{"light_static_depthmap", nil, nil, nil,   "light's depthbuffer for shadow mapping static objects"},

	{"light_cubemap",  nil, nil, nil,          "light's cubemap depthbuffer for shadow mapping (point lights)"},
	{"light_cube_lightspace_matrices", "table", nil, PropDefaultTable{}, "6 lightspace matrices used for static point light shadowmaps"},
	{"light_cube_lightspace_far_plane", "number", 0, nil, "the far plane for the point lights projection matrices"},

	{"light_lightspace_matrix", nil, nil, nil, "matrix for moving points to the space for this light"},
	{"light_lightspace_matrix_dimensions", nil, nil, nil, "min_x,max_x,min_y,max_y,min_z,max_z for lightspace_matrix projection."},
	{"light_lightspace_matrix_global_dimensions", nil, nil, nil, "min_x,max_x,min_y,max_y,min_z,max_z for lightspace_matrix projection."},

	{"light_static_lightspace_matrix", nil, nil, nil, "matrix for moving points to the space for this light`s (for static shadowmapping)."},
	{"light_static_lightspace_matrix_dimensions", nil, nil, nil, "min_x,max_x,min_y,max_y,min_z,max_z for static_lightspace_matrix projection."},
	{"light_static_lightspace_matrix_global_dimensions", nil, nil, nil, "min_x,max_x,min_y,max_y,min_z,max_z for static_lightspace_matrix projection."},
	{"light_static_depthmap_redraw_flag", "boolean", true, nil, [[set to true whenever a new static lightspace matrix is generated.
	                                                               set it to false after rendering a new static shadowmap!]]--},--]]

	{"light_static", "boolean", true, nil,     "true if light is never expected to change in property"}

}
