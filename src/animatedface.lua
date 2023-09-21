require "props.animatedface"
require "facialfeatures"
require "tick"
require "provtype"

AnimFace = {__type = "animface",

		-- composite needs any drawable to call with love.graphics.draw() to invoke
		-- it's shader and have uv coordinates to work with, so this is created.
		temp_tex = love.graphics.newCanvas(1,1,{format="r8"})}
AnimFace.__index = AnimFace

function AnimFace:new(props)
	local this = {
		props = AnimFacePropPrototype(props),
		frame_rate = periodicUpdate(1),
		first_composite = true,

		anim_playing = 0,
		play_last_time    = 0,
		play_time_acc     = 0,
	}

	setmetatable(this,AnimFace)
	this:allocateTexture()

	return this
end

function AnimFace:allocateTexture()
	local dim = self.props.animface_texture_dim
	self.props.animface_texture = love.graphics.newCanvas(dim[1], dim[2], {format="rgba8"})
end
function AnimFace:getTexture()
	return self.props.animface_texture
end

function AnimFace:release()
	local texture = self:getTexture()
	if texture then texture:release() end

	local eyedata = self.props.animface_eyesdata
	if eyedata then eyedata:release() end
end

function AnimFace:composite2()
	local props = self.props
	local texture = self:getTexture()

	if not self.first_composite and not self.frame_rate() then
		return texture
	end	
	self.first_composite = false

	local eyedata = props.animface_eyesdata
	local destw, desth = texture:getDimensions()

	--prof.push("setup_clearbuffers")
	love.graphics.setShader()

	love.graphics.setCanvas(texture)
	love.graphics.clear(0,0,0,0)
	love.graphics.origin()
	love.graphics.setColor(1,1,1,1)

	local shader = Renderer.facecomp_shader
	love.graphics.setShader( shader )

	local righteye_pos = props.animface_righteye_position
	eyedata:pushEyeDataToShader( shader ,
		props.animface_righteye_pose,
		"right", props.animface_righteye_dir,
		eyedata.props.eyes_radius,
		righteye_pos[1], righteye_pos[2],
		destw, desth)


	local lefteye_pos = props.animface_lefteye_position
	eyedata:pushEyeDataToShader( shader ,
		props.animface_lefteye_pose,
		"left", props.animface_lefteye_dir,
		eyedata.props.eyes_radius,
		lefteye_pos[1], lefteye_pos[2],
		destw, desth)

	love.graphics.draw(AnimFace.temp_tex, 0,0,0, destw, desth)
end

function AnimFace:pushComposite()
	--self.first_composite = false
	local texture = self:composite2()
	self.props.animface_decor_reference:getModel():getMesh():setTexture(texture)
end

function AnimFace:pushTexture()
	local texture = self:getTexture()
	self.props.animface_decor_reference:getModel():getMesh():setTexture(texture)
end

function AnimFace:getAnimationData( name )
	assert_type(name, "string")
	local anims = self.props.animface_anims
	local animation = anims[name]
	if not animation then
		error(string.format("AnimFace:getAnimationData(): no such face animation %s found", tostring(name))) end
	return animation
end

local __temptable1,__temptable2,__temptable3,__temptable4 =
{0,0,0},{0,0,0},{0,0,0},{0,0,0}
function AnimFace:updateAnimation()
	local anim = self.props.animface_curr_anim
	if anim == "" then return end

	local anim_data = self:getAnimationData(anim)
	if self.anim_playing then
		local diff = getTickSmooth() - self.play_last_time

		self.play_time_acc = self.play_time_acc + diff * self.props.animface_speed
		self.play_last_time = getTickSmooth()

		local lefteye_pose = nil
		local righteye_pose = nil

		local loop = anim_data.loop or true
		local length = anim_data.length 

		local keytime = 0
		if loop then
			keytime = self.play_time_acc % length
		else
			keytime = math.min(length, self.play_time_acc)
		end

		local frame_i = 1
		local frame_count = #anim_data

		-- seek keyframes
		for i,v in ipairs(anim_data) do
			if v[1] <= keytime then
				--lefteye_pose = v.animface_lefteye_pose or lefteye_pose
				--righteye_pose = v.animface_righteye_pose or righteye_pose
				frame_i = i
			else
				break
			end
		end

		lefteye_pose = anim_data[frame_i].animface_lefteye_pose
		righteye_pose = anim_data[frame_i].animface_righteye_pose

		-- the keyframe seeking&interpolation pattern for eye direction is rather complex,,
		-- perhaps abstract it away&reuse for the future
		local lefteye_dir_1 , lefteye_dir_2  = __temptable1, __temptable2
		local righteye_dir_1, righteye_dir_2 = __temptable3, __temptable4
		local eye_radius = self.props.animface_eyesdata.props.eyes_radius
		lefteye_dir_1[1] ,lefteye_dir_1[2] ,lefteye_dir_1[3]  = 0, 0, eye_radius
		righteye_dir_1[1],righteye_dir_1[2],righteye_dir_1[3] = 0, 0, eye_radius

		local lefteye_dir_1_i , lefteye_dir_2_i  = 1,1
		local righteye_dir_1_i, righteye_dir_2_i = 1,1

		-- we seek for the closest keyframe with a left eye direction
		for i=frame_i,1,-1 do
			lefteye_dir_1_i = i
			local dir = anim_data[i].animface_lefteye_dir 
			if dir then
				lefteye_dir_1[1] ,lefteye_dir_1[2] ,lefteye_dir_1[3]  = dir[1], dir[2], dir[3]
				break end
		end
		for i=frame_i,1,-1 do -- likewise for a right eye direction
			righteye_dir_1_i = i
			local dir = anim_data[i].animface_righteye_dir 
			if dir then
				righteye_dir_1[1] ,righteye_dir_1[2] ,righteye_dir_1[3]  = dir[1], dir[2], dir[3]
				break end
		end

		-- we do the same again to find a keyframe to interpolate to
		local lefteye_dir_2_found = false
		for i=frame_i+1,frame_count+1 do
			lefteye_dir_2_i = i
			local i = ((i-1)%frame_count) + 1
			local dir = anim_data[i].animface_lefteye_dir 
			if dir then
				lefteye_dir_2_found = true
				lefteye_dir_2[1] ,lefteye_dir_2[2] ,lefteye_dir_2[3]  = dir[1], dir[2], dir[3]
				break end
		end
		local righteye_dir_2_found = false
		for i=frame_i+1,frame_count+1 do
			righteye_dir_2_i = i
			local i = ((i-1)%frame_count) + 1
			local dir = anim_data[i].animface_righteye_dir 
			if dir then
				righteye_dir_2_found = true
				righteye_dir_2[1] ,righteye_dir_2[2] ,righteye_dir_2[3]  = dir[1], dir[2], dir[3]
				break end
		end

		-- in case there are missing keyframes for the eye directions
		if not lefteye_dir_2_found then
			lefteye_dir_2[1], lefteye_dir_2[2], lefteye_dir_2[3] = 0, 0, eye_radius	end
		if not righteye_dir_2_found then
			righteye_dir_2[1], righteye_dir_2[2], righteye_dir_2[3] = 0, 0, eye_radius	end

		local lefteye_dir_1_keytime  = anim_data[lefteye_dir_1_i][1]
		local righteye_dir_1_keytime = anim_data[righteye_dir_1_i][1]

		local lefteye_dir_2_keytime
		if lefteye_dir_2_i == frame_count+1 then
			lefteye_dir_2_keytime = length
		else lefteye_dir_2_keytime = anim_data[lefteye_dir_2_i][1] end

		local righteye_dir_2_keytime
		if righteye_dir_2_i == frame_count+1 then
			righteye_dir_2_keytime = length
		else righteye_dir_2_keytime = anim_data[righteye_dir_2_i][1] end
		
		local frame2_keytime = nil 

		local lefteye_interp  = (keytime - lefteye_dir_1_keytime)  / (lefteye_dir_2_keytime  - lefteye_dir_1_keytime)
		local righteye_interp = (keytime - righteye_dir_1_keytime) / (righteye_dir_2_keytime - righteye_dir_1_keytime)
		--print(unpack(righteye_dir_1))
		--print(" ",unpack(righteye_dir_2))
		--print(righteye_dir_1_i, righteye_dir_2_i)

		local ldir = self.props.animface_lefteye_dir
		local rdir = self.props.animface_righteye_dir

		ldir[1],ldir[2],ldir[3] = lefteye_dir_1[1]*(1.0-lefteye_interp) + lefteye_dir_2[1]*lefteye_interp,
                                  lefteye_dir_1[2]*(1.0-lefteye_interp) + lefteye_dir_2[2]*lefteye_interp,
                                  lefteye_dir_1[3]*(1.0-lefteye_interp) + lefteye_dir_2[3]*lefteye_interp

		rdir[1],rdir[2],rdir[3] = righteye_dir_1[1]*(1.0-righteye_interp) + righteye_dir_2[1]*righteye_interp,
                                  righteye_dir_1[2]*(1.0-righteye_interp) + righteye_dir_2[2]*righteye_interp,
                                  righteye_dir_1[3]*(1.0-righteye_interp) + righteye_dir_2[3]*righteye_interp

		if lefteye_pose then self.props.animface_lefteye_pose = lefteye_pose end
		if righteye_pose then self.props.animface_righteye_pose = righteye_pose end
	end
end

function AnimFace:playAnimationByName(name, time, speed)
	assert_type(name, "string")
	local time = time or 0.0
	local speed = speed or 1.0

	self.props.animface_curr_anim = name
	self.props.animface_speed     = speed
	self.play_time_acc = time
	self.play.play_last_time = time
end
