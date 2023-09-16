local iqm = require 'iqm-exm'
local cpml = require 'cpml'
local matrix = require 'matrix'
local shadersend = require 'shadersend'

require "cfg.gfx"
require "props.modelprops"
require "modelinstancing"
require "modelaccessory"
require "texturemanager"
require "rotation"

Model = {__type = "model"}
Model.__index = Model

function Model:new(props)
	local this = {
		props = ModelPropPrototype(props),

		-- internally used
		baseframe = {},
		inversebaseframe = {},
		frames = {},
		--outframes = {},

		--outframes_buffer = {},
		--outframes_buffer_allocated = false,

		dir_matrix = nil,
		outframes_allocated = false,
		--static_model_matrix = nil,
		--static_normal_matrix = nil,
		bounds_corrected = false -- has the bounding box been corrected by the direction fixing matrix?

		--bone_matrices = {}
	}

	setmetatable(this,Model)

	--[[local mat4new = cpml.mat4.new()
	local joint_count = this:getSkeletonJointCount()
	for i=1,joint_count do
		this.outframes_buffer = mat4new()
	end--]]

	return this
end

function Model:getMesh()
	return self.props.model_mesh
end

ModelInstance = {__type = "modelinstance"}
ModelInstance.__index = ModelInstance

--[[
--
--
-- ModelInstance
--
--
--]]

function ModelInstance:new(props)
	local this = {
		props = ModelInstancePropPrototype(props),

		static_model_matrix = nil,
		static_normal_matrix = nil,

		bone_matrices = {},

		model_moved = true,
		--update_bones = periodicUpdate(1),

		-- a flag that signals that this model has moved, so anything
		-- that uses its bounding box needs to be recalculated i.e.
		-- the space partitioning used for view culling
		recalculate_bounds_flag = false
	}

	setmetatable(this,ModelInstance)

	this:fillOutBoneMatrices(nil, 0)

	--local id = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
	--local function id_table() local t={} for i=1,16 do t[i]=id[i] end return t end
	this.static_model_matrix = cpml.mat4.new()
	this.static_normal_matrix = cpml.mat4.new()

	local a = {0,0,0}
	local b = {0,0,0}
	this.props.model_i_bounding_box.min = a
	this.props.model_i_bounding_box.max = b

	return this
end

function ModelInstance:newInstance(model, props)
	local props = props or {}
	props.model_i_reference = model
	return ModelInstance:new(props)
end

function ModelInstance:newInstances(model, instances)
	local count = #instances
	instances.mesh = ModelInfo.newMeshFromInfoTable(model, instances)

	local props = {
		["model_i_static"] = true,
		["model_i_reference"] = model,
		["model_i_draw_instances"] = true,
		["model_i_instances"] = instances,
		["model_i_instances_count"] = count
	}

	return ModelInstance:new(props)
end

function ModelInstance:usesModelInstancing()
	return self.props.model_i_draw_instances
end

function ModelInstance:allocateOutframeMatrices()
	if self.outframes_allocated then return end

	local model = self:getModel()
	if model.props.model_animated then
		local count = model:getSkeletonJointCount()
		print("jointcount", count)
		local mat4new = cpml.mat4.new
		for i=1,count do
			--print("mmmhm",i)
			--self.bone_matrices[i] = cpml.mat4.new({1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,})
			self.bone_matrices[i] = cpml.mat4.new()
			--print(self.bone_matrices[i],i )
		end
		self.outframes_allocated = true
	end
end

local __vec3temp = cpml.vec3.new()
local __mat4temp = cpml.mat4.new()
function ModelInstance:modelMatrix()
	local is_static = self.props.model_i_static
	--if (is_static and not self.model_moved) or not self.model_moved then
	if not self.model_moved then
		return self.static_model_matrix, self.static_normal_matrix
	end

	prof.push("modelmatrix")
	local props = self.props
	local pos = props.model_i_position
	local rot = props.model_i_rotation
	local scale = props.model_i_scale

	local m = self.static_model_matrix

	local id =
	{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
	for i=1,16 do
		m[i] = id[i]
	end

	--m = cpml.mat4.new()

	--m:scale(m,  cpml.vec3(unpack(props.model_i_scale)))
	__vec3temp.x = scale[1]
	__vec3temp.y = scale[2]
	__vec3temp.z = scale[3]
	m:scale(m,  __vec3temp)

	rotateMatrix(m, rot)

	__vec3temp.x = pos[1]
	__vec3temp.y = pos[2]
	__vec3temp.z = pos[3]
	m:translate(m, __vec3temp )

	--print(m)

	local dirfix = props.model_i_reference:getDirectionFixingMatrix()
	m = cpml.mat4.mul(m, m, dirfix )
	--m = m * dirfix 

	local norm_m = self.static_normal_matrix
	--local norm_m = cpml.mat4.new()
	norm_m = norm_m:invert(m)
	norm_m = norm_m:transpose(norm_m)

	self.static_model_matrix = m
	self.static_normal_matrix = norm_m

	self.model_moved = false
	self.recalculate_bounds_flag = true

	self:calculateBoundingBox()
	prof.pop("modelmatrix")
	return m, norm_m
end

function ModelInstance:areBoundsChanged()
	return self.recalculate_bounds_flag
end

function ModelInstance:informNewBoundsAreHandled()
	self.recalculate_bounds_flag = false
end

function ModelInstance:getModelReferenceBoundingBox()
	return self.props.model_i_reference.props.model_bounding_box
end

function ModelInstance:getUnfixedModelReferenceBoundingBox()
	return self.props.model_i_reference.props.model_bounding_box_unfixed
end

local __p_temptable = {
{0,0,0,0},
{0,0,0,0},
{0,0,0,0},
{0,0,0,0},
{0,0,0,0},
{0,0,0,0},
{0,0,0,0},
{0,0,0,0}}
local __tempnewmin = {}
local __tempnewmax = {}
function ModelInstance:calculateBoundingBox()
	local bbox = self:getUnfixedModelReferenceBoundingBox()
	local min = bbox.min
	local max = bbox.max

	local model_mat = self.static_model_matrix

	-- all 8 vertices of the bounding box
	--[[local p = {}
	p[1] = {min[1], min[2], min[3], 1}
	p[2] = {max[1], min[2], min[3], 1}
	p[3] = {min[1], max[2], min[3], 1}
	p[4] = {max[1], max[2], min[3], 1}
	p[5] = {min[1], min[2], max[3], 1}
	p[6] = {max[1], min[2], max[3], 1}
	p[7] = {min[1], max[2], max[3], 1}
	p[8] = {max[1], max[2], max[3], 1}]]

	local p = __p_temptable
	-- beautiful
	p[1][1] = min[1]     p[1][2] = min[2]    p[1][3] = min[3]  p[1][4] = 1
	p[2][1] = max[1]     p[2][2] = min[2]    p[2][3] = min[3]  p[2][4] = 1
	p[3][1] = min[1]     p[3][2] = max[2]    p[3][3] = min[3]  p[3][4] = 1
	p[4][1] = max[1]     p[4][2] = max[2]    p[4][3] = min[3]  p[4][4] = 1
	p[5][1] = min[1]     p[5][2] = min[2]    p[5][3] = max[3]  p[5][4] = 1
	p[6][1] = max[1]     p[6][2] = min[2]    p[6][3] = max[3]  p[6][4] = 1
	p[7][1] = min[1]     p[7][2] = max[2]    p[7][3] = max[3]  p[7][4] = 1
	p[8][1] = max[1]     p[8][2] = max[2]    p[8][3] = max[3]  p[8][4] = 1

	local mat_vec4_mul = cpml.mat4.mul_vec4
	-- transform all 8 vertices by the model matrix
	for i=1,8 do
		local vec = p[i]
		mat_vec4_mul(vec, model_mat, vec)

		-- perform w perspective division
		local w = vec[4]
		vec[1] = vec[1] / w
		vec[2] = vec[2] / w
		vec[3] = vec[3] / w
		--vec[4] = 1 
	end

	-- we find out the new min/max x,y,z components of all the
	-- transformed vertices to get the min/max for our new
	-- bounding box
	local new_min = __tempnewmin
	local new_max = __tempnewmax
	--local new_min = { 1/0,  1/0,  1/0}
	--local new_max = {-1/0, -1/0, -1/0}
	new_min[1] = 1/0
	new_min[2] = 1/0
	new_min[3] = 1/0
	new_max[1] =-1/0
	new_max[2] =-1/0
	new_max[3] =-1/0

	for i=1,8 do
		local vec = p[i]
		if vec[1] < new_min[1] then new_min[1] = vec[1] end
		if vec[2] < new_min[2] then new_min[2] = vec[2] end
		if vec[3] < new_min[3] then new_min[3] = vec[3] end

		if vec[1] > new_max[1] then new_max[1] = vec[1] end
		if vec[2] > new_max[2] then new_max[2] = vec[2] end
		if vec[3] > new_max[3] then new_max[3] = vec[3] end
	end

	local self_bbox = self.props.model_i_bounding_box
	self_bbox.min[1] = new_min[1]
	self_bbox.min[2] = new_min[2]
	self_bbox.min[3] = new_min[3]
	self_bbox.max[1] = new_max[1]
	self_bbox.max[2] = new_max[2]
	self_bbox.max[3] = new_max[3]
end

-- returns the bounding box
-- returns two tables for the position and size for the box
function ModelInstance:getBoundingBoxPosSize()
	local bbox = self.props.model_i_bounding_box
	local min = bbox.min
	local max = bbox.max
	local size = {max[1]-min[1], max[2]-min[2], max[3]-min[3]}
	return min, size
end

function ModelInstance:setPosition(pos)
	local v = self.props.model_i_position
	if pos[1]~=v[1]or pos[2]~=v[2] or pos[3]~=v[3] then
		self.props.model_i_position[1] = pos[1]
		self.props.model_i_position[2] = pos[2]
		self.props.model_i_position[3] = pos[3]
		--self.props.model_i_position = pos
		self.model_moved = true
	end
end
function ModelInstance:setRotation(rot)
	local r = self.props.model_i_rotation
	if rot[1]~=r[1] or rot[2]~=r[2] or rot[3]~=r[3] or rot[4] ~= rot[4] then
		--self.props.model_i_rotation = rot
		self.props.model_i_rotation[1] = rot[1]
		self.props.model_i_rotation[2] = rot[2]
		self.props.model_i_rotation[3] = rot[3]
		self.props.model_i_rotation[4] = rot[4]
		self.model_moved = true
	end
end
function ModelInstance:setScale(scale)
	local s = self.props.model_i_scale
	if scale[1]~=s[1] or scale[2]~=s[2] or scale[3]~=s[3] then
		self.props.model_i_scale = scale
		self.model_moved = true
	end
end

function ModelInstance:isStatic()
	return self.props.model_i_static
end

function ModelInstance:getModel()
	return self.props.model_i_reference
end

function ModelInstance:queryModelMatrix()
	local m,n = self.static_model_matrix, self.static_normal_matrix
	--print(self.props.model_i_reference.props.model_name, m,n)
	return self.static_model_matrix, self.static_normal_matrix
end

function ModelInstance:fillOutBoneMatrices(animation, frame)
	self:allocateOutframeMatrices()
	--if not self.update_bones() then return end

	local model = self:getModel()
	if model.props.model_animated then
		prof.push("get_bone_matrices")
		self.bone_matrices = model:getBoneMatrices(animation, frame, self.bone_matrices)
		prof.pop("get_bone_matrices")

		for i,v in ipairs(self.bone_matrices) do
			self.bone_matrices[i] = matrix(v)
		end

		--self.bone_matrices = bone_matrices
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

	local model_u, normal_u = self:queryModelMatrix()
	--model_u, normal_u = self:modelMatrix()
	shadersend(shader, "u_model", "column", matrix(model_u))
	shadersend(shader, "u_normal_model", "column", matrix(normal_u))

	prof.push("model_send_bone_matricessssss")
	self:sendBoneMatrices(shader)
	prof.pop("model_send_bone_matricessssss")
end

function ModelInstance:draw(shader, update_animation, is_main_pass)
	local shader = shader or love.graphics.getShader()

	if update_animation then
		self:fillOutBoneMatrices("Walk", getTickSmooth())
	end

	prof.push("model_shader_send")
	self:sendToShader(shader)
	prof.pop("model_shader_send")

	local modelprops = self:getModel().props
	love.graphics.setFrontFaceWinding(modelprops.model_vertex_winding)

	local props = self.props

	prof.push("model_drawwww")
	if props.model_i_draw_instances then
		self:drawInstances(shader)
	elseif is_main_pass then
		if props.model_i_outline_flag then
			self:drawOutlined(shader)
		else
			modelprops.model_mesh:drawModel(shader)
		end
		self:drawDecorations(shader)
	else
		modelprops.model_mesh:drawModel(shader)
		--self:drawDecorations(shader)
	end
	prof.pop("model_drawwww")
	love.graphics.setFrontFaceWinding("ccw")
end

function ModelInstance:drawOutlined(shader)
	local shader = shader or love.graphics.getShader()
	local model = self:getModel()
	local mesh = model:getMesh()

	prof.push("contour_draw")
	if self.props.model_i_contour_flag and gfxSetting("enable_contour") then
		self:drawContour(shader, mesh)
	end
	prof.pop("contour_draw")
	prof.push("after_contour_draw")
	mesh:drawModel(shader)
	prof.pop("after_contour_draw")
end

function ModelInstance:drawContour(shader, mesh)
	local mesh = mesh or model:getMesh()
	local colour = self.props.model_i_outline_colour
	local offset = 0.25

	love.graphics.setMeshCullMode("back")

	shader:send("u_contour_outline_offset", offset)
	shader:send("u_draw_as_contour", true)
	shader:send("u_contour_colour", colour)

	mesh:drawModel(shader)

	shader:send("u_contour_outline_offset", 0.0)
	shader:send("u_draw_as_contour", false)

	love.graphics.setMeshCullMode("front")
end

function ModelInstance:drawInstances(shader) 
	local shader = shader or love.graphics.getShader()
	local attr_mesh = self:getInstancesAttributeMesh()
	local model_mesh = self:getModel():getMesh().mesh
	model_mesh:attachAttribute("InstanceColumn1", attr_mesh, "perinstance")
	model_mesh:attachAttribute("InstanceColumn2", attr_mesh, "perinstance")
	model_mesh:attachAttribute("InstanceColumn3", attr_mesh, "perinstance")
	model_mesh:attachAttribute("InstanceColumn4", attr_mesh, "perinstance")

	shadersend(shader, "instance_draw_call", true)
	love.graphics.drawInstanced(model_mesh, self.props.model_i_instances_count)
	shadersend(shader, "instance_draw_call", false)
end

function ModelInstance:getInstancesAttributeMesh()
	return self.props.model_i_instances.mesh
end

function ModelInstance:drawDecorations(shader)
	local shader = shader or love.graphics.getShader()

	prof.push("draw_decorations")
	for i,decor in ipairs(self:decorations()) do
		decor:draw(self, shader)
	end
	prof.pop("draw_decorations")
end

function ModelInstance:queryBoneMatrix(bone)
	local index = self:getModel():getBoneIndex(bone)
	if index then
		return self.bone_matrices[index]
	else
		return nil
	end
end

function ModelInstance:decorations()
	return self.props.model_i_decorations
end

function ModelInstance:attachDecoration(decor)
	local name = decor:name()
	local decor_table = self.props.model_i_decorations
	table.insert(decor_table, decor)
	decor_table[name] = decor
end

-- name argument can either be the decor_name of the decoration
-- or an index in the decor_table
function ModelInstance:detachDecoration(name)
	local decor_table = self.props.model_i_decorations
	if name == "string" then
		decor_table[name] = nil
		for i,decor in ipairs(decor_table) do
			if decor:name() == name then
				table.remove(decor_table, i)
				return
			end
		end
	else -- if the argument name is a number index
		decor_name = decor_table[name]:name()
		decor_table[decor_name] = nil
		table.remove(decor_table, name)
	end
end

function ModelInstance:isAnimated()
	if self.props.model_i_static then return false end
	return self.props.model_i_reference:isAnimated()
end

function ModelInstance:defaultPose()
	if not self:isAnimated() then return end
	local outframe = self.props.model_i_reference:getDefaultPose(self.bone_matrices)
	self.bone_matrices = outframe
end


--[[
--
--
-- Model
--
--
--]]

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

--[[function Model:allocateOutframeBuffer()
	if self.outframes_buffer_allocated then return end

	if self.props.model_animated then
		local count = model:getSkeletonJointCount()
		print("jointcount", count)
		local mat4new = cpml.mat4.new(1)
		for i=1,count do
			self.outframe_bu = mat4new()
		end
		self.outframes_allocated = true
	end
end--]]

-- corrects the models bounding box by the model direction fixing matrix
function Model:correctBoundingBox()
	if self.bounds_corrected then return end

	local bounds = self.props.model_bounding_box
	local b_min = bounds.min
	local b_max = bounds.max
	local mat4 = cpml.mat4
	local dir_mat = self:getDirectionFixingMatrix()

	-- give the coordinates a 0 w component so they can be multiplied by a mat4
	b_min[4] = 0
	b_max[4] = 0

	-- multiply bounds by the direction fixing matrix
	mat4.mul_vec4(b_min, dir_mat, b_min)
	mat4.mul_vec4(b_max, dir_mat, b_max)

	local function swap(a,b,i)
		local temp = a[i]
		a[i] = b[i]
		b[i] = temp
	end
	-- after transformation, we need to determine the new min/max for x,y,z
	if b_min[1] > b_max[1] then swap(b_min,b_max,1) end
	if b_min[2] > b_max[2] then swap(b_min,b_max,2) end
	if b_min[3] > b_max[3] then swap(b_min,b_max,3) end

	self.bounds_corrected = true
end

-- returns the bounding box
-- returns two tables for the position and size for the box
--function Model:getBoundingBoxPosSize()
--	local bbox = self.model_bounding_box
--	local pos = bbox.min
--	local max = bbox.max
--	local size = {max[1]-min[1], max[2]-min[2], max[3]-min[3]}
--end
--
function Model:isAnimated()
	if not self.props.model_animated then return false end
	return true
end

function Model:getSkeleton()
	return self.props.model_skeleton
end

function Model:getSkeletonJointCount()
	if self.props.model_skeleton then
		return #self.props.model_skeleton
	else
		return 0
	end
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

-- if animation is nil, then default reference pose is used
function Model:getBoneMatrices(animation, frame, outframe)
	if not self.props.model_animated then return end

	local skeleton = self:getSkeleton()

	--local outframe = outframe or {}

	local anim_data = nil
	if animation then
		anim_data = self.props.model_animations[animation]
	end
	if not anim_data then
		--local outframe = self.outframes
		if animation then
		print("getBoneMatrices(): animation \"" .. animation .. "\" does not exist, (model " .. self.props.model_name .. ")")
		end

		return self:getDefaultPose(outframe)
	end

	local frame1,frame2,interp = self:getInterpolatedFrames(animation, frame)
	outframe = self:interpolateTwoFrames(frame1, frame2, interp, outframe)
	return outframe
end

function Model:getInterpolatedFrames(animation, frame, dont_loop)
	if not self.props.model_animated then return nil, nil end

	local anim_data = nil
	if animation then
		anim_data = self.props.model_animations[animation]
	end
	if not anim_data then
		--local outframe = self.outframes
		if animation then
			print("getInterpolatedFrames(): animation \"" .. animation .. "\" does not exist, (model " .. self.props.model_name .. ")")
			return nil,nil,nil
		end
	end

	local anim_first  = anim_data.first
	local anim_last   = anim_data.last
	local anim_length = anim_last - anim_first
	local anim_rate   = anim_data.framerate

	local frame_fitted = frame * anim_rate / tickRate()
	local frame_floor  = math.floor(frame_fitted)
	local frame_interp = frame_fitted - frame_floor
	--local frame_interp_i = 1.0 - frame_interp 

	local frame1_id = anim_first + (frame_floor-1) % anim_length
	local frame2_id = anim_first + (frame_floor) % anim_length

	local frame1 = self.frames[frame1_id]
	local frame2 = self.frames[frame2_id]

	return frame1, frame2, frame_interp
end

function Model:getInterpolatedFrameIndices(animation, frame, dont_loop)
	if not self.props.model_animated then return nil, nil end

	local anim_data = nil
	if animation then
		anim_data = self.props.model_animations[animation]
	end
	if not anim_data then
		if animation then
			print("getInterpolatedFrameIndices(): animation \"" .. animation .. "\" does not exist, (model " .. self.props.model_name .. ")")
			return nil,nil
		end
	end

	local anim_first  = anim_data.first
	local anim_last   = anim_data.last
	local anim_length = anim_last - anim_first
	local anim_rate   = anim_data.framerate

	local frame_fitted = frame * anim_rate / tickRate()
	local frame_floor  = math.floor(frame_fitted)
	local frame_interp = frame_fitted - frame_floor
	--local frame_interp_i = 1.0 - frame_interp 

	local clamp = function(a,low,up) return min(max(a,low),up) end
	
	if not dont_loop then
		local frame1_id = anim_first + (frame_floor-1) % anim_length
		local frame2_id = anim_first + (frame_floor) % anim_length
		return frame1_id, frame2_id
	else
		local frame1_id = clamp(anim_first + (frame_floor-1), 0, anim_last)
		local frame2_id = clamp(anim_first + (frame_floor),   0, anim_last)
		return frame1_id, frame2_id
	end
end

function Model:getUninterpolatedFrame(animation, frame, dont_loop)
	if not self.props.model_animated then return nil, nil end
	local dont_loop = dont_loop or false

	local anim_data = nil
	if animation then
		anim_data = self.props.model_animations[animation]
	end
	if not anim_data then
		--local outframe = self.outframes
		if animation then
			print("getInterpolatedFrames(): animation \"" .. animation .. "\" does not exist, (model " .. self.props.model_name .. ")")
		end
		return nil,nil,nil
	end

	local anim_first  = anim_data.first
	local anim_last   = anim_data.last
	local anim_length = anim_last - anim_first
	local anim_rate   = anim_data.framerate

	local frame_fitted = frame * anim_rate / tickRate()
	local frame_floor  = math.floor(frame_fitted)
	--local frame_interp = frame_fitted - frame_floor
	--local frame_interp_i = 1.0 - frame_interp
	--
	local clamp = function(a,low,up) return min(max(a,low),up) end

	local frame_id = nil
	if not dont_loop then
		frame_id = anim_first + (frame_floor-1) % anim_length
	else
		frame_id = clamp(anim_first + (frame_floor-1), 1, anim_last)
	end
	--local frame1_id = anim_first + (frame_floor-1) % anim_length
	--local frame2_id = anim_first + (frame_floor) % anim_length

	local frame = self.frames[frame_id]

	return frame
end

function Model:interpolateTwoFrames(frame1, frame2, interp, outframe)
	local skeleton = self:getSkeleton()

	local mat4 = cpml.mat4
	local mat4new = mat4.new
	local mat4mul = mat4.mul

	local frame_interp   = interp
	local frame_interp_i = 1.0 - interp

	prof.push("interpolatetwoframes")

	local temps = self.outframes_buffer
	local temp_mat = mat4new()

	for i,pose1 in ipairs(frame1) do
		pose2 = frame2[i]

		for j=1,16 do
			outframe[i][j] =
			 (frame_interp_i)*pose1[j] + frame_interp*pose2[j]
		end

		local parent_i = skeleton[i].parent
		if parent_i > 0 then
			mat4mul(outframe[i], outframe[parent_i], outframe[i])
		else
			--outframe[i] = outframe[i]
		end
	end
	prof.pop("interpolatetwoframes")

	return outframe
end

function Model:getDefaultPose(outframe)
	local id =
	{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}

	local skeleton = self:getSkeleton()
	for i,v in ipairs(skeleton) do
		for j=1,16 do
			outframe[i][j] = id[j]
		end
	end
	return outframe
end

function Model:animationExists(animation)
	if not animation then return false end
	if not self.props.model_animated then return false end
	anim_data = self.props.model_animations[animation]
	return anim_data ~= nil
end

-- this is for use in multi-threaded animation calculation
-- basically the same as get getBoneMatrices, but we just return frame1, frame2, parents and the interp value so
-- all the later steps can be multi-threaded :]
-- returns nil,nil,nil,nil if model is not animated/default animation is used
function Model:getAnimationFramesDataForThread(animation, frame)
	if not self.props.model_animated then return nil, nil end

	local skeleton = self:getSkeleton()

	local mat4 = cpml.mat4
	local mat4new = mat4.new
	local mat4mul = mat4.mul

	--local outframe = outframe or {}

	local anim_data = nil
	if animation then
		anim_data = self.props.model_animations[animation]
	end
	if not anim_data then
		--local outframe = self.outframes
		if animation then
		print("getBoneMatrices(): animation \"" .. animation .. "\" does not exist, (model " .. self.props.model_name .. ")")
		end

		local mat = mat4new(1.0)
		for i,v in ipairs(skeleton) do
			outframe[i] = mat
		end
		return outframe
	end

	local anim_first  = anim_data.first
	local anim_last   = anim_data.last
	local anim_length = anim_last - anim_first
	local anim_rate   = anim_data.framerate

	local frame_fitted = frame * anim_rate / tickRate()
	local frame_floor  = math.floor(frame_fitted)
	local frame_interp = frame_fitted - frame_floor
	local frame_interp_i = 1.0 - frame_interp 

	local frame1_id = anim_first + (frame_floor-1) % anim_length
	local frame2_id = anim_first + (frame_floor) % anim_length

	local frame1 = self.frames[frame1_id]
	local frame2 = self.frames[frame2_id]

	local parents = {}

	local s = #frame1
	for i=1,s do
		parents[i] = skeleton[i].parent
	end

	return frame1,frame2,parents,frame_interp
end

function Model:getBoneIndex(bone)
	local joint_map = self.props.model_animations.joint_map
	return joint_map[bone]
end
