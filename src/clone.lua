return function(t)
	return function()
		local clone = {}
		for i,v in pairs(t) do
			clone[i]=v
		end
		return clone
	end
end
