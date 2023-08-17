--[[
-- __pairs and __next metamethods are not in 5.1
-- this adds that functionality
--]]
--

rawpairs = pairs
function pairs(t, ...)
	local m = getmetatable(t)
	local n = m and m.__pairs or rawpairs
	return n(t, ...)
end

rawipairs = ipairs
function ipairs(t, ...)
	local m = getmetatable(t)
	local n = m and m.__ipairs or rawipairs
	return n(t, ...)
end

rawnext = next
function next(t,k)
	local m = getmetatable(t)
	local n = m and m.__next or rawnext
	return n(t,k)
end
