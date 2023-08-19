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
	{"tile_model", "string", "block",  nil,                         "tile's model   (only for model tiles)", "readonly"},

	{"tile_mesh", nil, nil, nil,              "tiles Love2D mesh for rendering"},
	{"tile_mesh_optimized", "boolean", false, nil, "flag for whether or not this tile is missing a mesh due to grid:optimizeMesh"},


	{"tile_walkable", "boolean", true, nil, nil,         "can be walked on by entities"},

}
