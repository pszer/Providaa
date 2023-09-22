-- prop table for map edit
--

require "prop"

MapEditPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"mapedit_filename", nil, nil, nil, "working map's filename"},

	{"mapedit_cam", nil, nil, nil, "camera for map edit view" },
	{"mapedit_cam_speed", "number", 400, nil, "camera move speed"},
	{"mapedit_cam_rotspeed", "number", 0.001, nil, "camera rotation speed"},

	{"mapedit_command_stack", "table", nil, PropDefaultTable{}, "history of invoked map edit commands"},
	{"mapedit_command_stack_max", "number", 300, nil,           "max number of commands to remember"},
	{"mapedit_map_mesh", nil, nil, nil, "MapMesh object for a map`s static geometry, displayed in map edit view"},

	{"mapedit_models", "table", nil, PropDefaultTable{}, "table of map's models"},

	{"mapedit_tileset", "table", nil, PropDefaultTable{}, "tileset for active map"},
	{"mapedit_wallset", "table", nil, PropDefaultTable{}, "wallset for active map"},

	{"mapedit_skybox_enable", "boolean", true, nil, "whether to draw skybox in viewport"},
	{"mapedit_skybox", "table", nil, PropDefaultTable{}, "maps skybox info"},
	{"mapedit_skybox_img", nil, nil, nil, "skybox img to use in the viewport"},

	{"mapedit_map_width" , "number", 0, nil, "active map width"},
	{"mapedit_map_height", "number", 0, nil, "active map height"},

	{"mapedit_tile_heights", "table", nil, PropDefaultTable{}, "map_width x map_height table of tile heights"},
	{"mapedit_tile_map", "table", nil, PropDefaultTable{}, "map_width x map_height mapping of tiles to the tileset"},
	{"mapedit_wall_map", "table", nil, PropDefaultTable{}, "map_width x map_height mapping of walls to the wallset"},

	{"mapedit_anim_tex", "table", nil, PropDefaultTable{}, "active map animated texture definitions"},

	{"mapedit_tile_vertices", "table", nil, PropDefaultTable{}, [[map_width x map_height mapping of tiles to their vertices in map_mesh,
	                                                              each entry is a start index, the next 4 vertices starting from that
																  index in the mesh are the vertices for the tile]]},
	{"mapedit_wall_vertices", "table", nil, PropDefaultTable{}, [[map_width x map_height mapping of walls to their vertices in map_mesh,
	                                                              each entry is {west=int/nil, south=int/nil, east=int/nil, north=int/ni;}
	                                                              each number is a start index, the next 4 vertices starting from that
																  index in the mesh are the vertices for the tile]]}

}
