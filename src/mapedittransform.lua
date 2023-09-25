--
-- MapEditTransform handles translating screenspace mouse movements to a 
-- worldspace transformation of translation, rotation or scaling
--
-- you create a MapEditTransform object using either
-- transform = MapEditTransform:newTranslate()
-- transform = MapEditTransform:newRotate()
-- transform = MapEditTransform:newScale()
--
-- to get the transformation, you call transform:getTransform(cam) where cam
-- is the Camera object for the scene.
-- it will automatically get the current mouse position and determine the 
-- appropiate transformation based on the current view.
-- depending on the type of transformation, it will return a:
-- {x,y,z}   translation
-- {x,y,z,w} quaternion
-- {x,y,z}   scale factors
--
-- transformations can be axis-locked, to toggle axis-locking call
-- transform:lockX() / lockY() / lockZ()
-- the current axis-lock state can be accessed in transform.axis_mode
-- it will be one of:
-- "xyz" - no axis locking
-- "x"   - x axis locked
-- "y"   - y axis locked
-- "z"   - z axis locked
--

local cpml = require 'cpml'

local MapEditTransform = {}
MapEditTransform.__index = MapEditTransform

function MapEditTransform:new(mousex, mousey)
	local this = {
		mx = mousex,
		my = mousey,
		getCam = get_cam,
		axis_mode = "xyz",
		transformation_type = "nil",

		getTransform = function(cam)
			error("MapEditTransform:getTransform(): this object has no transformation type, use newTranslate() / newRotate() / newScale()!")
		end,
		getTransformType = function(self)
			local t = self.transformation_type
			assert(t ~= "nil")
			return t
		end,

		lockX = function(self)
			if self.axis_mode == "x" then
				self.axis_mode = "xyz" -- toggle off x-axis lock if already enabled
				return
			end
			self.axis_mode = "x"
		end,
		lockY = function(self)
			if self.axis_mode == "y" then
				self.axis_mode = "xyz" -- toggle off y-axis lock if already enabled
				return
			end
			self.axis_mode = "y"
		end,
		lockZ = function(self)
			if self.axis_mode == "z" then
				self.axis_mode = "xyz" -- toggle off z-axis lock if already enabled
				return
			end
			self.axis_mode = "z"
		end,
	}
	setmetatable(this, MapEditTransform)
	return this
end

local __tempdirup      = {0,-1,0}
local __tempdirright   = {1,0,0}
local __tempdirforward = {0,0,-1}
local function __getTransform_translate(self, cam)
	local curr_mouse_x, curr_mouse_y = love.mouse.getX(), love.mouse.getY()

	local mouse_dx = curr_mouse_x - self.mx
	local mouse_dy = curr_mouse_y - self.my

	local mode = self.axis_mode
	assert(mode == "xyz" or mode=="x" or mode=="y" or mode=="z")

	local acos = math.acos
	local sin  = math.sin

	if mode == "xyz" then
		-- in normal "xyz" mode, the final transformation is
		-- (mouse_dx * cam_relative_right_vector) + (mouse_dy * cam_relative_up_vector)
		-- where cam_relative_right_vector is the vector pointing directly right
		-- from the camera's perspective, likewise for cam_relative_up_vector
		local tdir_up    = {cam:getDirectionVector(__tempdirup)}
		local tdir_right = {cam:getDirectionVector(__tempdirright)}
		local x = mouse_dx * tdir_right[1] - mouse_dy * tdir_up[1]
		local y = mouse_dx * tdir_right[2] - mouse_dy * tdir_up[2]
		local z = mouse_dx * tdir_right[3] - mouse_dy * tdir_up[3]
		return {x,y,z}
	end

	local function sign(x)
		if x == 0.0 then return  0 end
		if x  < 0.0 then return -1 end
		if x  > 0.0 then return  1 end
	end

	if mode == "x" then
		local right_vector = __tempdirright
		local cam_right_vector = {cam:getDirectionVector(right_vector)}

		local dot_p = right_vector[1]*cam_right_vector[1] +
                      right_vector[2]*cam_right_vector[2] +
                      right_vector[3]*cam_right_vector[3]
		-- both right_vector and cam_right_vector are unit vectors, no need
		-- to normalise
		local theta = acos(dot_p)

		local costheta = dot_p
		local sintheta = sin(theta)

		local forward_vector = __tempdirforward
		local cam_f_vector = {cam:getDirectionVector(forward_vector)}

		local dot_p = right_vector[1]*cam_f_vector[1] +
                      right_vector[2]*cam_f_vector[2] +
                      right_vector[3]*cam_f_vector[3]
		local dot_sign = sign(dot_p)

		local x = costheta * mouse_dx - sintheta * mouse_dy * dot_sign
		return {x,0,0}
	end

	if mode == "y" then
		local up_vector = __tempdirup
		local cam_up_vector = {cam:getDirectionVector(up_vector)}

		local dot_p = up_vector[1]*cam_up_vector[1] +
                      up_vector[2]*cam_up_vector[2] +
                      up_vector[3]*cam_up_vector[3]
		local costheta = dot_p
		local y = costheta * mouse_dy
		return {0,y,0}
	end

	if mode == "z" then
		local forward_vector = __tempdirforward
		local cam_forward_vector = {cam:getDirectionVector(forward_vector)}

		local dot_p = forward_vector[1]*cam_forward_vector[1] +
                      forward_vector[2]*cam_forward_vector[2] +
                      forward_vector[3]*cam_forward_vector[3]
		-- both right_vector and cam_right_vector are unit vectors, no need
		-- to normalise
		local theta = acos(dot_p)

		local costheta = dot_p
		local sintheta = sin(theta)

		local right_vector = __tempdirright
		local cam_f_vector = {cam:getDirectionVector(right_vector)}

		local dot_p = forward_vector[1]*cam_f_vector[1] +
                      forward_vector[2]*cam_f_vector[2] +
                      forward_vector[3]*cam_f_vector[3]
		local dot_sign = sign(dot_p)

		local z = -sintheta * mouse_dx * dot_sign + costheta * mouse_dy
		return {0,0,z}
	end
end

local __tempvec3 = cpml.vec3.new()
local __tempvec3t = {0,0,0}
local function __getTransform_rotate(self, cam)
	local curr_mouse_x, curr_mouse_y = love.mouse.getX(), love.mouse.getY()

	local win_w, win_h = love.graphics.getDimensions()

	local mouse_dx = (curr_mouse_x - self.mx) 
	local mouse_dy = (curr_mouse_y - self.my) 
	local mode = self.axis_mode

	if mode == "xyz" then
		local viewport = {0,0,win_w,win_h}

		local unproject = cpml.mat4.unproject
		local viewproj = cam:getViewProjMatrix()
		local cursor = __tempvec3
		cursor.x,cursor.y,cursor.z = win_w*0.5+mouse_dx*2, win_h*0.5+mouse_dy*2, 1.0

		local P = unproject(cursor, viewproj, viewport)
		local cam_pos = cam:getPosition()

		local dir = __tempvec3t
		dir[1] = P.x - cam_pos[1]
		dir[2] = P.y - cam_pos[2]
		dir[3] = P.z - cam_pos[3]
		local x,y,z = cam:getInverseDirectionVector(dir)
		--local length = math.sqrt(x*x + y*y + z*z)
		--x = x/length
		--y = y/length
		--z = z/length

		--dir[1],dir[2],dir[3],dir[4]=x,y,z,1
		return cpml.quat.new(dir)
		--return dir
	end

	local function sign(x)
		if x == 0.0 then return  0 end
		if x  < 0.0 then return -1 end
		if x  > 0.0 then return  1 end
	end

	mouse_dx = mouse_dx * (8/win_w)
	mouse_dy = mouse_dy * (8/win_h)
	--[[local sin,cos = math.sin,math.cos
	if mode == "x" then
		local forward_vector = __tempdirforward
		local cam_forward_vector = {cam:getDirectionVector(forward_vector)}

		local dot_p = forward_vector[1]*cam_forward_vector[1] +
                      forward_vector[2]*cam_forward_vector[2] +
                      forward_vector[3]*cam_forward_vector[3]
		local dot_sign = sign(dot_p)

		local y = sin(mouse_dy * dot_sign)
		local z = -cos(mouse_dy * dot_sign)
		print(dot_sign)
		return {0,y,z}
	end
	if mode == "y" then
		local x = sin(mouse_dx)
		local z = -cos(mouse_dx)
		return {x,0,z}
	end
	if mode == "z" then
		local right_vector = __tempdirright
		local cam_f_vector = {cam:getDirectionVector(right_vector)}
		local dot_p = right_vector[1]*cam_f_vector[1] +
                      right_vector[2]*cam_f_vector[2] +
                      right_vector[3]*cam_f_vector[3]
		local dot_sign = sign(dot_p)
		print("z")
		local x = sin(mouse_dy * -dot_sign)
		local y = -cos(mouse_dy * -dot_sign)
		return {x,y,0}
	end--]]
	if mode == "x" then
		local forward_vector = __tempdirforward
		local cam_forward_vector = {cam:getDirectionVector(forward_vector)}

		local dot_p = forward_vector[1]*cam_forward_vector[1] +
                      forward_vector[2]*cam_forward_vector[2] +
                      forward_vector[3]*cam_forward_vector[3]
		local dot_sign = sign(dot_p)

		local axis = __tempdirright
		local angle = mouse_dy * dot_sign
		local quat = cpml.quat.from_angle_axis(angle, axis[1], axis[2], axis[3])
		--return {quat.x, quat.y, quat.z, quat.w}
		return quat
	end

	if mode == "y" then
		local axis = __tempdirup
		local angle = mouse_dx
		local quat = cpml.quat.from_angle_axis(angle, axis[1], axis[2], axis[3])
		--return {quat.x, quat.y, quat.z, quat.w}
		return quat
	end

	if mode == "z" then
		local right_vector = __tempdirright
		local cam_f_vector = {cam:getDirectionVector(right_vector)}
		local dot_p = right_vector[1]*cam_f_vector[1] +
                      right_vector[2]*cam_f_vector[2] +
                      right_vector[3]*cam_f_vector[3]
		local dot_sign = sign(dot_p)

		local axis = __tempdirforward
		local angle = mouse_dy * dot_sign
		local quat = cpml.quat.from_angle_axis(angle, axis[1], axis[2], axis[3])
		--return {quat.x, quat.y, quat.z, quat.w}
		return quat
	end
end

local function __getTransform_scale(self, cam)
	local curr_mouse_x, curr_mouse_y = love.mouse.getX(), love.mouse.getY()
	local mouse_dx = (curr_mouse_x - self.mx) / 66.0
	local mouse_dy = (curr_mouse_y - self.my) / 66.0

	local pow = math.pow
	local function scale_map(x)
		if x < 0 then
			return pow(2,x)
		end
		return x+1
	end

	local mode = self.axis_mode
	assert(mode == "xyz" or mode=="x" or mode=="y" or mode=="z")

	local acos = math.acos
	local sin  = math.sin

	if mode == "xyz" then
		-- in normal "xyz" mode, the final transformation is
		-- (mouse_dx * cam_relative_right_vector) + (mouse_dy * cam_relative_up_vector)
		-- where cam_relative_right_vector is the vector pointing directly right
		-- from the camera's perspective, likewise for cam_relative_up_vector
		local tdir_up    = {cam:getDirectionVector(__tempdirup)}
		local tdir_right = {cam:getDirectionVector(__tempdirright)}
		local x = scale_map(mouse_dx * tdir_right[1] + mouse_dy * tdir_up[1])
		local y = scale_map(-(mouse_dx * tdir_right[2] + mouse_dy * tdir_up[2]))
		local z = scale_map(-(mouse_dx * tdir_right[3] + mouse_dy * tdir_up[3]))
		return {x,y,z}
	end

	local function sign(x)
		if x == 0.0 then return  0 end
		if x  < 0.0 then return -1 end
		if x  > 0.0 then return  1 end
	end

	if mode == "x" then
		local right_vector = __tempdirright
		local cam_right_vector = {cam:getDirectionVector(right_vector)}

		local dot_p = right_vector[1]*cam_right_vector[1] +
                      right_vector[2]*cam_right_vector[2] +
                      right_vector[3]*cam_right_vector[3]
		-- both right_vector and cam_right_vector are unit vectors, no need
		-- to normalise
		local theta = acos(dot_p)

		local costheta = dot_p
		local sintheta = sin(theta)

		local forward_vector = __tempdirforward
		local cam_f_vector = {cam:getDirectionVector(forward_vector)}

		local dot_p = right_vector[1]*cam_f_vector[1] +
                      right_vector[2]*cam_f_vector[2] +
                      right_vector[3]*cam_f_vector[3]
		local dot_sign = sign(dot_p)

		local x = costheta * mouse_dx - sintheta * mouse_dy
		return {scale_map(x),1,1}
	end

	if mode == "y" then
		local up_vector = __tempdirup
		local cam_up_vector = {cam:getDirectionVector(up_vector)}

		local dot_p = up_vector[1]*cam_up_vector[1] +
                      up_vector[2]*cam_up_vector[2] +
                      up_vector[3]*cam_up_vector[3]
		-- both right_vector and cam_right_vector are unit vectors, no need
		-- to normalise
		local theta = acos(dot_p)

		local costheta = dot_p
		local sintheta = sin(theta)

		local y = scale_map(-costheta * mouse_dy)
		return {1,y,1}
	end

	if mode == "z" then
		local forward_vector = __tempdirforward
		local cam_forward_vector = {cam:getDirectionVector(forward_vector)}

		local dot_p = forward_vector[1]*cam_forward_vector[1] +
                      forward_vector[2]*cam_forward_vector[2] +
                      forward_vector[3]*cam_forward_vector[3]
		-- both right_vector and cam_right_vector are unit vectors, no need
		-- to normalise
		local theta = acos(dot_p)

		local costheta = dot_p
		local sintheta = sin(theta)

		local right_vector = __tempdirright
		local cam_f_vector = {cam:getDirectionVector(right_vector)}

		local dot_p = forward_vector[1]*cam_f_vector[1] +
                      forward_vector[2]*cam_f_vector[2] +
                      forward_vector[3]*cam_f_vector[3]
		local dot_sign = sign(dot_p)

		local z = -sintheta * mouse_dx + costheta * mouse_dy
		return {1,1,scale_map(-z)}
	end
end

function MapEditTransform:newTranslate()
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my)
	this.getTransform = __getTransform_translate
	this.transformation_type = "translate"
	return this
end
function MapEditTransform:newRotate()
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my)
	this.getTransform = __getTransform_rotate
	this.transformation_type = "rotate"
	return this
end
function MapEditTransform:newScale()
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my)
	this.getTransform = __getTransform_scale
	this.transformation_type = "scale"
	return this
end
function MapEditTransform:newTransform(trans_type)
	assert(trans_type and (trans_type == "translate" or trans_type == "rotate" or trans_type == "scale"))
	if trans_type == "translate" then
		return self:newTranslate() end
	if trans_type == "rotate" then
		return self:newRotate() end
	if trans_type == "scale" then
		return self:newScale() end
end

return MapEditTransform
