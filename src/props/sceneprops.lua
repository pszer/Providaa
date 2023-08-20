require "prop"

ScenePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"scene_grid", nil, nil, nil, "scene tile grid"},
	{"scene_walls", nil, nil, nil, "scene walls"},

	{"scene_width",  "number", 1, nil, "scene grid width"},
	{"scene_height", "number", 1, nil, "scene grid height"},

	{"scene_fog_start", "number", 1024, nil, "distance where fog begins"},
	{"scene_fog_end", "number", 2024, nil, "distance where fog begins"},
	{"scene_fog_colour", "table", {222/255, 210/255, 197/255, 1.0}, nil, "fog colour"},

	{"scene_meshes", "table", nil, PropDefaultTable{}, nil, "scenes generated meshes"}

}
