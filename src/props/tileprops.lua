--[[ property table prototype for tile object
--]]
--

require "prop"

TILE_MIN_Y = 0
TILE_MAX_Y = 32

TilePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"tile_type", "string", "void", PropIsOneOf{"void","land","model"}, "tile type", "readonly" }, -- done

	{"tile_height1", "number", 0, PropIntegerClamp(TILE_MIN_Y,TILE_MAX_Y),   "tile's y position (-x,+z corner)" }, -- done
	{"tile_height2", "number", 0, PropIntegerClamp(TILE_MIN_Y,TILE_MAX_Y),   "tile's y position (+x,+z corner)" }, -- done
	{"tile_height3", "number", 0, PropIntegerClamp(TILE_MIN_Y,TILE_MAX_Y),   "tile's y position (+x,-z corner)" }, -- done
	{"tile_height4", "number", 0, PropIntegerClamp(TILE_MIN_Y,TILE_MAX_Y),   "tile's y position (-x,-z corner)" }, -- done

	{"tile_texture", "string", "tile", nil,                         "tile's texture (only for land tiles)" , "readonly"},
	{"tile_texture_animation_offset", "number", 0, nil,             "offset for texture animation on this tile"},
	{"tile_texture_scalex", "number", 1, nil,                        "scale for tiles texture"},
	{"tile_texture_scaley", "number", 1, nil,                        "scale for tiles texture"},
	{"tile_texture_offx", "number", 0, nil,                         "x offset for tiles texture"},
	{"tile_texture_offy", "number", 0, nil,                         "y offset for tiles texture"},

	{"tile_model", "string", "block",  nil,                         "tile's model   (only for model tiles)", "readonly"},

	{"tile_mesh", nil, nil, nil,              "the mesh which this tile is a part of"},
	{"tile_mesh_vstart_index", "number", 0, nil, "the starting index vertex in the mesh for this tile"},
	{"tile_mesh_vend_index", "number", 0, nil,   "the final index vertex in the mesh for this tile"},

	{"tile_walkable", "boolean", true, nil, nil,         "can be walked on by entities"},

}
