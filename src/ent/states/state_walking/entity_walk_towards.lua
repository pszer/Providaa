require "vec3"

require "math"
require "angle"

local __tempvec = {}
local func = function(GameData)
	return function(ent, state, args)
		local M_PI = 3.1415926535897932384626433832795
		local M_2PI = 2*3.1415926535897932384626433832795

		local walk_speed = state.state_walking_speed
		local walk_accel = state.state_walking_accel 
		local dt = GameData:getDt()

		local direction = args.dir
		__tempvec[1] = direction[1] * walk_accel
		__tempvec[2] = direction[2] * walk_accel 
		__tempvec[3] = direction[3] * walk_accel 
		ent:accelerate( __tempvec, dt )

		local angle = atan3(direction[1] , direction[3])
		local acc = state.state_walking_rot_acc
		local diff = differenceRadians(angle, acc) + 1.0

		local rot_speed = state.state_walking_rot_speed 
		local new_angle = slerpRadians(state.state_walking_rot_acc, angle, math.min(dt*rot_speed * diff*diff, 1.0))
		state.state_walking_rot_acc = new_angle

		__tempvec[1] = 0
		__tempvec[2] = new_angle
		__tempvec[3] = 0
		__tempvec[4] = "rot"
		ent:setRotation(__tempvec)

		ent:limitSpeed( walk_speed )
		state.state_walking_deaccel = false
	end
end
return func
