ModelDecorPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"decor_name",           "string", "", nil, "model decor ID"},
	{"decor_reference"         , nil, nil, nil, "model accessory model" },

	{"decor_position", "table", nil, PropDefaultTable{0,0,0}, "model accessory's local position"},
	{"decor_rotation", "table", nil, PropDefaultTable{0,0,0}, "model accessory's local rotation"},
	{"decor_scale"   , "table", nil, PropDefaultTable{1,1,1}, "model accessory's local scale"},

	{"decor_parent_bone", "string", "", nil, "parent bone to follow"}

}
