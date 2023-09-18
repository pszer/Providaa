require "props.entityprops"
require "event"
require "custommodel"
require "gameinterface"

Entity = {__type = "entity"}
Entity.__index = Entity

function Entity:new(props)
	local this = {
		props = EntityPropPrototype(props),

		ent_moved = true,
		recalculate_bounds_flag = true
	}

	setmetatable(this,Entity)

	return this
end

function Entity:newFromPrototype(prototype, props)
	local this = {
		props = prototype(props),

		ent_moved = true,
		recalculate_bounds_flag = true
	}

	setmetatable(this,Entity)

	return this
end

-- this function should not be treated as a virtual function to overwrite, thats the job of Entity:update
-- let this do what its gotta do
function Entity:internalUpdate(dt)
	assert(dt)

	for i,v in pairs(self.props.ent_current_states) do
		if v.state_update then
			v.state_update(self, v)
		end
	end

	self:translatePosition(self:getVelocity(), dt)

	self:updateModelPosition()
	if self.props.ent_hitbox_inherit then
		self:copyHitboxFromModel()
	end
	self.ent_moved = false
end

function Entity:update()

end

function Entity:updateModelPosition()
	local props = self.props
	if props.ent_model_inherit then
		local ent_pos = self:getPosition()
		local ent_rot = self:getRotation()
		local ent_scale = self:getScale()

		local model_inst = props.ent_model

		if model_inst then
			model_inst:setPosition(ent_pos)
			model_inst:setRotation(ent_rot)
			model_inst:setScale(ent_scale)
		end
	end
end

function Entity:getPosition()
	return self.props.ent_position end
function Entity:getRotation()
	return self.props.ent_rotation end
function Entity:getScale()
	return self.props.ent_scale end
function Entity:getVelocity()
	return self.props.ent_velocity end
function Entity:getSpeed()
	local vel = self:getVelocity()
	return math.sqrt(vel[1]*vel[1] + vel[2]*vel[2] + vel[3]*vel[3])
end
-- uses manhattan distance instead of euclidian
function Entity:getApproximateSpeed()
	local vel = self:getVelocity()
	local abs = math.abs
	return abs(vel[1]) + abs(vel[2]) + abs(vel[3])
end

local __temp_lmtspd_vec = {}
function Entity:limitSpeed( max_speed )
	local vel = self:getVelocity()
	local spd = self:getSpeed()

	if spd <= max_speed then return end

	local scale = max_speed / spd;
	__temp_lmtspd_vec[1] = scale * vel[1]
	__temp_lmtspd_vec[2] = scale * vel[2]
	__temp_lmtspd_vec[3] = scale * vel[3]
	self:setVelocity( __temp_lmtspd_vec )
end

local __temp_scvel_vec = {}
-- takes in a scalar to scale the entities velocity by
--  1.0 means no change
-- <1.0 decreases velocity over time
-- >1.0 increases velocity over time
function Entity:scaleVelocity(scale, dt)
	local diff = scale - 1.00
	local vel = self:getVelocity()
	__temp_scvel_vec[1] = vel[1] * diff
	__temp_scvel_vec[2] = vel[2] * diff
	__temp_scvel_vec[3] = vel[3] * diff
	self:accelerate(__temp_scvel_vec, dt)
end

function Entity:getModel()
	return self.props.ent_model end
function Entity:getIdentifier()
	return self.props.ent_identifier end

function Entity:setVelocity(vel)
	local v = self.props.ent_velocity
	if vel[1]~=v[1]or vel[2]~=v[2] or vel[3]~=v[3] then
		self.props.ent_velocity[1] = vel[1]
		self.props.ent_velocity[2] = vel[2]
		self.props.ent_velocity[3] = vel[3]
		--self.props.ent_position = pos
		--self.ent_moved = true
		--self.recalculate_bounds_flag = true
	end
end

local __temp_acc_vec = {}
-- adds an acceleration vector to the entity, scaled by
-- a given delta time step
function Entity:accelerate(vec, dt)
	local vel = self:getVelocity()
	__temp_acc_vec[1] = vel[1] + vec[1] * dt
	__temp_acc_vec[2] = vel[2] + vec[2] * dt
	__temp_acc_vec[3] = vel[3] + vec[3] * dt
	self:setVelocity(__temp_acc_vec)
end

function Entity:setPosition(pos)
	local v = self.props.ent_position
	if pos[1]~=v[1]or pos[2]~=v[2] or pos[3]~=v[3] then
		--local ent_pos = self.props.ent_position
		self.props.ent_position[1] = pos[1]
		self.props.ent_position[2] = pos[2]
		self.props.ent_position[3] = pos[3]
		--self.props.ent_position = pos
		self.ent_moved = true
		self.recalculate_bounds_flag = true
	end
end
function Entity:setRotation(rot)
	local r = self.props.ent_rotation
	if rot[1]~=r[1] or rot[2]~=r[2] or rot[3]~=r[3] or rot[4] ~= r[4] then
		--self.props.ent_rotation = rot
		self.props.ent_rotation[1] = rot[1]
		self.props.ent_rotation[2] = rot[2]
		self.props.ent_rotation[3] = rot[3]
		self.props.ent_rotation[4] = rot[4]
		self.ent_moved = true
		self.recalculate_bounds_flag = true
	end
end
function Entity:setScale(scale)
	local s = self.props.ent_scale
	if scale[1]~=s[1] or scale[2]~=s[2] or scale[3]~=s[3] then
		self.props.ent_scale[1] = scale[1]
		self.props.ent_scale[2] = scale[2]
		self.props.ent_scale[3] = scale[3]
		self.model_moved = true
		self.recalculate_bounds_flag = true
	end
end

function Entity:translatePosition(vec, dt)
	if vec[1]==0 and vec[2]==0 and vec[3]==0 then return end

	local dt = dt or 1.0

	local v = self.props.ent_position
	local new_pos = {
		v[1]+vec[1]*dt,
		v[2]+vec[2]*dt,
		v[3]+vec[3]*dt
	}
	self:setPosition(new_pos)
end

function Entity:copyHitboxFromModel()
	local model = self.props.ent_model
	if model then
		local pos, size = model:getBoundingBoxPosSize()

		self.props.ent_hitbox_size = size

		-- an entity's hitbox has it's position stored locally to ent_position
		-- this transforms the world co-ordinates to local space
		local ent_pos = self:getPosition()
		local local_pos = {
			pos[1] - ent_pos[1],
			pos[2] - ent_pos[2],
			pos[3] - ent_pos[3] }

		self.props.ent_hitbox_position = local_pos
	end
end

function Entity:updateHitbox()
	--if self.props.ent_hitbox_inherit then
end

function Entity:areBoundsChanged()
	return self.recalculate_bounds_flag
end
function Entity:informNewBoundsAreHandled()
	self.recalculate_bounds_flag = false
end

-- returns {x,y,z}, {dx,dy,dz}
function Entity:getWorldHitboxPosSize()
	local pos = self:getPosition()
	local hitbox_pos = self.props.ent_hitbox_position
	local hitbox_size = self.props.ent_hitbox_size

	return { pos[1] + hitbox_pos[1],
	         pos[2] + hitbox_pos[2],
	         pos[3] + hitbox_pos[3] },
		   { hitbox_size[1],
		     hitbox_size[2],
		     hitbox_size[3] }
end

-- returns {x,y,z}
function Entity:getWorldHitboxCentre()
	return self:getHitboxPointByRelativeCoord{0.5,0.5,0.5}
end

-- returns a point inside the entities hitbox, queried by an
-- argument coord with range 0.0 < coord.xyz < 1.0
-- coord = {0,0,0} would give the minimum point of the hitbox
-- coord = {1,1,1} would give the maximum point of the hitbox
-- coord = {0.5,0.5,0.5} would give the middle of the hitbox
-- etc.
--
function Entity:getHitboxPointByRelativeCoord(coord)
	local pos,size = self:getWorldHitboxPosSize()

	return {
		pos[1] + size[1]*coord[1],
		pos[2] + size[2]*coord[2],
		pos[3] + size[3]*coord[3]
	}
end

--function Entity:currentState()
--	return self.props.ent_current_state
--end

function Entity:getStateByName(name)
	if not name then return nil end

	local states = self.props.ent_states
	return states[name]
end

function Entity:getStateParent(state)
	if state then
		local parent_name = state.state_parent
		if parent_name then
			return self:getStateByName(parent_name)
		end
	end

	return nil
end

-- returns a command and the state it belongs to
function Entity:getCommand(command_name)
	local function traverse(state, recur)
		if not state then return nil, nil end

		local command = state.state_commands[command_name]
		if command then
			return command, state
		else
			local parent = self:getStateParent(state)
			return recur(parent, recur)
		end
	end

	for i,v in pairs(self.props.ent_current_states) do
		local found, state = traverse(v, traverse)
		if found then return found, state end
	end
	return nil, nil
end

function Entity:enableState(state)
	if state then
		if self:isStateEnabled(state) then
			print(string.format("Entity:changeState: tried to enter already enabled state"))
			return
		end

		local enter = state.state_enter
		table.insert(self.props.ent_current_states, state)
		if enter then
			enter(self, state)
		end
	else
		print(string.format("Entity:changeState: tried to enter non-existant state"))
	end
end

function Entity:enableStateByName(name)
	local state = self:getStateByName(name)
	if state then
		self:enableState(state)
	end
end

function Entity:disableState(state)
	if state then
		local enabled, index = self:isStateEnabled(state)
		if not enabled then
			print(string.format("Entity:changeState: tried to exit disabled state"))
			return
		end

		local exit = state.state_exit
		table.remove(self.props.ent_current_states, index)
		if exit then
			exit(self, state)
		end
	else
		print(string.format("Entity:changeState: tried to exit non-existant state"))
	end
end

function Entity:disableStateByName(name)
	local state = self:getStateByName(name)
	if state then
		self:disableState(state)
	end
end

-- returns true/false, and index of state in ent_current_states
function Entity:isStateEnabled(state)
	for i,v in pairs(self.props.ent_current_states) do
		if v == state then return true, i end
	end
	return false, nil
end

function Entity:toBeDeleted()
	return self.props.ent_delete_flag
end
function Entity:delete()
	self.props.ent_delete_flag = true
end

function Entity:callCommand(command_name, args)
	--local args = {...}
	prof.push("call_command")
	local command, state = self:getCommand(command_name)

	if not command then
		return
	end

	command(self, state, args)
	prof.pop("call_command")
end

function Entity:isModelAnimated()
	local model = self:getModel()
	if not model then return false end
	if not model:getAnimator() then return false end
	return true
end

function Entity:getAnimator()
	local model = self:getModel()
	if not model then return nil,nil end
	local anim1,anim2 = model:getAnimator()
	return anim1, anim2
end

function Entity:playAnimation(anim, time, speed, loop, callback)
	local anim1,anim2 = self:getAnimator()
	if not anim1 then
		error(string.format("Entity:playAnimation(): entity's \"%s\" model has no animators", self:getIdentifier())) end
	anim1:playAnimation(anim, time, speed, loop, callback)
	if anim2 then anim2:suspendAnimation() end
end

function Entity:playAnimationInterp(anim1, anim2, interp)
	local model = self:getModel()
	if not model then
		error(string.format("Entity:playAnimationInterp(): entity "%s" has no model", self:getIdentifier())) end
	local anim1,anim2 = self:getAnimator()
	if not (anim1 and anim2) then
		error(string.format("Entity:playAnimationInterp(): entity's \"%s\" model has no animators", self:getIdentifier())) end
	anim1:playAnimation(unpack(anim1))
	anim2:playAnimation(unpack(anim2))
	model.props.model_i_animator_interp = interp
end

function Entity:setAnimationInterp(interp)
	local model = self:getModel()
	if not model then
		error(string.format("Entity:setAnimationInterp(): entity "%s" has no model", self:getIdentifier())) end
	model.props.model_i_animator_interp = interp
end

function Entity:setAnimationSpeed(speed)
	local model = self:getModel()
	if not model then
		error(string.format("Entity:setAnimationSpeed(): entity "%s" has no model", self:getIdentifier())) end
	local anim1,anim2 = self:getAnimator()
	if not (anim1 and anim2) then
		error(string.format("Entity:setAnimationSpeed(): entity's \"%s\" model has no animators", self:getIdentifier())) end
	anim1:setSpeed(speed)
	anim2:setSpeed(speed)
end

function Entity:getAnimationByName(name)
	local model = self:getModel()
	if not model then
		error(string.format("Entity:getAnimationByName(): entity "%s" has no model", self:getIdentifier())) end
	return model.props.model_i_reference:getAnimation( name )
end

function Entity:setAnimationTime(time, which_animator)
	if not (which_animator == 1 or which_animator == 2) then
		error(string.format("Entity:setAnimationTime(): which_animator argument expected to be 1 or 2, got %s",
			tostring(which_animator), self:getIdentifier())) end
	local anim1, anim2 = self:getAnimator()

	if which_animator == 1 then
		anim1:setTime(time)
	else
		anim2:setTime(time)
	end
end

-- takes in established hooks from Prov:establishEntityHooks()
function Entity:addHook( hook )
	table.insert(self.props.ent_hooks, hook)
end

--function Entity:createHook( func )
--	local hook = Hook:new(func)
--	table.insert(self.props.ent_hooks, hook)
--end

function Entity:clearHooks()
	for i,hook in ipairs(self.props.ent_hooks) do
		hook:clear()
	end
end

function Entity:getHooksInfo()
	return self.props.ent_hooks_info
end

function Entity:stateFromPrototype(GameData, prototype)
	local state = prototype()

	local proto_update = state.state_update
	local proto_enter  = state.state_enter
	local proto_exit   = state.state_exit

	local proto_comms  = state.state_commands
	for i,v in pairs(proto_comms) do
		proto_comms[i] = v(GameData)
	end
	if state.state_update then state.state_update = state.state_update(GameData) end
	if state.state_enter  then state.state_enter = state.state_enter(GameData) end 
	if state.state_exit   then state.state_exit = state.state_exit(GameData) end

	return state
end

