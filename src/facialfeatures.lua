require "texturemanager"
require "render"

require "props.facialfeaturesprops"
local eye_attributes = require 'cfg/eyes'

--[[
--
-- Do SET_GAMESTATE(EYETESTMODE) for an eye compositing demo.
--
-- Eyes are stored as in a single texture in the following 2xN grid
--
-- eyes.dds
-- |------------------------------|
-- |                              |
-- |     Iris         Highlight   |
-- |                              |
-- | EyeTexture1   ScleraStencil1 |  <-- Eye pose 1
-- |                              |
-- | EyeTexture2   ScleraStencil2 |  <-- Eye pose 2
-- |                              |
-- | EyeTexture3   ScleraStencil3 |  <-- Eye pose 3
-- |                              |
-- |      ...            ...      |
-- |                              |
-- | EyeTextureN   ScleraStencilN |  <-- Eye pose N
-- |                              |
-- |------------------------------|
--
-- Each component is an image with identical widths and heights placed
-- at the eyes neutral position.
--
-- Each row below Iris and Highlight is a pose for the eye (one could be fully open, another half closed etc.),
-- each poses re-uses the same Iris and Highlight.
-- These components are used to composite a complete image for the eyes.
--
-- First Iris is translated by some small amount to make the eye look in a direction, it is then multiplicatively
-- masked by ScleraStencil to have it fit inside the eye. After that Highlight is stencil masked by the translated Iris
-- and all of these are composited with EyeTexture to create the eye. All the components should be in correct orientation
-- for the right eye, when compositing the left eye, all components excluding Highlight are flipped, care should be taken
-- for the component images to be centred in the middle for this flip to look correct.
--
-- If alternative irises and highlights are wanted, each eye pose can have alternative textures given, as long as these
-- alternative textures have the same dimensions.
--
--]]
--

EyesData = {__type = "eyesdata"}
EyesData.__index = EyesData

function EyesData:new(props)
	local this = {
		props = EyesDataPropPrototype(props),

		buffer = nil,
		buffer2 = nil
	}

	setmetatable(this,EyesData)
	this:allocateCanvases()
	this:generateComponentTextures()

	return this
end

function EyesData:fromCfg(eyes_name)
	local atts = eye_attributes[eyes_name]

	if not atts then
		error(string.format("EyesData:fromCfg: [\"%s\"] not found in cfg/eyes.lua", eyes_name))
	end

	local fname = atts.eyes_filename
	return self:openFilename(fname, atts)
end

function EyesData:openFilename(fname, props)
	local source_image = Textures.rawLoadTexture(fname)

	if not source_image then
		print(string.format("EyesData:openFilename(): image file \"%s\" not found", fname))
		return nil
	end

	props.eyes_source = source_image

	local source_w, source_h = source_image:getDimensions()
	local dim = props.eyes_dimensions
	local w,h = dim[1],dim[2]

	if source_w / dim[1] ~= 2 or source_h % dim[2] ~= 0 then
		print(string.format("EyesData:openFilename(): %s incorrect eye component dimensions (%d,%d) (%d,%d)",fname,
		  dim[1], dim[2], source_w, source_h))
		return nil
	end

	local poses_count = source_h / dim[2] - 1
	local poses_table = props.eyes_poses
	if not poses_table then
		poses_table={}
		props.eyes_poses=poses_table
	end
	props.eyes_pose_count = poses_count

	if poses_count ~= #poses_table then
		print(string.format("EyesData:openFilename(): pose count mismatch, %d found, %d given", poses_count, #poses_table)) end
	
	props.eyes_iris      = love.graphics.newQuad(0*w, 0*h, w, h, source_w, source_h)
	props.eyes_highlight = love.graphics.newQuad(1*w, 0*h, w, h, source_w, source_h)

	props.eyes_pose_map = {}
	for i=1,poses_count do
		local pose = poses_table[i]
		if not pose then
			poses_table[i] = {name="unnamed_pose"..to_string(i)}
			pose = poses_table[i]
		end

		pose.base   = love.graphics.newQuad(0*w, i*h, w, h, source_w, source_h)
		pose.sclera = love.graphics.newQuad(1*w, i*h, w, h, source_w, source_h)

		props.eyes_pose_map[pose.name] = i
		props.eyes_pose_map[i] = i
	end

	return EyesData:new(props)
end

function EyesData:allocateCanvases()
	local props = self.props
	local dim = props.eyes_dimensions
	props.eyes_left_canvas = love.graphics.newCanvas(dim[1],dim[2],{format="rgba16f"})
	props.eyes_right_canvas = love.graphics.newCanvas(dim[1],dim[2],{format="rgba16f"})
	self.buffer = love.graphics.newCanvas(dim[1],dim[2],{format="rgba16f"})
	self.buffer2 = love.graphics.newCanvas(dim[1],dim[2],{format="rgba16f"})
end

-- workin with quads ever is an absolute pain in the ass
-- takes all the component quads and renders them to a texture
function EyesData:generateComponentTextures()
	love.graphics.setShader()
	love.graphics.origin()

	local blit = function(quad, dim, img)
		local canvas = love.graphics.newCanvas(dim[1], dim[2], {format="rgba8"})
		canvas:setWrap("clampzero")
		love.graphics.setCanvas(canvas)
		love.graphics.setColor(1,1,1,1)
		love.graphics.draw(img, quad)
		love.graphics.setCanvas()
		return canvas
	end

	local dim = self.props.eyes_dimensions
	local img = self.props.eyes_source
	self.props.eyes_iris      = blit(self.props.eyes_iris, dim, img)
	self.props.eyes_highlight = blit(self.props.eyes_highlight, dim, img)
	for i,v in ipairs(self.props.eyes_poses) do
		v.base = blit(v.base, dim, img)
		v.sclera = blit(v.sclera, dim, img)
	end
end

function EyesData:release()
	local props = self.props
	props.eyes_source:release()
	props.eyes_left_canvas:release()
	props.eyes_right_canvas:release()
	self.stencil_buffer:release()
end

function EyesData:getDimensions()
	return self.props.eyes_dimensions
end
function EyesData:poseIndex(p)
	return self.props.eyes_pose_map[p]
end
function EyesData:sourceImage()
	return self.props.eyes_source
end
function EyesData:defaultIris()
	return self.props.eyes_iris
end
function EyesData:defaultHighlight()
	return self.props.eyes_highlight
end
function EyesData:getBase(pose)
	return self.props.eyes_poses[self:poseIndex(pose)].base
end
function EyesData:getSclera(pose)
	return self.props.eyes_poses[self:poseIndex(pose)].sclera
end
function EyesData:getIris(pose)
	if pose then 
		return self.props.eyes_poses[self:poseIndex(pose)].iris or self:defaultIris()
	else
		return self.props.eyes_iris
	end
end
function EyesData:getHightlight(pose)
	if pose then 
		return self.props.eyes_poses[self:poseIndex(pose)].highlight or self:defaultHighlight()
	else
		return self.props.eyes_highlight
	end
end

function EyesData:clearBuffers()
	local function clear(c)
		love.graphics.setCanvas(c)
		love.graphics.clear()
	end
	clear(self.props.eyes_right_canvas)
	clear(self.props.eyes_left_canvas)
	clear(self.buffer)
	clear(self.buffer2)
	love.graphics.setCanvas()
end

-- pose       : string name/index for eye pose
-- which_eye  : "left" or "right"
-- eye_look_v : direction vector where eye is looking, (0,0,1) is neutral
-- eye_radius : radius of eye in pixels, used to get a correct iris look translation
function EyesData:composite(pose, which_eye, eye_look_v, eye_radius)
	local source    = self:sourceImage()
	local iris      = self:getIris(pose)
	local highlight = self:getHightlight(pose)
	local base      = self:getBase(pose)
	local sclera    = self:getSclera(pose)
	local look_v    = {eye_look_v[1], eye_look_v[2], eye_look_v[3]}
	local eye_r     = eye_radius or self.props.eyes_radius
	local dim       = self:getDimensions()
	local max_look  = self.props.eyes_look_max

	if look_v[3] == 0 then look_v[3] = 0 end
	look_v[1] = look_v[1] * (eye_r / look_v[3])
	look_v[2] = look_v[2] * (eye_r / look_v[3])

	local dist = math.sqrt(look_v[1]*look_v[1] + look_v[2]*look_v[2])
	if dist ~= 0 and dist > max_look then
		look_v[1] = max_look * look_v[1]/dist
		look_v[2] = max_look * look_v[2]/dist
	end

	look_v[1] = look_v[1] / dim[1]
	look_v[2] = look_v[2] / dim[2]

	-- TODO implement maximum eyelook locking

	local canvas = nil
	if which_eye == "right" then
		 canvas = self.props.eyes_right_canvas
	else canvas = self.props.eyes_left_canvas end

	local flip_flag = which_eye == "left"

	local mask_sh = Renderer.mask_shader
	love.graphics.origin()
	love.graphics.setColor(1,1,1,1)

	-- we draw the iris multiplicatively masked by sclera to self.buffer
	love.graphics.setCanvas(self.buffer)
	love.graphics.setShader(mask_sh)
	mask_sh:send("multiplicative_mask", true)
	mask_sh:send("mask", sclera)
	mask_sh:send("uv_translate", {look_v[1], look_v[2]})
	mask_sh:send("flip_x", flip_flag)
	mask_sh:send("flip_y", false)
	love.graphics.draw(iris)

	-- we draw the highlight alpha masked by iris to self.buffer2
	love.graphics.setCanvas(self.buffer2)
	love.graphics.setShader(mask_sh)
	mask_sh:send("multiplicative_mask", false)
	mask_sh:send("mask", self.buffer)
	mask_sh:send("uv_translate", {look_v[1]/10,look_v[2]/10})
	mask_sh:send("flip_x", false)
	mask_sh:send("flip_y", false)
	love.graphics.draw(highlight)

	love.graphics.setShader()
	love.graphics.setCanvas(canvas)
	if flip_flag then
		love.graphics.draw(base, dim[1], 0, 0, -1, 1)
	else
		love.graphics.draw(base)
	end
	love.graphics.draw(self.buffer)
	love.graphics.draw(self.buffer2)

	love.graphics.setCanvas()
	love.graphics.setShader()
	return canvas
end
