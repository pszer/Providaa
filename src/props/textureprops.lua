--[[ property table prototype for texture object
--]]
--

require "prop"

TexturePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"texture_name", "string", "", nil, "texture name", "readonly" }, -- done

	{"texture_imgs", "table", PropDefaultTable{}, nil,  "table of textures animation frames"},
	{"texture_frames", "number", 1, nil,                "number of animation frames"},
	{"texture_sequence", "table", {}, nil,              "table of indices "},
	{"texture_sequence_length", "number", 1, nil,       "table of indices "},

	{"texture_animated", "boolean", false, nil,         "is texture animated?", "readonly"},

	{"texture_animation_delay", "number", 60/2,     nil,    "delay between each animation frame in 1/60th of a second"},
	{"texture_wrap_mode",       "string", "repeat", PropIsOneOf{"clamp","repeat","clampzero","mirroredrepeat"}}, -- implement
	{"texture_type",            "string", "2d",     PropIsOneOf{"2d","array","cube","volume"}} -- implement

}
