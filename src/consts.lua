-- thanks lua reference guide :]
local function readOnly (t)
	local proxy = {}
	local mt = {       -- create metatable
		__index = t,
		__newindex = function (t,k,v)
			error("attempt to update a read-only table", 2)
		end
	}
	setmetatable(proxy, mt)
	return proxy
end

CONSTS = readOnly{
	TILE_SIZE = 24,
	TILE_HEIGHT = -16,

	BLOOM_CHAIN_LENGTH = 4,
	LIGHT_REDO_MATRIX_DELAY = 10,
	ATLAS_SIZE = 2048,

	MAX_DIR_LIGHTS = 1,
	MAX_POINT_LIGHTS = 9,
}
return CONSTS
