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

		bone_matrices = {}
	}

	setmetatable(this,Model)

	return this
end

function Model.openFilename(fname, texture_fname, load_anims)
	local fpath = "models/" .. fname

	local objs = Model.readIQM(fpath)

	local texture = Textures.loadTexture(texture_fname)

	local mesh = Mesh.newFromMesh(objs.mesh, texture)
	local anims = nil
	local skeleton = nil
	local has_anims = false

	if load_anims and objs.has_anims then
		anims = Model.openAnimations(fname)
		skeleton = anims.skeleton
		has_anims = true
	end

	local model = Model:new{
		["model_name"] = fname,
		["model_mesh"] = mesh,
		["model_skeleton"] = skeleton,
		["model_animations"] = anims,
		["model_animated"] = has_anims
	}

	if load_anims and objs.has_anims then
		model:generateBaseFrames()
		model:generateAnimationFrames()
	end

	model:generateDirectionFixingMatrix()

	return model
end

function Model.openAnimations(fname)
	print("openAnimations")
	local fpath = "models/" .. fname
	local anims = Model.readIQMAnimations(fpath)
	return anims
end

function Model.readIQM(fname)
	local finfo = love.filesystem.getInfo(fname)
	if not finfo or finfo.type ~= "file" then return nil end

	local objs = iqm.load(fname)
	if not objs then return nil end

	return objs
end

function Model.readIQMAnimations(fname)
	local finfo = love.filesystem.getInfo(fname)
	if not finfo or finfo.type ~= "file" then return nil end

	local anims = iqm.load_anims(fname)
	if not anims then return nil end

	return anims
end

function Model:generateDirectionFixingMatrix()
	local up_v = cpml.vec3(self.props.model_up_vector)
	local dir_v = cpml.vec3(self.props.model_dir_vector)
	local mat = cpml.mat4.from_direction(up_v, dir_v)
	self.dir_matrix = mat
end

-- calculates returns model matrix and the model for normal vector transformation
-- if model is static this function calculates once and re-uses
function Model:modelMatrix()
	local is_static = self.props.model_static
	if is_static and self.static_model_matrix then
		return self.static_model_matrix, self.static_normal_matrix
	end

	local props = self.props
	local pos = props.model_position

	local m = cpml.mat4():identity()
	m = m * self.dir_matrix
	m:scale(m,  cpml.vec3(unpack(props.model_scale)))
	m:rotate(m, props.model_rotation[1], cpml.vec3.unit_x)
	m:rotate(m, props.model_rotation[2], cpml.vec3.unit_y)
	m:rotate(m, props.model_rotation[3], cpml.vec3.unit_z)
	m:translate(m, cpml.vec3( pos[1], pos[2], pos[3]))

	-- the xyz 3x3 section of the model matrix
	norm_m = cpml.mat4.new(m[1],m[2],m[3], m[5],m[6],m[7], m[9],m[10],m[11])

	norm_m = norm_m:invert(norm_m)
	norm_m = norm_m:transpose(norm_m)

	self.static_model_matrix = m
	self.static_normal_matrix = norm_m

	return m, norm_m
end

function Model:fillOutBoneMatrices(animation, frame)
	if self.props.model_animated then
		local bone_matrices = self:getBoneMatrices(animation, frame)

		for i,v in ipairs(bone_matrices) do
			bone_matrices[i] = matrix(v)
		end

		self.bone_matrices = bone_matrices
	end
end

-- called after fillOutBoneMatrices()
function Model:sendBoneMatrices(shader)
	if not self.props.model_animated then
		shadersend(shader, "u_skinning", 0)
	else
		shadersend(shader, "u_skinning", 1)
		shadersend(shader, "u_bone_matrices", "column", unpack(self.bone_matrices))
	end
end

function Model:getSkeleton()
	return self.props.model_skeleton
end

function Model:sendToShader(shader)
	shader = shader or love.graphics.getShader()

	local model_u, normal_u = self:modelMatrix()
	shadersend(shader, "u_model", "column", matrix(model_u))
	shadersend(shader, "u_normal_model", "column", matrix(normal_u))

	self:sendBoneMatrices(shader)
end

function Model:draw(shader, update_animation)
	shader = shader or love.graphics.getShader()

	if update_animation then
		self:fillOutBoneMatrices("Walk", getTickSmooth())
	end

	self:sendToShader()

	self.props.model_mesh:drawModel(shader)
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

	--TODO add interpolation
	local outframe = self.outframes
	for i,pose1 in pairs(self.frames[frame1_id]) do
		pose2 = self.frames[frame2_id][i]

		local pose_interp = {}

		for i,v in ipairs(pose1) do
			pose_interp[i] =
			 (1-frame_interp)*pose1[i] + frame_interp*pose2[i]
		end

		--local mat = pose1 -- interp here <---- DO IT
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


