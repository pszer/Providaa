local cpml = require 'cpml'

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
	local rot_v   = rot or {0,0,0}
	local scale_v = scale or {1,1,1}
	if type(scale) == "number" then
		scale_v = {scale, scale, scale}
	end

	return {
		position = pos_v,
		rotation = rot_v,
		scale    = scale_v
	}
end

-- alias
INSTANCE = ModelInfo.new

function ModelInfo.newMeshFromInfoTable(model, instances)
	local verts = {}
	for i,instance in ipairs(instances) do
		local vertex = {}

		local m = cpml.mat4.new(1)

		m:scale(m,  cpml.vec3(instance.scale))

		m:rotate(m, instance.rotation[1], cpml.vec3.unit_x)
		m:rotate(m, instance.rotation[2], cpml.vec3.unit_y)
		m:rotate(m, instance.rotation[3], cpml.vec3.unit_z)

		m:translate(m, cpml.vec3( instance.position ))

		m = m * model:getDirectionFixingMatrix()

		for i=1,16 do
			vertex[i] = m[i]
		end

		verts[i] = vertex
	end

	return love.graphics.newMesh(ModelInfo.atypes, verts, nil, "static")
end