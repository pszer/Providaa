require "props.entityprops"
require "event"

Entity = {__type = "entity"}
Entity.__index = Entity

function Entity:new(props)
	local this = {
		props = EntityPropPrototype(props),

		ent_moved = true
	}

	setmetatable(this,Entity)

	return this
end

-- this function should not be treated as a virtual function to overwrite
-- let it do what its gotta do
function Entity:update()
	self:updateModelPosition()
	self.ent_moved = false
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

function Entity:setPosition(pos)
	local v = self.props.ent_position
	if pos[1]~=v[1]or pos[2]~=v[2] or pos[3]~=v[3] then
		self.props.ent_position = pos
		self.ent_moved = true
	end
end
function Entity:setRotation(rot)
	local r = self.props.ent_rotation
	if rot[1]~=r[1] or rot[2]~=r[2] or rot[3]~=r[3] or rot[4] ~= r[4] then
		self.props.ent_rotation = rot
		--self.ent_moved = true
	end
end
function Entity:setScale(scale)
	local s = self.props.ent_scale
	if scale[1]~=s[1] or scale[2]~=s[2] or scale[3]~=s[3] then
		self.props.ent_scale = scale
		--self.model_moved = true
	end
end

-- returns x,y,z, dx,dy,dz
function Entity:getWorldHitbox()
	local pos = self:getPosition()
	local hitbox_pos = self.props.ent_hitbox_position
	local hitbox_size = self.props.ent_hitbox_size

	return pos[1] + hitbox_pos[1],
	       pos[2] + hitbox_pos[2],
	       pos[3] + hitbox_pos[3],
		   hitbox_size[1],
		   hitbox_size[2],
		   hitbox_size[3]
end

function Entity:getWorldHitboxCentre()
	local x,y,z,dx,dy,dz = self:getWorldHitbox()
	return x+dx*0.5,
	       y+dy*0.5,
	       z+dz*0.5
end

function Entity:currentState()
	return self.props.ent_current_state
end

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

function Entity:getCommand(command_name)
	local function traverse(state, recur)
		if not state then return nil end

		local command = state.state_commands[command_name]
		if command then
			return command
		else
			local parent = self:getStateParent(state)
			return recur(parent, recur)
		end
	end

	for i,v in pairs(self.props.ent_current_states) do
		local found = traverse(v, traverse)
		if found then return found end
	end
	return nil
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
			enter(self)
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
			exit(self)
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

function Entity:callCommand(command_name, ...)
	local args = {...}
	local command = self:getCommand(command_name)

	if not command then
		return
	end

	command(self, unpack(args))
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
