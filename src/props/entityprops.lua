--[[ property table prototype for entity object
--]]
--

require "prop"

EntPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"ent_pos", "table", nil, PropDefaultTable{0,0,0}  , "entity position" }, -- done
	{"ent_rot", "table", nil, PropDefaultTable{0,0,0}  , "entity rotation" }, -- done
	{"ent_scale", "table", nil, PropDefaultTable{0,0,0}, "entity scale" }, -- done

	{"ent_model", nil, nil, nil, "entity model"},

}
