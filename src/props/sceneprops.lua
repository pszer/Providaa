require "prop"

ScenePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"scene_grid", nil, nil, nil, "scene tile grid"},
	{"scene_walls", nil, nil, nil, "scene walls"},

	{"scene_width",  "number", 1, nil, "scene grid width"},
	{"scene_height", "number", 1, nil, "scene grid height"}

}
