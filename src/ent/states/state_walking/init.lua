require "props.entityprops"

local entity_walk_towards = require "ent.states.state_walking.entity_walk_towards"

local StateWalkingPrototype = EntityStatePropPrototype:extend{

	{"state_commands", "table", nil, PropDefaultTable
		{
			["entity_walk_towards"] = entity_walk_towards
		},
		"state_walking commands"
	}, -- done

	{"state_update", nil, function(GameData)
		local rot_last_frame = {0,0,0, "rot"}
		local __tempvec = {}
		return function(ent,state)
			local vel = ent:getVelocity()
			local anim_speed = state.state_walking_anim_speed
			local dt  = GameData:getDt()

			if state.state_walking_deaccel then
				ent:scaleVelocity(state.state_walking_deaccel_scale, dt)

				if ent:getApproximateSpeed() < 0.1 then
					ent:setVelocity{0,0,0}
					ent:setAnimationTime(0, 1)
				end
			end

			local walk_speed = state.state_walking_speed
			ent:limitSpeed( walk_speed )
			state.state_walking_deaccel = true

			--local vel = ent:getVelocity()
			local dir_this_frame = state.state_walking_dir_this_frame
			if dir_this_frame[1] ~= 0 or dir_this_frame[3] ~= 0 then
				local angle = atan3( dir_this_frame[1] , dir_this_frame[3] )
				local acc = state.state_walking_rot_acc
				local diff = differenceRadians(angle, acc)*0.3 + 1.0

				local rot_speed = state.state_walking_rot_speed 
				local new_angle = slerpRadians(state.state_walking_rot_acc, angle, math.min(dt*rot_speed * diff*diff, 1.0))
				state.state_walking_rot_acc = new_angle

				__tempvec[1] = 0
				__tempvec[2] = new_angle
				__tempvec[3] = 0
				__tempvec[4] = "rot"
				ent:setRotation(__tempvec)
			end

				local walk_speed = state.state_walking_speed
			local ent_speed  = ent:getSpeed()
			--ent:setAnimationSpeed(0.75 + 0.25*(anim_speed * ent_speed / walk_speed))
			ent:setAnimationSpeed(1)
			local diff = (walk_speed - ent_speed) / walk_speed
			ent:setAnimationInterp(diff * diff)

			local dir_this_frame = state.state_walking_dir_this_frame
			dir_this_frame[1] = 0
			dir_this_frame[2] = 0
			dir_this_frame[3] = 0
		end
	end,},
	{"state_enter" , nil, function(GameData)
		return function(ent,state)
			local walk_anim  = {"Walk", 0.0, 1.0, true}
			local stand_anim = {"Stand", 0.0, 1.0, true}
			ent:playAnimationInterp(walk_anim, stand_anim, 0.0)
		end
	end },
	{"state_exit"  , nil, function(GameData)
		return function(ent,state)
		end
	end },

	--{"state_walking_speed", "number", 80, nil,  "max walk speed, stated in world units per second"},
	{"state_walking_speed", "number", 280, nil,  "max walk speed, stated in world units per second"},
	{"state_walking_accel", "number", 200, nil ,  "walk speed acceleration, stated in world units per second"},
	{"state_walking_anim_speed", "number", 1.15, nil,  "scalar for walk speed animation"},

	{"state_walking_deaccel", "boolean", true, nil, "deaccelerates if set to true"},
	{"state_walking_deaccel_scale", "number", -4.5, nil, "the smaller, the faster the deacceleration"},

	{"state_walking_rot_speed", "number", 1.5, nil},
	{"state_walking_rot_acc", "number", 0, nil},
	{"state_walking_dir_this_frame", "table", nil, PropDefaultTable{0,0,0}}

}

return StateWalkingPrototype
