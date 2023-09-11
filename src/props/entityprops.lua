--[[ property table prototype for entity object
--]]
--

require "prop"

EntityPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"ent_position", "table", nil, PropDefaultTable{0,0,0}  , "entity position" }, -- done
	{"ent_rotation", "table", nil, PropDefaultTable{0,0,0}  , "entity rotation" }, -- done
	{"ent_scale", "table", nil, PropDefaultTable{1,1,1}, "entity scale" }, -- done

	{"ent_hitbox_position", "table", nil, PropDefaultTable{-12,-24,-12}, "entity's hitbox position, local to ent_position"},
	{"ent_hitbox_size", "table", nil, PropDefaultTable{24,24,24}, "entity's hitbox size, local to ent_position"},

	{"ent_model", nil, nil, nil,                      "entity`s model instance. can be nil for logic entities."},
	{"ent_model_inherit", "boolean", true, nil,       "if true, the model inherits this entity's position, rotation and scale."},

	{"ent_current_states", "table", nil, PropDefaultTable{},              "entities current states"},
	{"ent_states", "table", nil,         PropDefaultTable{},  "entities possible states, see EntState"},

	{"ent_delete_flag", "boolean", false, nil,        "set to true to signal entity deletion"}

}

EntityStatePropPrototype = Props:prototype{

	{"state_update", nil, nil, nil, "optional update function, function(Entity)"},
	{"state_enter" , nil, nil, nil, "optional function called when entity changes to this state, function(Entity)"},
	{"state_exit"  , nil, nil, nil, "optional function called when entity changes from this state, function(Entity)"},

	{"state_parent", nil, nil, nil, "optional parent name, if state has a parent then it inherits its state_commands"},
	{"state_commands", "table", nil, PropDefaultTable{}, "this states possible commands, each entry is [\"commandname\"] = function(Entity, ...)"}

}
