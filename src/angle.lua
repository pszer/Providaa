--
-- functions for working with angles&radians
--

require "math"

local pi = math.pi
local pi2 = 2.0 * math.pi

-- expects inputs in range 0-2pi
function slerpRadians(r1, r2, t)
	if r1 > r2 then
		-- return slerpRadians(r2, r1, 1.0-t)
		--
		-- inline:]
		local t = 1.0-t
		local _r = r1
		local r1 = r2
		local r2 = _r
		local delta = r2 - r1
		if delta < pi then
			return r1 * (1.0-t)  + r2 * t
		else
			local diff = (pi2 - r2) + r1
			local a = r2 + diff * (1.0 - t)
			if a > pi2 then a = a - pi2 end
			return a
		end
	end

	-- from now on r1 < r2 
	local delta = r2 - r1
	if delta < pi then
		return r1 * (1.0-t)  + r2 * t
	else
		local diff = (pi2 - r2) + r1
		local a = r2 + diff * (1.0 - t)
		if a > pi2 then a = a - pi2 end
		return a
	end
end

local atan = math.atan
-- ive had some wierd behaviour with lua's atan before
function atan3(a,b)
	local angle
	if a == 0 and b == -1 then
		angle = pi 
	else
		angle = atan(a, b) * 2 + pi2 + 0.01
		if angle > pi2 then angle = angle - pi2 end
	end
	return angle
end
