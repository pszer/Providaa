require "vec3"

local __tempvec = {}
local func = function(GameData)
	return function(ent, state, args)
		local walk_speed = state.state_walking_speed
		local dt = GameData:getDt()

		local direction = args.dir
		__tempvec[1] = direction[1] * walk_speed * dt
		__tempvec[2] = direction[2] * walk_speed * dt
		__tempvec[3] = direction[3] * walk_speed * dt

		ent:translatePosition(__tempvec)
	end
end
return func
