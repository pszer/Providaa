--[[
-- utility function for a set
--]]

Set = {}
Set.__index = Set
Set.__type  = "set"

function Set:new()
	local s = {}
	setmetatable(s,Set)
	return s
end

function Set:Add(x)
	for _,v in ipairs(self) do
		if v == x then return end
	end
	table.insert(self, x)
end

function Set:RemoveByIndex(i)
	table.remove(self. i)
end

function Set:Remove(x)
	local i = self:Search(x)
	if i then
		table.remove(self, i)
	end
end

function Set:Search(x)
	for i,v in ipairs(self) do
		if v == x then
			return i
		end
	end
	return nil
end

function EqualTables(a,b)
	for i,v in pairs(a) do
		if a[i] ~= b[i] then
			return false
		end
	end

	for i,v in pairs(b) do
		if a[i] ~= b[i] then
			return false
		end
	end

	return true
end
