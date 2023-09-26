--
--

local cpml = require 'cpml'

local TransObj = {}
TransObj.__index = TransObj

function TransObj:new(pos,dir,scale)
	function s_clone(dest,t)
		for i,v in ipairs(t) do
			dest[i] = v
		end
	end

	local this = {
		position  = {},
		direction = {},
		scale     = {},
	}
	s_clone(this.position, pos)
	s_clone(this.direction, dir)
	s_clone(this.scale, scale)
	setmetatable(this, TransObj)

	return this
end

function TransObj:newFromMatrix(mat)
	function s_clone(dest,t)
		for i,v in ipairs(t) do
			dest[i] = v
		end
	end

	local this = {
		position  = nil,
		direction = nil,
		scale     = nil,
		matrix    = cpml.mat4.new()
	}
	--s_clone(this.position, pos)
	--s_clone(this.direction, dir)
	--s_clone(this.scale, scale)
	for i=1,16 do this.matrix[i] = mat[i] end
	setmetatable(this, TransObj)

	return this
end

-- assumes that the object has
-- getPosition()
-- getRotation()
-- getScale()
-- functions
function TransObj:from(obj)
	local m = obj:getTransformMode()
	if obj == "component" then
		local pos,rot,scale=obj:getPosition(),obj:getDirection(),obj:getScale()
		return TransObj:new(pos,rot,scale)
	else
		local mat = obj:getTransformMatrix()
		return TransObj:newFromMatrix(mat)
	end
end

function TransObj:send(obj)
	if self.matrix then
		obj:setMatrix(self.matrix)
	else
		obj:setPosition(self.position)
		obj:setDirection(self.direction)
		obj:setScale(self.scale)
	end
end

local __tempvec4 = {0,0,0,0}
local __tempmat4 = cpml.mat4.new()
function TransObj:applyMatrix(mat, mat_info)
	if self.matrix then
		cpml.mat4.mul(self.matrix, mat, self.matrix)
		return
	end

	local mat_info = mat_info or {}
	local has_rot = mat_info.rot
	local has_scale = mat_info.scale

	local p_v = __tempvec4
	p_v[1] = self.position[1]
	p_v[2] = self.position[2]
	p_v[3] = self.position[3]
	p_v[4] = 1.0

	-- apply the matrix to position
	cpml.mat4.mul_vec4(p_v, mat, p_v)
	self.position[1] = p_v[1]
	self.position[2] = p_v[2]
	self.position[3] = p_v[3]

	if has_scale and not has_rot then
		local xs = mat[1]
		local ys = mat[6]
		local zs = mat[11]
		self.scale[1] = self.scale[1] * xs
		self.scale[2] = self.scale[2] * ys
		self.scale[3] = self.scale[3] * zs
	elseif has_rot and not has_scale then
		local d_v = p_v
		d_v[1] = self.direction[1]
		d_v[2] = self.direction[2]
		d_v[3] = self.direction[3]
		d_v[4] = 0.0
		cpml.mat4.mul_vec4(d_v, mat, d_v)
		self.direction[1] = d_v[1]
		self.direction[2] = d_v[2]
		self.direction[3] = d_v[3]
	else
		
	end

	-- extract the scale factors for each x,y,z component
	-- assumed to be non-zero
	--[[local function length(v3)
		return math.sqrt(v3[1]*v3[1] + v3[2]*v3[2] + v3[3]*v3[3])
	end
	local row_x = {mat[1],mat[2],mat[3]}
	local row_y = {mat[5],mat[6],mat[7]}
	local row_z = {mat[9],mat[10],mat[11]}
	local rox_x_l = length(row_x)
	local rox_y_l = length(row_y)
	local rox_z_l = length(row_z)

	self.scale[1] = self.scale[1] * row_x_l
	self.scale[1] = self.scale[1] * row_x_l
	self.scale[1] = self.scale[1] * row_x_l-]]
end

return TransObj
