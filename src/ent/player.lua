require "entity"

EntityPlayerPrototype = EntityPropPrototype:extend{

	{"ent_identifier", "string", "player", nil},
	{"ent_model_name", "string", "pianko_model", nil},

	{"ent_hitbox_position", "table", nil, PropDefaultTable{-10,-64,-10}, "entity's hitbox position, local to ent_position"},
	{"ent_hitbox_size", "table", nil, PropDefaultTable{20,64,20}, "entity's hitbox size, local to ent_position"},

	{"ent_states", "table", nil, PropDefaultTable{
{
			["state_walking"] =
			EntityStatePropPrototype{
				["state_commands"] = {
					["entity_walk_towards"] = function(ent, state, dir) print(unpack(dir)) end
				},

				["state_enter"] = function(ent) print("enter") end
			}

	}}

		["ent_identifier"] = "player",
		["ent_model"] = instance,
		["ent_position"] = {200, -24, -200},
		["ent_states"] = {
			["state_walking"] =
			EntityStatePropPrototype{
				["state_commands"] = {
					["entity_walk_towards"] = function(ent, state, dir) print(unpack(dir)) end
				},

				["state_enter"] = function(ent) print("enter") end
			}
		},
		["ent_hooks_info"] = {
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
		}
}
