--[[ property table prototype for tile object
--]]
--

require "prop"

TILE_MIN_Y = 0
TILE_MAX_Y = 32

WallTilePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"wtile_texture", nil, nil, nil,   "wall tile's texture"},
	{"wtile_texture_scalex", "number", 1, nil, "scale for wall tiles texture"},
	{"wtile_texture_scaley", "number", 1, nil, "scale for wall tiles texture"},
	{"wtile_texture_offx", "number", 0, nil,   "x offset for wall tiles texture"},
	{"wtile_texture_offy", "number", 0, nil,   "y offset for wall tiles texture"},

	{"wtile_coords", "table", nil, PropDefaultTable{}, "wall tile coords"},

	{"wtile_mesh", nil, nil, nil,              "the mesh which this wall tile is a part of"},
	{"wtile_mesh_vstart_index", "number", 0, nil, "the starting index vertex in the mesh for this wall tile"},
	{"wtile_mesh_vend_index", "number", 0, nil,   "the final index vertex in the mesh for this wall tile"},

}
