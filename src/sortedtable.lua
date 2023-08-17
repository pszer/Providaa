--[[
-- Provides functionality for a sorted table
-- Entries are inserted, removed and searched for
-- using a fast binary search
--
-- Use
-- s = SortedTable:new(lessthan, equality) - creates a new sorted table with a less than operator for order
--                                         - and an equality operator used to specify what to search for
--                                         - in Search
-- s:Add(x)    - adds x to the sorted table
-- s:Remove(i) - removes entry at index i
-- i,entry = s:Search(x) - finds entry x in table and returns it's index as well as the entry
--                         if entry doesn't exist it returns nil,nil
--
--]]

require 'table'
require 'math'

require "pairs"

SortedTable = {}
SortedTable.__index = SortedTable
SortedTable.__pairs = function (t)
	return pairs(t.__entries)
end
SortedTable.__ipairs = function (t)
	return ipairs(t.__entries)
end

-- Creates a sorted table, a less than operator
-- is required to specify order and an equality operator
-- used for searching
function SortedTable:new(lessthan, equality)
	local t = {
		__entries = {},
		__lessthan = lessthan,
		__equality = equality,
		__length = 0
	}
	setmetatable(t, SortedTable)
	return t
end

function SortedTable:Add(x)
	local l, r, m = 1, self.__length+1, 1

	while l < r do
		m = math.floor((l+r)/2)
		local at_m = self.__entries[m]
		if self.__lessthan(at_m, x) then
			l = m+1
		else
			r = m
		end
	end

	table.insert(self.__entries, l, x)
	self.__length = self.__length + 1
end

function SortedTable:Remove(index)
	table.remove(self.__entries, index)
	self.__length = self.__length - 1
end

function SortedTable:Search(x)
	local l, r, m = 1, self.__length, 1

	while l <= r do
		m = math.floor((l+r)/2)
		local at_m = self.__entries[m]

		if self.__equality(at_m, x) then
			return m, at_m
		elseif self.__lessthan(at_m, x) then
			l = m+1
		else
			r = m-1
		end
	end

	local at_l = self.__entries[l]
	if self.__equality(l, x) then
		return at_l, l
	else
		return nil, nil
	end
end

-- inserts sorted table b into self
function SortedTable:Merge(b)
	local i, j = 1, 1

	while j <= b.__length do
		if i > self.__length or not self.__lessthan(self.__entries[i], b.__entries[j]) then
			table.insert(self.__entries, i, b.__entries[j])
			i = i + 1
			j = j + 1
			self.__length = self.__length + 1
		else
			i = i + 1
		end
	end
end

function CombineSortedTable(a,b)
	local result = SortedTable:new()

	local i, j, k = 1, 1, 1
	local an = a.__length
	local bn = b.__length

	while k < an + bn do
		if i > an then
			result.__entries[k] = b.__entries[j]
			j = j + 1
		elseif j > an then
			result.__entries[k] = a.__entries[i]
			i = i + 1
		elseif a.__lessthan(b.__entries[j], a.__entries[i]) then
			result.__entries[k] = b.__entries[j]
			j = j + 1
		else
			result.__entries[k] = a.__entries[i]
			i = i + 1
		end

		k = k + 1
	end

	result.__length = an + bn
	return result
end
