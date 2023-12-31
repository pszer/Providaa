--
-- MapEditTransform handles translating screenspace mouse movements to a 
-- worldspace transformation of translation, rotation or scaling
--
-- you create a MapEditTransform object using either
-- transform = MapEditTransform:newTranslate()
-- transform = MapEditTransform:newRotate()
-- transform = MapEditTransform:newScale()
-- transform = MapEditTransform:newFlip()
--
-- to get the transformation, you call transform:getTransform(cam) where cam
-- is the Camera object for the scene.
-- it will automatically get the current mouse position and determine the 
-- appropiate transformation based on the current view.
-- depending on the type of transformation, it will return a:
-- {x,y,z, type="translate"}   translation
-- {quaternion, type="rotate"} rotation
-- {x,y,z, type="scale"}   scaling
-- {x,y,z, type="scale"}   scale factors (for a flip transformation)
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

local MapEditTransform = {
	__pos_at_cursor = nil
}
MapEditTransform.__index = MapEditTransform

function MapEditTransform:new(mousex, mousey, centre)
	local this = {
		mx = mousex,
		my = mousey,
		sel_centre = centre,
		getCam = get_cam,
		axis_mode = "xyz",
		transformation_type = "nil",
		absolute = false,

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
local function __getTransform_translate(self, cam, granular)
	local curr_mouse_x, curr_mouse_y = love.mouse.getX(), love.mouse.getY()

	local mouse_dx = curr_mouse_x - self.mx
	local mouse_dy = curr_mouse_y - self.my

	local mode = self.axis_mode
	assert(mode == "xyz" or mode=="x" or mode=="y" or mode=="z")

	local acos = math.acos
	local sin  = math.sin

	local int = math.floor
	local g_scale=8
	local function granulate(v)
		--if not granular then return v end
		--v[1] = int(v[1]/g_scale)*g_scale
		--v[2] = int(v[2]/g_scale)*g_scale
		--v[3] = int(v[3]/g_scale)*g_scale
		return v
	end

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
		return granulate{x,y,z, type = "translate"}
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
		return granulate{x,0,0, type = "translate"}
	end

	if mode == "y" then
		local up_vector = __tempdirup
		local cam_up_vector = {cam:getDirectionVector(up_vector)}

		local dot_p = up_vector[1]*cam_up_vector[1] +
                      up_vector[2]*cam_up_vector[2] +
                      up_vector[3]*cam_up_vector[3]
		local costheta = dot_p
		local y = costheta * mouse_dy
		return granulate{0,y,0, type = "translate"}
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
		return granulate{0,0,z, type = "translate"}
	end
end

local __tempvec3 = cpml.vec3.new()
local __tempvec3t = {0,0,0}
local __tempvec3cp1 = cpml.vec3.new()
local __tempvec3cp2 = cpml.vec3.new()
local function __getTransform_rotate(self, cam, granular)
	local curr_mouse_x, curr_mouse_y = love.mouse.getX(), love.mouse.getY()

	local win_w, win_h = love.graphics.getDimensions()

	local mouse_dx = (curr_mouse_x - self.mx) 
	local mouse_dy = (curr_mouse_y - self.my) 
	local mode = self.axis_mode

	local int = math.floor
	local g_scale=math.pi/4.0
	local function granulate_theta(t)
		if not granular then return t end
		t = int(t/g_scale)*g_scale
		return t
	end

	if mode == "xyz" then
		local viewport = {0,0,win_w,win_h}

		local unproject = cpml.mat4.unproject
		local project = cpml.mat4.project
		local viewproj = cam:getViewProjMatrix()
		local cursor = __tempvec3
	--	cursor.x,cursor.y,cursor.z = win_w*0.5+mouse_dx*2, win_h*0.5+mouse_dy*2, 1.0

		local centre_v = __tempvec3cp1
		centre_v.x=self.sel_centre[1]
		centre_v.y=self.sel_centre[2]
		centre_v.z=self.sel_centre[3]
		local centre_v_screen = project(centre_v,viewproj,{0,0,win_w,win_h})

		mouse_dx = curr_mouse_x - centre_v_screen.x
		mouse_dy = curr_mouse_y - centre_v_screen.y

		local angle = math.atan2(mouse_dy,mouse_dx)

		if self.__rotangle_start then
			angle = -(angle - self.__rotangle_start)
		else
			self.__rotangle_start = angle
			angle = 0.0
		end

		local forward_vec = __tempdirforward
		local x,y,z = cam:getDirectionVector(forward_vec)

		return {
			cpml.quat.from_angle_axis(angle, x,y,z),
			angle = angle,
			type="rotate"
		}

		--[[
		local P = unproject(cursor, viewproj, viewport)
		local cam_pos = cam:getPosition()

		local dir = __tempvec3t
		dir[1] = P.x - cam_pos[1]
		dir[2] = P.y - cam_pos[2]
		dir[3] = P.z - cam_pos[3]
		local x,y,z = cam:getDirectionVector(dir)
		local up_vector = __tempdirright
		local x1,y1,z1 = cam:getDirectionVector(up_vector)

		local v1 = __tempvec3cp1
		local v2 = __tempvec3cp2
		v1.x, v1.y, v1.z = x,y,z
		v2.x, v2.y, v2.z = x1,y1,z1
		local cross = cpml.vec3.cross(v1,v2)
		local cross = cpml.vec3.cross(cross, v1)
		cross = cross:normalize()
		return { cpml.quat.from_direction(cross, cpml.vec3.new(0,-1,0)), type="rotate" }--]]
	end

	local function sign(x)
		if x == 0.0 then return  0 end
		if x  < 0.0 then return -1 end
		if x  > 0.0 then return  1 end
	end

	mouse_dx = mouse_dx * (8/win_w)
	mouse_dy = mouse_dy * (8/win_h)
	if mode == "x" then
		local forward_vector = __tempdirforward
		local cam_forward_vector = {cam:getDirectionVector(forward_vector)}

		local dot_p = forward_vector[1]*cam_forward_vector[1] +
                      forward_vector[2]*cam_forward_vector[2] +
                      forward_vector[3]*cam_forward_vector[3]
		local dot_sign = sign(dot_p)

		local axis = __tempdirright
		local angle = granulate_theta(mouse_dy * dot_sign)
		local quat = { cpml.quat.from_angle_axis(angle, axis[1], axis[2], axis[3]),
		 angle = angle , type="rotate" }
		--return {quat.x, quat.y, quat.z, quat.w}
		return quat
	end

	if mode == "y" then
		local axis = __tempdirup
		local angle = granulate_theta(mouse_dx)
		local quat = { cpml.quat.from_angle_axis(angle, axis[1], axis[2], axis[3]), 
		 angle = angle, type="rotate" }
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
		local angle = granulate_theta(mouse_dy * dot_sign)
		local quat = { cpml.quat.from_angle_axis(angle, axis[1], axis[2], axis[3]),
		 angle = angle, type="rotate" }
		--return {quat.x, quat.y, quat.z, quat.w}
		return quat
	end
end

local function __getTransform_scale(self, cam, granular)
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
		--
		--local tdir_up    = {cam:getDirectionVector(__tempdirup)}
		--local tdir_right = {cam:getDirectionVector(__tempdirright)}
		--local x = mouse_dx * tdir_right[1] + mouse_dy * tdir_up[1]
		--local y = -(mouse_dx * tdir_right[2] + mouse_dy * tdir_up[2])
		--local z = -(mouse_dx * tdir_right[3] + mouse_dy * tdir_up[3])
		--local dist = math.sqrt(x*x + y*y + z*z)
		
		--local sign
		--if mouse_dx+mouse_dy < 0 then sign=-1 else sign=1 end
		--local dist = math.sqrt(mouse_dx*mouse_dx + mouse_dy*mouse_dy)
		--local s = scale_map(dist * sign)
		local s = math.max(scale_map(mouse_dx),1/8.0)
		return {s,s,s, type="scale"}
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
		return {scale_map(x),1,1, type="scale"}
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
		return {1,y,1, type="scale"}
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
		return {1,1,scale_map(-z), type="scale"}
	end
end

function MapEditTransform:__getTransform_flip(self, cam)
	local curr_mouse_x, curr_mouse_y = love.mouse.getX(), love.mouse.getY()

	local mouse_dx = curr_mouse_x - self.mx
	local mouse_dy = curr_mouse_y - self.my

	local mode = self.axis_mode
	assert(mode == "xyz" or mode=="x" or mode=="y" or mode=="z")

	local acos = math.acos
	local sin  = math.sin

	local function flip_s(x)
		if x > 0.0 then return 1.0 end
		return -1.0
	end

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
		return {flip_s(x),flip_s(y),flip_s(z),"scale"}
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
		return {flip_s(x),1,1,"scale"}
	end

	if mode == "y" then
		local up_vector = __tempdirup
		local cam_up_vector = {cam:getDirectionVector(up_vector)}

		local dot_p = up_vector[1]*cam_up_vector[1] +
                      up_vector[2]*cam_up_vector[2] +
                      up_vector[3]*cam_up_vector[3]
		local costheta = dot_p
		local y = costheta * mouse_dy
		return {1,flip_s(-y),1,"scale"}
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
		return {1,1,flip_s(z),"scale"}
	end
end

function MapEditTransform:__getTransform_cursor(self, cam)
	local curr_mouse_x, curr_mouse_y = love.mouse.getX(), love.mouse.getY()
	local get_at_cursor = self.get_at_cursor

	local sel_centre = self.sel_centre
	local last_pos = self.last_pos
	local pos = self.pos_at_cursor(x,y)

	if pos then
		last_pos[1]=pos[1]
		last_pos[2]=pos[2]
		last_pos[3]=pos[3]
	else
		pos = last_pos
	end

	local result = {
		pos[1]-sel_centre[1],
		pos[2]-sel_centre[2],
		pos[3]-sel_centre[3],
		"translate"
	}
end

function MapEditTransform:newTranslate(c)
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my,c)
	this.getTransform = __getTransform_translate
	this.transformation_type = "translate"
	return this
end
function MapEditTransform:newRotate(c)
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my,c)
	this.getTransform = __getTransform_rotate
	this.transformation_type = "rotate"
	return this
end
function MapEditTransform:newScale(c)
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my,c)
	this.getTransform = __getTransform_scale
	this.transformation_type = "scale"
	return this
end
function MapEditTransform:newFlip(c)
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my,c)
	this.getTransform = __getTransform_flip
	this.transformation_type = "flip"
	return this
end
function MapEditTransform:newTransform(trans_type,centre)
	assert(trans_type and (trans_type == "translate" or trans_type == "rotate" or trans_type == "scale" or trans_type == "flip"))
	if trans_type == "translate" then return self:newTranslate(centre) end
	if trans_type == "rotate" then return self:newRotate(centre) end
	if trans_type == "scale" then return self:newScale(centre) end
	if trans_type == "flip" then return self:newFlip(centre) end
end
function MapEditTransform:newCursorTransform(tests,centre)
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my,centre)
	this.getTransform = __getTransform_cursor
	this.transformation_type = "translate"
	this.pos_at_cursor = self.__pos_at_cursor(tests)
	this.last_pos = {unpack(centre)}
	return this
end

local __flipx = {-1, 1, 1, type="scale"}
local __flipy = { 1,-1, 1, type="scale"}
local __flipz = { 1, 1,-1, type="scale"}

local t000 = 0*math.pi/2.0
local t090 = 1*math.pi/2.0
local t180 = 2*math.pi/2.0
local t270 = 3*math.pi/2.0

local quat_x_000 = cpml.quat.from_angle_axis(t000, 1,0,0)
local quat_x_090 = cpml.quat.from_angle_axis(t090, 1,0,0)
local quat_x_180 = cpml.quat.from_angle_axis(t180, 1,0,0)
local quat_x_270 = cpml.quat.from_angle_axis(t270, 1,0,0)

local quat_y_000 = cpml.quat.from_angle_axis(t000, 0,-1,0)
local quat_y_090 = cpml.quat.from_angle_axis(t090, 0,-1,0)
local quat_y_180 = cpml.quat.from_angle_axis(t180, 0,-1,0)
local quat_y_270 = cpml.quat.from_angle_axis(t270, 0,-1,0)

local quat_z_000 = cpml.quat.from_angle_axis(t000, 0,0,1)
local quat_z_090 = cpml.quat.from_angle_axis(t090, 0,0,1)
local quat_z_180 = cpml.quat.from_angle_axis(t180, 0,0,1)
local quat_z_270 = cpml.quat.from_angle_axis(t270, 0,0,1)

local function def_fixed_rot(quat,angle)
	local T = MapEditTransform:new(0,0)
	T.getTransform = function(self,cam,g) return {quat, type="rotate", angle=angle} end
	T.transformation_type = "rotate"
	return T
end

function MapEditTransform:rotateByAxis(angle,axis)
	assert(string.match(axis,"^[xXyYzZ]$"))
	local quat
	if axis=="x" or axis=="X" then
		quat=cpml.quat.from_angle_axis(angle, 1,0,0)
	elseif axis=="y" or axis=="Y" then
		quat=cpml.quat.from_angle_axis(angle, 0,-1,0)
	elseif axis=="z" or axis=="Z" then
		quat=cpml.quat.from_angle_axis(angle, 0,0,1)
	end
	return def_fixed_rot(quat,angle)
end

function MapEditTransform:scaleBy(x,y,z)
	local T = MapEditTransform:new(0,0)
	T.getTransform = function(self,cam,g) return {x,y,z, type="scale"} end
	T.transformation_type = "scale"
	T.absolute = true
	return T
end

function MapEditTransform:translateBy(x,y,z)
	local T = MapEditTransform:new(0,0)
	T.getTransform = function(self,cam,g) return {x,y,z, type="translate"} end
	T.transformation_type = "translate"
	T.absolute = true
	return T
end

local __flipx = {-1, 1, 1, type="scale"}
local __flipy = { 1,-1, 1, type="scale"}
local __flipz = { 1, 1,-1, type="scale"}

MapEditTransform.rot_x_000 = def_fixed_rot(quat_x_000,0*math.pi/4)
MapEditTransform.rot_x_090 = def_fixed_rot(quat_x_090,1*math.pi/4)
MapEditTransform.rot_x_180 = def_fixed_rot(quat_x_180,2*math.pi/4)
MapEditTransform.rot_x_270 = def_fixed_rot(quat_x_270,3*math.pi/4)
MapEditTransform.rot_y_000 = def_fixed_rot(quat_y_000,0*math.pi/4)
MapEditTransform.rot_y_090 = def_fixed_rot(quat_y_090,1*math.pi/4)
MapEditTransform.rot_y_180 = def_fixed_rot(quat_y_180,2*math.pi/4)
MapEditTransform.rot_y_270 = def_fixed_rot(quat_y_270,3*math.pi/4)
MapEditTransform.rot_z_000 = def_fixed_rot(quat_z_000,0*math.pi/4)
MapEditTransform.rot_z_090 = def_fixed_rot(quat_z_090,1*math.pi/4)
MapEditTransform.rot_z_180 = def_fixed_rot(quat_z_180,2*math.pi/4)
MapEditTransform.rot_z_270 = def_fixed_rot(quat_z_270,3*math.pi/4)

local FlipXT = MapEditTransform:new(0,0)
FlipXT.getTransform = function(self,cam,g) return __flipx end
FlipXT.transformation_type = "scale"
local FlipYT = MapEditTransform:new(0,0)
FlipYT.getTransform = function(self,cam,g) return __flipy end
FlipYT.transformation_type = "scale"
local FlipZT = MapEditTransform:new(0,0)
FlipZT.getTransform = function(self,cam,g) return __flipz end
FlipZT.transformation_type = "scale"

MapEditTransform.flip_x_const = FlipXT
MapEditTransform.flip_y_const = FlipYT
MapEditTransform.flip_z_const = FlipZT

return MapEditTransform
