require "texturemanager"
require "assetloader"
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
	}

	setmetatable(this,EyesData)
	this:generateComponentTextures()

	return this
end

function EyesData:release()
	local source = self:sourceImage()
	if source then
		Loader:deref("texture", self.props.eyes_filename) end
	self:releaseComponentTextures()
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
	--local source_image = Textures.rawLoadTexture(fname)
	local source_image = Loader:getTextureReference(fname)

	if not source_image then
		error(string.format("EyesData:openFilename(): image file \"%s\" not found", fname))
		return nil
	end

	props.eyes_source = source_image

	local source_w, source_h = source_image:getDimensions()
	local dim = props.eyes_dimensions
	local w,h = dim[1],dim[2]

	if source_w / dim[1] ~= 2 or source_h % dim[2] ~= 0 then
		error(string.format("EyesData:openFilename(): %s incorrect eye component dimensions (%d,%d) (%d,%d)",fname,
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
	--self.buffer = love.graphics.newCanvas(dim[1],dim[2],{format="rgba8"})
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

function EyesData:releaseComponentTextures()
	for i,v in ipairs(self.props.eyes_poses) do
		if v.base then v.base:release() end
		if v.sclera then v.sclera:release() end
	end
	local iris,highlight = self.props.eyes_iris, self.props.eyes_highlight
	if iris then iris:release() end
	if highlight then highlight:release() end
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

-- which_eye  : "left" or "right"
-- eye_look_v : direction vector where eye is looking, (0,0,1) is neutral
-- eye_radius : radius of eye in pixels, used to get a correct iris look translation
local __temp_lookv = {0,0,0}
local __temp_lvec2  = {0,0}
local __temp_rvec2  = {0,0}
local __temp_uvrect = {0,0,0,0}
function EyesData:pushEyeDataToShader(shader, pose, which_eye, eye_look_v, eye_radius, posx, posy, destw, desth)
	local iris      = self:getIris(pose)
	local highlight = self:getHightlight(pose)
	local base      = self:getBase(pose)
	local sclera    = self:getSclera(pose)

	local look_v    = __temp_lookv
	--local look_v    = {eye_look_v[1], eye_look_v[2], eye_look_v[3]}
	look_v[1],look_v[2],look_v[3] = eye_look_v[1],eye_look_v[2],eye_look_v[3]

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

	local uv_rect = __temp_uvrect
	uv_rect[1],uv_rect[2],uv_rect[3],uv_rect[4] =
	 posx   / destw, posy   / desth,
	 dim[1] / destw, dim[2] / desth

	if which_eye == "left" then
		__temp_lvec2 = {look_v[1], look_v[2]}
		shader:send("leye_uv_translate", __temp_lvec2)
		shader:send("leye_sclera_mask", sclera)
		shader:send("leye_base_img", base)
		shader:send("leye_iris_img", iris)
		shader:send("leye_highlight_img", highlight)
		shader:send("leye_pos", uv_rect)
	else
		__temp_rvec2 = {look_v[1], look_v[2]}
		shader:send("reye_uv_translate", __temp_rvec2)
		shader:send("reye_sclera_mask", sclera)
		shader:send("reye_base_img", base)
		shader:send("reye_iris_img", iris)
		shader:send("reye_highlight_img", highlight)
		shader:send("reye_pos", uv_rect)
	end
end

FacialFeatureData = {}
FacialFeatureData.__index = FacialFeatureData

function FacialFeatureData:new(props)
	local this = {
		props = FacialFeaturePropPrototype(props),
	}

	setmetatable(this,FacialFeatureData)
	this:generateQuads()

	return this
end

function FacialFeatureData:release()
	local source = self:sourceImage()
	if source then
		Loader:deref("texture", self.props.feature_filename) end
	for i,v in pairs(self.props.feature_pose_map) do
		v:release()
	end
end

function FacialFeatureData:fromCfg(feature_name)
	local atts = feature_attributes[feature_name]

	if not atts then
		error(string.format("FacialFeatureData:fromCfg: [\"%s\"] not found in cfg/features.lua", feature_name))
	end

	local fname = atts.feature_filename
	return self:openFilename(fname, atts)
end

function FacialFeatureData:openFilename(fname, props)
	local source_image = Loader:getTextureReference(fname)

	if not source_image then
		error(string.format("FacialFeatureData:openFilename(): image file \"%s\" not found", fname))
		return nil
	end

	props.feature_source = source_image

	local source_w, source_h = source_image:getDimensions()
	local dim = props.feature_dimensions
	local w,h = dim[1],dim[2]

	if source_w / dim[1] ~= 1 or source_h % dim[2] ~= 0 then
		error(string.format("FacialFeatureData:openFilename(): %s incorrect feature component dimensions (%d,%d) (%d,%d)",fname,
		  dim[1], dim[2], source_w, source_h))
		return nil
	end

	local poses_count = source_h / dim[2]
	local poses_table = props.feature_poses
	if not poses_table then
		poses_table={}
		props.feature_poses=poses_table
	end
	props.feature_pose_count = poses_count

	if poses_count ~= #poses_table then
		print(string.format("FacialFeatureData:openFilename(): pose count mismatch, %d found, %d given", poses_count, #poses_table)) end
	

	props.feature_pose_map = {}
	for i=1,poses_count do
		local pose = poses_table[i]
		if not pose then
			pose = "unnamed_pose"..to_string(i)
		end

		local quad = love.graphics.newQuad(0,i*(h-1),w,h, source_w, source_h)

		props.eyes_pose_map[pose] = i
		props.eyes_pose_map[i] = pose
	end

	return FacialFeatureData:new(props)
end
