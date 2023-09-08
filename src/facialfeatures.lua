require "texturemanager"

require "props.facialfeaturesprops"

--[[
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

EyesData = {__type = "eyesdata" }
EyesData.__index = EyesData

function EyesData:new(props)
	local this = {
		props = TilePropPrototype(props),
	}

	setmetatable(this,EyesData)

	return this
end

function EyesData:openFilename(fname, props)
	local source_image = Textures.rawLoadTexture(fname)

	if not source_image then
		print(string.format("EyesData:openFilename(): image file \"%s\" not found", fname))
		return nil
	end

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

	for i=1,poses_count do
		local pose = poses_table[i]
		if not pose then
			poses_table[i] = {name="unnamed_pose"..to_string(i)}
			pose = poses_table[i]
		end

		pose.base   = love.graphics.newQuad(0*w, i*h, w, h, source_w, source_h)
		pose.sclera = love.graphics.newQuad(1*w, i*h, w, h, source_w, source_h)
	end

	return EyesData:new(props)
end
