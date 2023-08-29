require "prop"

ScenePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"scene_grid", nil, nil, nil, "scene tile grid"},
	{"scene_walls", nil, nil, nil, "scene walls"},
	{"scene_wall_tiles", nil, nil, nil, "scene wall tiles"},

	{"scene_camera", nil, Camera:new(), nil, "scenes camera"},

	{"scene_width",  "number", 1, nil, "scene grid width"},
	{"scene_height", "number", 1, nil, "scene grid height"},

	{"scene_fog_start", "number", 800, nil, "distance where fog begins"},
	{"scene_fog_end", "number", 2048, nil, "distance where fog begins"},
	{"scene_fog_colour", "table", {209/255, 247/255, 255/255, 1.0}, nil, "fog colour"},

	{"scene_light_col", "table", {232/255, 228/255, 216/255}, nil,   "colour of the ambient light"},
	{"scene_ambient_col", "table", {196/255, 238/255, 255/255}, nil, "colour of the ambience (shows up in shadows)"},
	{"scene_light_dir", "table", {0.5,1,-0.25}, nil,                       "direction of ambient light source"},
	{"scene_ambient_str", "number", 0.6, nil,                        "strength of global illumination"},

	{"scene_skybox", "string", "skyday01.png", nil, "scene's skybox, if empty string then no skybox is drawn"},

	{"scene_meshes", "table", nil, PropDefaultTable{}, nil, "scenes generated meshes"},

}
