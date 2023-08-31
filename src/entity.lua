require "props.entityprops"

Entity = {__type = "Entity"}
Entity.__index = Entity

function Entity:new(props)
	local this = {
		props = EntityPropPrototype(props),
	}

	setmetatable(this,Scene)

	return this
end
