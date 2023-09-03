local iqm = require 'iqm-exm'
local cpml = require 'cpml'
local matrix = require 'matrix'
local shadersend = require 'shadersend'

require "props.modelprops"
require "texturemanager"

Model = {__type = "model"}
Model.__index = Model

function Model:new(props)
	local this = {
		props = ModelPropPrototype(props),

		baseframe = {},
		inversebaseframe = {},
		frames = {},
		outframes = {},

		dir_matrix = nil,
		static_model_matrix = nil,
		static_normal_matrix = nil,

		--bone_matrices = {}
	}

	setmetatable(this,Model)

	return this
end

ModelInstance = {__type = "modelinstance"}
ModelInstance.__index = ModelInstance

function ModelInstance:new(props)
	local this = {
		props = ModelInstancePropPrototype(props),

		static_model_matrix = nil,
		static_normal_matrix = nil,

		bone_matrices = {}
	}

	setmetatable(this,ModelInstance)

	return this
end

function ModelInstance:newInstance(model, props)
	local props = props or {}
	props.model_i_reference = model
	return ModelInstance:new(props)
end

function ModelInstance:modelMatrix()
	local is_static = self.props.model_i_static
	if is_static and self.static_model_matrix then
		return self.static_model_matrix, self.static_normal_matrix
	end

	local props = self.props
	local pos = props.model_i_position
	local rot = props.model_i_rotation

	local m = cpml.mat4():identity()

	m:scale(m,  cpml.vec3(unpack(props.model_i_scale)))

	m:rotate(m, rot[1], cpml.vec3.unit_x)
	m:rotate(m, rot[2], cpml.vec3.unit_y)
	m:rotate(m, rot[3], cpml.vec3.unit_z)

	m:translate(m, cpml.vec3( pos[1], pos[2], pos[3] ))

	m = m * props.model_i_reference:getDirectionFixingMatrix() 

	local norm_m = cpml.mat4.new()
	norm_m = norm_m:invert(m)
	norm_m = norm_m:transpose(norm_m)

	self.static_model_matrix = m
	self.static_normal_matrix = norm_m

	return m, norm_m
end

function ModelInstance:getModel()
	return self.props.model_i_reference
end

function ModelInstance:fillOutBoneMatrices(animation, frame)
	local model = self:getModel()
	if model.props.model_animated then
		local bone_matrices = model:getBoneMatrices(animation, frame)

		for i,v in ipairs(bone_matrices) do
			bone_matrices[i] = matrix(v)
		end

		self.bone_matrices = bone_matrices
	end
end

function ModelInstance:sendBoneMatrices(shader)
	local model = self:getModel()
	if not model.props.model_animated then
		shadersend(shader, "u_skinning", 0)
	else
		shadersend(shader, "u_skinning", 1)
		shadersend(shader, "u_bone_matrices", "column", unpack(self.bone_matrices))
	end
end

function ModelInstance:sendToShader(shader)
	local shader = shader or love.graphics.getShader()

	local model_u, normal_u = self:modelMatrix()
	shadersend(shader, "u_model", "column", matrix(model_u))
	shadersend(shader, "u_normal_model", "column", matrix(normal_u))

	self:sendBoneMatrices(shader)
end

function ModelInstance:draw(shader, update_animation)
	local shader = shader or love.graphics.getShader()

	if update_animation then
		self:fillOutBoneMatrices("Walk", getTickSmooth())
	end

	self:sendToShader(shader)

	local model = self:getModel()
	love.graphics.setFrontFaceWinding(model.props.model_vertex_winding)
	model.props.model_mesh:drawModel(shader)
	love.graphics.setFrontFaceWinding("ccw")
end

function Model:generateDirectionFixingMatrix()
	local up_v = cpml.vec3(self.props.model_up_vector)
	local dir_v = cpml.vec3(self.props.model_dir_vector)
	local mat = cpml.mat4.from_direction(up_v, dir_v)
	self.dir_matrix = mat
end

function Model:getDirectionFixingMatrix()
	if not self.dir_matrix then self:generateDirectionFixingMatrix() end
	return self.dir_matrix
end

function Model:getSkeleton()
	return self.props.model_skeleton
end

function Model:generateBaseFrames()
	local skeleton = self:getSkeleton()

	for bone_id,bone in ipairs(skeleton) do
		local position_v = bone.position
		local rotation_q = bone.rotation
		local scale_v = bone.scale

		local bone_pos_v = cpml.vec3.new(position_v.x, position_v.y, position_v.z)
		local bone_rot_q = cpml.quat.new(rotation_q.x, rotation_q.y, rotation_q.z, rotation_q.w)
		bone_rot_q = bone_rot_q:normalize()
		local bone_scale_v = cpml.vec3.new(scale_v.x, scale_v.y, scale_v.z)

		local rotation_u = cpml.mat4.from_quaternion( bone_rot_q )
		local position_u = cpml.mat4.new(1)
		local scale_u    = cpml.mat4.new(1)

		position_u:translate(position_u, bone_pos_v)
		scale_u:scale(scale_u, bone_scale_v)

		local matrix = position_u * rotation_u * scale_u
		local invmatrix = cpml.mat4():invert(matrix)

		self.baseframe[bone_id] = matrix
		self.inversebaseframe[bone_id] = invmatrix

		if bone.parent > 0 then -- if bone has a parent
			self.baseframe[bone_id] = self.baseframe[bone.parent] * self.baseframe[bone_id]
			self.inversebaseframe[bone_id] = self.inversebaseframe[bone_id] * self.inversebaseframe[bone.parent]
		end

		bone.offset = matrix
	end
end

function Model:generateAnimationFrames()
	for frame_i, frame in ipairs(self.props.model_animations.frames) do
		self.frames[frame_i] = {}
		local output_frames = self.frames[frame_i]

		for pose_i, pose in ipairs(frame) do
			
			local position = pose.translate
			local rotation = pose.rotate
			local scale = pose.scale

			local pos_v = cpml.vec3.new(position.x, position.y, position.z)
			local rot_q = cpml.quat.new(rotation.x, rotation.y, rotation.z, rotation.w)
			rot_q = rot_q:normalize()
			local scale_v = cpml.vec3.new(scale.x, scale.y, scale.z)

			local position_u = cpml.mat4.new(1)
			local rotation_u = cpml.mat4.from_quaternion( rot_q )
			local scale_u    = cpml.mat4.new(1)

			position_u:translate(position_u, pos_v)
			scale_u:scale(scale_u, scale_v)

			--local matrix = scale_u * rotation_u * position_u
			local matrix = position_u * rotation_u * scale_u
			local invmatrix = cpml.mat4():invert(matrix)

			local bone = self:getSkeleton()[pose_i]

			if bone.parent > 0 then -- if bone has a parent
				output_frames[pose_i] = self.baseframe[bone.parent] * matrix * self.inversebaseframe[pose_i]
			else
				output_frames[pose_i] = matrix * self.inversebaseframe[pose_i]
			end
		end
	end
end

function Model:getBoneMatrices(animation, frame)
	if not self.props.model_animated then return end

	local anim_data   = self.props.model_animations[animation]
	local anim_first  = anim_data.first
	local anim_last   = anim_data.last
	local anim_length = anim_last - anim_first
	local anim_rate   = anim_data.framerate

	local frame_fitted = frame * anim_rate / tickRate()
	local frame_floor  = math.floor(frame_fitted)
	local frame_interp = frame_fitted - frame_floor

	local frame1_id = anim_first + (frame_floor-1) % anim_length
	local frame2_id = anim_first + (frame_floor) % anim_length

	local skeleton = self:getSkeleton()

	local outframe = self.outframes
	for i,pose1 in pairs(self.frames[frame1_id]) do
		pose2 = self.frames[frame2_id][i]

		local pose_interp = {}

		for i,v in ipairs(pose1) do
			pose_interp[i] =
			 (1-frame_interp)*pose1[i] + frame_interp*pose2[i]
		end

		local mat = cpml.mat4.new(pose_interp)

		local parent_i = skeleton[i].parent
		if parent_i > 0 then
			outframe[i] = outframe[parent_i] * mat
		else
			outframe[i] = mat
		end
	end

	return outframe
end


