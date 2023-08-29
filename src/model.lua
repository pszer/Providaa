local iqm = require 'iqm-exm'
local cpml = require 'cpml'
local matrix = require 'matrix'

require "props.modelprops"
require "texture"

Model = {__type = "model"}
Model.__index = Model

function Model:new(props)
	local this = {
		props = ModelPropPrototype(props),

		bone_hierarchy = {} -- for use internally
	}

	setmetatable(this,Model)

	return this
end

function Model.openFilename(fname, texture_fname, load_anims)
	local fpath = "models/" .. fname

	local objs = Model.readIQM(fpath)

	local texture = Textures.loadTexture(texture_fname)

	print("whats in the model")
	for i,v in pairs(objs) do
		print(i, v)
	end

	for i,v in pairs(objs.mesh:getVertexFormat()) do
		print(i, v[1], v[2], v[3])
	end

	for i = 1,objs.mesh:getVertexCount() do
		x,y,z,w = objs.mesh:getVertexAttribute(i, 5)
		x2,y2,z2,w2 = objs.mesh:getVertexAttribute(i, 6)
		print(x,y,z,w)
	end

	local mesh = Mesh.newFromMesh(objs.mesh, texture)
	local anims = nil
	local skeleton = nil
	local has_anims = false

	if load_anims and objs.has_anims then
		anims = Model.openAnimations(fname)
		skeleton = anims.skeleton
		has_anims = true
	end

	return Model:new{
		["model_name"] = fname,
		["model_mesh"] = mesh,
		["model_animations"] = anims,
		["model_skeleton"] = skeleton,
		["model_animated"] = has_anims
	}
end

function Model.openAnimations(fname)
	print("openAnimations")
	local fpath = "models/" .. fname

	local anims = Model.readIQMAnimations(fpath)

	for i,v in pairs(anims) do
		print(i, v)
	end

	print()
	for i,v in pairs(anims[1]) do
		print(i, v)
	end

	print()
	for i,v in pairs(anims[2]) do
		print(i, v)
	end

	--[[
	print()
	print("wooop")
	for i,v in pairs(anims.frames) do
		print("frame ", i)
		for j,u in pairs(v) do
			print("joint",j,u)
			for k,p in pairs(u) do
				print("   ",k,p)
			end
		end
	end

	print("skeleton")
	for i,v in pairs(anims.skeleton) do
		print(i,v)

		for j,p in pairs(v) do
			print(" ",j,p)
		end
	end--]]

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

function Model:modelMatrix()
	local props = self.props
	local pos = props.model_position

	local m = cpml.mat4():identity()
	m:rotate(m, props.model_rotation[1], cpml.vec3.unit_x)
	m:rotate(m, props.model_rotation[2], cpml.vec3.unit_y)
	m:rotate(m, props.model_rotation[3], cpml.vec3.unit_z)
	m:translate(m, cpml.vec3(pos.x, pos.y, pos.z))
	return m
end

function Model:sendAnimation(shader, animation)
	shader = shader or love.graphics.getShader()

	if not self.props.model_animated then
		shader:send("u_skinning", 0)
	else
		shader:send("u_skinning", 1)

		local matrices = self:calculateBoneMatrices(unpack(animation))
		shader:send("u_bone_matrices", unpack(matrices))
	end
end

function Model:draw(shader)
	shader = shader or love.graphics.getShader()

	shader:send("u_model", "column", matrix(self:modelMatrix()))
	self:sendAnimation(shader, {alekin.props.model_animations["Walk"], getTick(), 0.0})


	self.props.model_mesh:drawModel(shader)
end

function Model:generateBoneOffsetMatrices()
	local skeleton = self.props.model_skeleton

	for bone_id,bone in ipairs(skeleton) do
		local position_v = bone.position
		local rotation_q = bone.rotation
		local scale_v = bone.scale

		local bone_pos_v = cpml.vec3.new(position_v.x, position_v.y, position_v.z)
		local bone_rot_q = cpml.quat.new(rotation_q.x, rotation_q.y, rotation_q.z, rotation_q.w)
		local bone_scale_v = cpml.vec3.new(scale_v.x, scale_v.y, scale_v.z)

		local rotation_u = cpml.mat4.from_quaternion( bone_rot_q )
		local position_u = cpml.mat4.new(1)
		local scale_u    = cpml.mat4.new(1)

		position_u:translate(position_u, bone_pos_v)
		scale_u:scale(scale_u, bone_scale_v)

		local matrix = scale_u * rotation_u * position_u
		bone.offset = matrix
	end
end

function Model:calculateBoneMatrices(animation, frame, interp_value)
	local bone_matrices = {}
	local final_bone_matrices = {}
	local skeleton = self.props.model_skeleton
	interp_value = interp_value or 0

	if (not skeleton) or (not animation) then return end

	local anim_start = animation.first
	local anim_end = animation.last
	--local anim_loop = animation.loop
	local anim_loop = true
	local anim_length = anim_end - anim_start

	local frame_id = 0
	local nextframe_id = 0
	if anim_loop then
		frame_id = anim_start + (frame-1) % anim_length
		nextframe_id = anim_start + (frame) % anim_length
	else
		if frame >= anim_length then
			frame_id = anim_end
			nextframe_id = anim_end
		else
			frame_id = anim_start + (frame-1)
			nextframe_id = anim_start + (frame)
		end
	end

	anim_joints = self.props.model_animations.frames[frame_id]
	nextanim_joints = self.props.model_animations.frames[nextframe_id]
	
	local calc_bone = function(bone_id, func)

		if bone_matrices[bone_id] then return end
		
		local bone = skeleton[bone_id]
		local anim1 = anim_joints[bone_id]
		local anim2 = nextanim_joints[bone_id]

		local anim_pos_v1 = cpml.vec3.new(anim1.translate.x, anim1.translate.y, anim1.translate.z)
		--local anim_pos_v2 = cpml.vec3.new(anim2.position.x, anim2.position.y, anim2.position.z)
		--

		local anim_rot_q1 = cpml.quat.new(anim1.rotate.x, anim1.rotate.y, anim1.rotate.z, anim1.rotate.w )
		--local anim_rot_q2 = cpml.quat.new(anim2.rotate.x, anim2.rotate.y, anim2.rotate.z, anim2.rotate.w  )

		local anim_scale_v1 = cpml.vec3.new(anim1.scale.x, anim1.scale.y, anim1.scale.z)
		--local anim_scale_v2 = cpml.vec3.new(anim2.scale.x, anim2.scale.y, anim2.scale.z)
		--
		--

		-- TODO implement interpolation
		local f_anim_pos_v = anim_pos_v1
		local f_anim_rot_q = anim_rot_q1
		local f_anim_scale_v = anim_scale_v1

		local anim_rotation_u = nil
		local anim_position_u = cpml.mat4.new(1)
		local anim_scale_u    = cpml.mat4.new(1)

		anim_rotation_u = cpml.mat4.from_quaternion( cpml.quat(f_anim_rot_q.x, f_anim_rot_q.y, f_anim_rot_q.z, f_anim_rot_q.w) )
		anim_position_u:translate(anim_position_u, f_anim_pos_v)
		anim_scale_u:scale(anim_scale_u, f_anim_scale_v)

		local bone_offset_u = bone.offset

		local final_u = anim_scale_u * anim_rotation_u * anim_position_u


		-- if root
		if not bone.parent or bone.parent < 1 then
			bone_matrices[bone_id] = final_u
			final_bone_matrices[bone_id] = final_u * bone_offset_u
		else
			func(bone.parent, func)
			bone_matrices[bone_id] = final_u * bone_matrices[bone.parent]
			final_bone_matrices[bone_id] = final_u * bone_matrices[bone.parent] * bone_offset_u
		end

	end

	for i,v in ipairs(skeleton) do
		calc_bone(i, calc_bone)
	end

	return final_bone_matrices
end
