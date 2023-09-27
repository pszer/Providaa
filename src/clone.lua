--
-- 
--

local function __clone(dest, t, clone)
	for i,v in pairs(t) do
		local typ = provtype(v)
		if typ ~= "table" then
			dest[i] = v
		else
			dest[i] = {}
			clone(dest[i], v, clone)
		end
	end
	return dest
end

return function(t)
	return function()
		local clone = {}
		__clone(clone, t, __clone)
		return clone
	end
end
