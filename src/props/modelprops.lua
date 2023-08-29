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
	{"model_scale",    "table", nil, PropDefaultTable{1,1,1}, "model's scale"},

	{"model_mesh", nil, nil, nil, "model's love2d mesh"},

	{"model_skeleton", nil, nil, nil, "model's skeleton for animation"},
	{"model_animations", nil, nil, nil, "model's animations"},
	{"model_animated", "boolean", false, nil, "is model animated?"}

}
