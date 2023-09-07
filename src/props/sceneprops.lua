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

	{"scene_fog_start", "number", 1600, nil,                              "distance where fog begins"},
	{"scene_fog_end", "number", 2048, nil,                               "distance where fog begins"},
	{"scene_fog_colour", "table", {209/255, 247/255, 255/255}, nil, "fog colour"},

	{"scene_models", "table", nil, PropDefaultTable{}, "collection of scene's model instances"},
	{"scene_lights", "table", nil, PropDefaultTable{}, "collection of scene's lights (max 64)"},
	{"scene_meshes", "table", nil, PropDefaultTable{}, "scenes generated meshes"},
	{"scene_generic_mesh", nil, nil, nil, "the mesh of the entire map without textures as one, used in shadow mapping"},

	{"scene_light_col", "table", {255/255, 235/255, 204/255, 5}, nil,   "colour of the ambient light"},
	{"scene_ambient_col", "table", {135/255, 243/255, 255/255, 7}, nil, "colour of the ambience (shows up in shadows)"},
	{"scene_light_dir", "table", {-0.3,-0.8,0.5}, nil,             "direction of ambient light source"},

	{"scene_skybox", "string", "skyday01.png", nil,           "scene's skybox, if empty string then no skybox is drawn"},
	{"scene_skybox_hdr_brightness", "number", 1.0, nil,       "HDR brightness for skybox"}
}
