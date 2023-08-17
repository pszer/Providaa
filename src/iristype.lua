--[[
-- extends the type function of lua to include types in the game
--
-- types can be specified in the __type field of a metatable
--
--]]
--

function iristype(x)
	local t = type(x)
	if t ~= "table" then
		return t
	end
	local mt = getmetatable(x)

	if mt then
		local typemt = mt.__type
		if typemt == nil then
			return t
		elseif type(typemt) == "function" then
			return typemt(x)
		elseif type(mt) == "table" then
			if mt.__type then
				return mt.__type
			end
			return iristype(mt)
		else
			return typemt
		end
	else
		return t
	end
end
