--[[ property table prototype for grid object
--]]
--

require "prop"

GridPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"grid_w", "number", 1, PropMin(1), "grid width position (+x direction)" , "readonly"}, -- done
	{"grid_h", "number", 1, PropMin(1), "grid height position(+z direction)", "readonly"}, -- done
	{"grid_data", "table", nil, nil,    "grid 2d array data position", "readonly"}, -- done

}
