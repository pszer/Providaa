require "props/entityprops"

EntityPlayerPrototype = EntityPropPrototype:extend{

	{"ent_identifier", "string", "player", nil},
	{"ent_model_name", "string", "pianko_model", nil},

	{"ent_hitbox_position", "table", nil, PropDefaultTable{-10,-64,-10}, "entity's hitbox position, local to ent_position"},
	{"ent_hitbox_size", "table", nil, PropDefaultTable{20,64,20}, "entity's hitbox size, local to ent_position"},

	{"ent_states", "table", nil, PropDefaultTable{
		["state_walking"] = require "ent.states.state_walking"
	}},

	{"ent_hooks_info", "table", nil, PropDefaultTable{
		{type="control", handler="overworld", keybind="move_up", event="press",
		 hook_func = function(ent)
			return function(ticktime, realtime)
				ent:callCommand("entity_walk_towards", { 0 , 0 , -1 })
			end
		 end},

		{type="control", handler="overworld", keybind="move_down", event="press",
		 hook_func = function(ent)
			return function(ticktime, realtime)
				ent:callCommand("entity_walk_towards", { 0 , 0 , 1 })
			end
		 end},

		{type="control", handler="overworld", keybind="move_left", event="press",
		 hook_func = function(ent)
			return function(ticktime, realtime)
				ent:callCommand("entity_walk_towards", { -1 , 0 , 0 })
			end
		 end},

		{type="control", handler="overworld", keybind="move_right", event="press",
		 hook_func = function(ent)
			return function(ticktime, realtime)
				ent:callCommand("entity_walk_towards", { 1 , 0 , 0 })
			end
		 end}
	}}
}

return EntityPlayerPrototype
