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

local MapEditTransform = {}
MapEditTransform.__index = MapEditTransform

function MapEditTransform:new(mousex, mousey)
	local this = {
		mx = mousex,
		my = mousey,
		getCam = get_cam,
		axis_mode = "xyz",

		getTransform = function(cam)
			error("MapEditTransform:getTransform(): this object has no transformation type, use newTranslate() / newRotate() / newScale()!")
		end,

		lockX = function(self)
			if self.axismode == "x" then
				self.axismode = "xyz" -- toggle off x-axis lock if already enabled
				return
			end
			self.axismode = "x"
		end,
		lockY = function(self)
			if self.axismode == "y" then
				self.axismode = "xyz" -- toggle off y-axis lock if already enabled
				return
			end
			self.axismode = "y"
		end,
		lockZ = function(self)
			if self.axismode == "z" then
				self.axismode = "xyz" -- toggle off z-axis lock if already enabled
				return
			end
			self.axismode = "z"
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

	if mode == "xyz" then
		-- in normal "xyz" mode, the final transformation is
		-- (mouse_dx * cam_relative_right_vector) + (mouse_dy * cam_relative_up_vector)
		-- where cam_relative_right_vector is the vector pointing directly right
		-- from the camera's perspective, likewise for cam_relative_up_vector
		local tdir_up    = cam:getDirectionVector(__tempdirup)	
		local twdir_right = cam:getDirectionVector(__tempdirright)
		local x = mouse_dx * tdir_right[1] + mouse_dy * tdir_up[1]
		local y = mouse_dx * tdir_right[2] + mouse_dy * tdir_up[2]
		local z = mouse_dx * tdir_right[3] + mouse_dy * tdir_up[3]
		return {x,y,z}
	end

	if mode == "x" then
		local right_vector = __tempdirright
		local cam_right_vector = cam:getDirectionVector(right_vector)

		local dot_p = right_vector[1]*cam_right_vector[1] +
                      right_vector[2]*cam_right_vector[2] +
                      right_vector[3]*cam_right_vector[3]
		-- both right_vector and cam_right_vector are unit vectors, no need
		-- to normalise
		local theta = acos(dot_p)

		local costheta = dot_p
		local sintheta = sin(theta)

		local x = costheta * dx + sintheta * dy
		return {x,0,0}
	end
end
local function __getTransform_rotate(self, cam)

end
local function __getTransform_scale(self, cam)

end

function MapEditTransform:newTranslate()
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my)
	this.getTransform = __getTransform_translate
	print("ok", this.getTransform)
	return this
end
function MapEditTransform:newRotate()
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my)
	this.getTransform = __getTransform_rotate
	return this
end
function MapEditTransform:newScale()
	local mx,my = love.mouse.getX(), love.mouse.getY()
	local this = MapEditTransform:new(mx,my)
	this.getTransform = __getTransform_scale
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
