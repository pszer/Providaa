--[[ property table prototype for model object
--]]
--

require "prop"

ModelPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"model_name", "string", "", nil, "model's name" }, -- done

	{"model_position", "table", nil, PropDefaultTable{0,0,0}, "model's world position"},
	{"model_rotation", "table", nil, PropDefaultTable{0,0,0}, "model's world rotation"},
	{"model_scale"   , "table", nil, PropDefaultTable{1,1,1}, "model's scale"},
	{"model_up_vector" , "table", { 0 ,  -1  , 0 }, nil, "model`s upward pointing vector",  "readonly"},
	{"model_dir_vector", "table", { 0 , 0  , -1 }, nil, "model`s forward pointing vector", "readonly"},

	{"model_mesh", nil, nil, nil, "model's love2d mesh"},

	{"model_animations", nil, nil, nil, "model's animations"},
	{"model_skeleton"  , nil, nil, nil, "model's skeleton"},
	{"model_animated"  , "boolean", false, nil, "is model animated?"},

	{"model_static"    , "boolean", false, nil, "is model instance static?"}
}

ModelInstancePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"model_i_reference", nil, nil, nil, "the model this instance is referencing" }, -- done

	{"model_i_position", "table", nil, PropDefaultTable{0,0,0}, "model's world position"},
	{"model_i_rotation", "table", nil, PropDefaultTable{0,0,0}, "model's world rotation"},
	{"model_i_scale"   , "table", nil, PropDefaultTable{1,1,1}, "model's scale"},

	{"model_i_static"    , "boolean", false, nil, "is model instance static?"}

}
