require "props.entityprops"

local entity_walk_towards = require "ent.states.state_walking.entity_walk_towards"

local StateWalkingPrototype = EntityStatePropPrototype:extend{

	{"state_commands", "table", nil, PropDefaultTable
		{
			["entity_walk_towards"] = entity_walk_towards
		},
		"state_walking commands"
	}, -- done

	{"state_update", nil, function(GameData) return function(ent,state) end end, nil },
	{"state_enter" , nil, function(GameData) return function(ent,state) end end, nil },
	{"state_exit"  , nil, function(GameData) return function(ent,state) end end, nil },

	{"state_walking_speed", "number", 500, nil, "max walk speed, stated in world units per second"}

}

return StateWalkingPrototype
