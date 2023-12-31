-- prop table for animated face instances
--

require "prop"

AnimFacePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"animface_decor_reference", nil, nil, nil, "reference to the ModelDecor this animated face will be applied to" },

	{"animface_eyesdata_name", "string", "", nil, "name of eye's in cfg/eyes to use for this face."},
	{"animface_eyesdata", nil, nil, nil,          "eye's to use for this face."},
	{"animface_features", "table", nil, PropDefaultTable{}, "table of other facial features."},

	{"animface_texture", nil, nil, nil,         "texture to blit face elements onto for the final composition."},
	{"animface_texture_dim", "table", nil, PropDefaultTable{256,256}, "dimensions of animface_texture"},

	{"animface_righteye_position", "table", nil, PropDefaultTable{0,0}, "x,y position to blit right eye to onto animface_texture"},
	{"animface_lefteye_position", "table", nil, PropDefaultTable{0,0},  "x,y position to blit left eye to onto animface_texture"},

	{"animface_righteye_pose", "string", "neutral", nil, "the pose to use for the right eye"},
	{"animface_lefteye_pose" , "string", "neutral", nil, "the pose to use for the left eye"},

	{"animface_righteye_dir", "table", nil, PropDefaultTable{0,0,1}, "direction vector of where the right eye is looking"},
	{"animface_lefteye_dir" , "table", nil, PropDefaultTable{0,0,1}, "direction vector of where the left eye is looking"},

	{"animface_curr_anim", "string", "neutral", nil, "current animation of the face (in animface_anims)"},
	--{"animface_loop"  ,"boolean", true, nil, "whether to loop the current face animation"},
	{"animface_speed" ,"number", 1.0, nil, "face animation speed"},
	{"animface_anims" , "table", nil, PropDefaultTable{}, "animations"}

}
