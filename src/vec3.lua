-- some vec3 utilities
--
--

require 'math'

function normaliseVec3( vec )
	local dist = vec[1]*vec[1] +
	             vec[2]*vec[2] +
	             vec[3]*vec[3]
	
	if dist == 0 then return v end
	dist = 1/math.sqrt(dist)

	vec[1] = vec[1] * dist
	vec[2] = vec[2] * dist
	vec[3] = vec[3] * dist
	return vec
end
