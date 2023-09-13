-- 
-- rotations in most contexts can be described by a vec3 pitch/yaw/roll or vec3 direction vector
--
-- rotations are stored as tables {a,b,c, "rotation"/"direction"}, with the 4th component showing
-- which type it is
-- 
-- these are functions for working with these dual-type rotation vectors
--
--

-- casts a rotation vector to a rotation type
function toRotationVector(vec)
	if vec[4] == "rotation" then
		return vec
	else
		-- things
	end
end

function toDirectionVector(vec)
	if vec[4] == "rotation" then
		return vec
	else
		-- things
	end
end

-- if the input is nil, it returns the fallback direction vector
-- of {0,0,-1,"direction"}
function nonNilDirection(vec)
	if vec[4] == "rotation" then
		return vec
	end

	if vec[1]==0 and vec[2]==0 and vec[3]==0 then
		local d = {0,0,-1,"direction"}
		return d
	end
	return vec
end

local cpml = require 'cpml'
function rotateMatrix(mat, vec)
	if vec[4] == "rotation" then
		mat:rotate(m, rot[1], cpml.vec3.unit_x)
		mat:rotate(m, rot[2], cpml.vec3.unit_y)
		mat:rotate(m, rot[3], cpml.vec3.unit_z)
		return mat
	else
		local vec = nonNilDirection(vec)

		local vec3 = cpml.vec3.new
		local look = cpml.mat4.new(1)
		local look = cpml.mat4.look_at(
			look,
			vec3(0,0,0),
			vec3(vec[1],vec[2],vec[3]),
			vec3(0,1,0)
		)

		cpml.mat4.mul(mat, look, mat)
		return mat
	end
end
