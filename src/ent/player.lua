require "props/entityprops"

local state_walking = require "ent.states.state_walking"

local dir_up    = {dir={ 0, 0,-1}}
local dir_down  = {dir={ 0, 0, 1}}
local dir_left  = {dir={-1, 0, 0}}
local dir_right = {dir={ 1, 0, 0}}

local EntityPlayerPrototype = EntityPropPrototype:extend{

	{"ent_identifier", "string", "player", nil},
	{"ent_model_name", "string", "pianko_model", nil},

	{"ent_hitbox_position", "table", nil, PropDefaultTable{-10,-64,-10}, "entity's hitbox position, local to ent_position"},
	{"ent_hitbox_size", "table", nil, PropDefaultTable{20,64,20}, "entity's hitbox size, local to ent_position"},
	{"ent_hitbox_inherit" , "boolean", false, nil},

	{"ent_states", "table", nil, PropDefaultTable{
		["state_walking"] = state_walking
	}},

	{"ent_hooks_info", "table", nil, PropDefaultTable{
		{type="control", handler="overworld", keybind="move_up", event="press",
		 hook_func = function(ent)
			return function(args)
				ent:callCommand("entity_walk_towards", dir_up)
			end
		 end},

		{type="control", handler="overworld", keybind="move_down", event="press",
		 hook_func = function(ent)
			return function(args)
				ent:callCommand("entity_walk_towards", dir_down)
			end
		 end},

		{type="control", handler="overworld", keybind="move_left", event="press",
		 hook_func = function(ent)
			return function(args)
				ent:callCommand("entity_walk_towards", dir_left)
			end
		 end},

		{type="control", handler="overworld", keybind="move_right", event="press",
		 hook_func = function(ent)
			return function(args)
				ent:callCommand("entity_walk_towards", dir_right)
			end
		 end}
	}}
}

return EntityPlayerPrototype
