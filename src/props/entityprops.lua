--[[ property table prototype for entity object
--]]
--

require "prop"

EntPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"ent_position", "table", nil, PropDefaultTable{0,0,0}  , "entity position" }, -- done
	{"ent_rotation", "table", nil, PropDefaultTable{0,0,0}  , "entity rotation" }, -- done
	{"ent_scale", "table", nil, PropDefaultTable{1,1,1}, "entity scale" }, -- done

	{"ent_model", nil, nil, nil,               "entity`s model instance. can be nil for logic entities."},
	{"ent_model_inherit", "boolean", true, nil,"if true, the model inherits this entities position, rotation and scale."},

}
