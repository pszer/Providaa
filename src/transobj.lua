--
--

local TransObj = {}
TransObj.__index = TransObj

function TransObj:new(pos,dir,scale)
	function s_clone(dest,t)
		for i,v in ipairs(t) do
			dest[i] = v
		end
	end

	local this = {
		position = {},
		rotation = {},
		scale    = {}
	}
	s_clone(this.position, pos)
	s_clone(this.rotation, dir)
	s_clone(this.scale, scale)
	setmetatable(this, TransObj)

	return this
end

-- assumes that the object has
-- getPosition()
-- getRotation()
-- getScale()
-- functions
function TransObj:from(obj)
	local pos,rot,scale=obj:getPosition(),obj:getRotation(),obj:getScale()
	return TransObj:new(pos,rot,scale)
end

return TransObj
