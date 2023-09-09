-- model "decorations" are models that can be attached to other models bones
-- main use is for attaching transparent meshes to heads for drawing animated faces
--

require "props.modelaccessoryprops"
local shadersend = require 'shadersend'
local cpml = require 'cpml'
local matrix = require 'matrix'

ModelDecor = {__type = "decor"}
ModelDecor.__index = ModelDecor

function ModelDecor:new(props)
	local this = {
		props = ModelDecorPropPrototype(props),

		recalc_model = true,
		local_model_u = nil
	}

	setmetatable(this,ModelDecor)

	return this
end

function ModelDecor:getLocalModelMatrix()
	-- decor objects are attached to another models bones, it's rare
	-- to ever need it's local position to change so we only calculate the local
	-- model matrix once
	if self.recalc_model then

		local props = self.props
		local pos = props.decor_position
		local rot = props.decor_rotation

		pos[4] = 0
		cpml.mat4.mul_vec4(pos, self:getModel():getDirectionFixingMatrix(), pos)

		local m = cpml.mat4():identity()

		m:scale(m,  cpml.vec3(unpack(props.decor_scale)))

		m:rotate(m, rot[1], cpml.vec3.unit_x)
		m:rotate(m, rot[2], cpml.vec3.unit_y)
		m:rotate(m, rot[3], cpml.vec3.unit_z)

		m:translate(m, cpml.vec3( pos[1], pos[2], pos[3] ))

		--m = m * self:getModel():getDirectionFixingMatrix() 

		self.local_model_u = m
		self.recalc_model = false
	end

	return self.local_model_u
end

-- returns model_u, normal_model_u to be used in shader
function ModelDecor:getGlobalModelMatrix(parent)
	local local_model_u = self:getLocalModelMatrix()

	local props = self.props
	local model_matrix = parent:queryModelMatrix()
	local bone_matrix  = parent:queryBoneMatrix(props.decor_parent_bone)
	local model_u = model_matrix * bone_matrix * local_model_u

	local norm_m = cpml.mat4.new()
	norm_m = norm_m:invert(model_u)
	norm_m = norm_m:transpose(model_u)

	return model_u, norm_m
end

function ModelDecor:getModel()
	return self.props.decor_reference
end

function ModelDecor:draw(parent, shader)
	local shader = shader or love.graphics.getShader()
	local model_u, norm_u = self:getGlobalModelMatrix(parent)

	shadersend(shader, "u_model", "column", matrix(model_u))
	shadersend(shader, "u_normal_model", "column", matrix(norm_u))
	shadersend(shader, "u_skinning", 0) -- bone matrix is preapplied by getGlobalModelMatrix, so disable skinning

	local mesh = self:getModel():getMesh()
	mesh:drawModel(shader)
end

function ModelDecor:name()
	return self.props.decor_name
end
