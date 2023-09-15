require "vec3"

local func = function(GameData)
	return function(ent, state, direction)
		local walk_speed = state.state_walking_speed
		local dt = GameData:getDt()

		local dir = {
			direction[1] * walk_speed * dt,
			direction[2] * walk_speed * dt,
			direction[3] * walk_speed * dt,
		}

		ent:translatePosition(dir)
	end
end
return func
