local cpml = require 'cpml'

require "rotation"

ModelInfo = {__type = "modelinfo",
             atypes = {
               {"InstanceColumn1", "float", 4},
               {"InstanceColumn2", "float", 4},
               {"InstanceColumn3", "float", 4},
               {"InstanceColumn4", "float", 4}},
			 atypes_map = {
				["InstanceColumn1"] = 1,
				["InstanceColumn2"] = 1,
				["InstanceColumn3"] = 1,
				["InstanceColumn4"] = 1
			 }
			}
ModelInfo.__index = ModelInfo

-- returns a table with position, rotation and scale information
-- for a model copy instance
-- rot and scale are optional arguments, defaulting to no rotation and no scaling
-- scale can be a single number that acts as a scalar scaling in all directions
function ModelInfo.new(pos, rot, scale) 
	local pos_v   = pos or {0,0,0}
	local rot_v   = rot or {0,0,0,"rot"}
	local scale_v = scale or {1,1,1}
	if type(scale) == "number" then
		scale_v = {scale, scale, scale}
	end

	local p = {
		position = pos_v,
		rotation = rot_v,
		scale    = scale_v,
	}
	setmetatable(p, ModelInfo)
	return p
end

function ModelInfo.newFromMatrix(mat)
	local p = {
		position = nil,
		rotation = nil,
		scale    = nil,
		matrix   = mat
	}
	setmetatable(p, ModelInfo)
	return p
end

-- alias
INSTANCE = ModelInfo.new

local __tempmat4 = cpml.mat4.new()
local __tempid = cpml.mat4.new(1)
function ModelInfo.newMeshFromInfoTable(model, instances)
	local verts = {}
	local mat4mul = cpml.mat4.mul
	for i,instance in ipairs(instances) do
		local vertex = {}

		if instance.matrix then
			local m = __tempmat4
			for i=1,16 do
				m[i] = instance.matrix[i]
			end
			mat4mul(m,m,model:getDirectionFixingMatrix())
			for i=1,16 do
				vertex[i] = m[i]
			end
		else
			local m = __tempmat4
			for i=1,16 do
				m[i] = __tempid[i]
			end

			m:scale(m,  cpml.vec3(instance.scale))

			rotateMatrix(m, instance.rotation)

			m:translate(m, cpml.vec3( instance.position ))

			mat4mul(m,m,model:getDirectionFixingMatrix())

			for i=1,16 do
				vertex[i] = m[i]
			end
		end

		verts[i] = vertex
	end

	return love.graphics.newMesh(ModelInfo.atypes, verts, nil, "static")
end
