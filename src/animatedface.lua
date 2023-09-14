require "props.animatedface"
require "facialfeatures"
require "tick"

AnimFace = {__type = "animface"}
AnimFace.__index = AnimFace

function AnimFace:new(props)
	local this = {
		props = AnimFacePropPrototype(props),
		frame_rate = periodicUpdate(2.5),
		first_composite = true
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

function AnimFace:composite()
	local props = self.props
	local texture = self:getTexture()

	if not self.first_composite and not self.frame_rate() then
		return texture
	end	
	self.first_composite = false

	--prof.push("setup_clearbuffers")
	love.graphics.setShader()

	love.graphics.setCanvas(texture)
	love.graphics.clear(0,0,0,0)
	love.graphics.origin()
	love.graphics.setColor(1,1,1,1)

	local eyedata = props.animface_eyesdata
	eyedata:clearBuffers()
	--prof.pop("setup_clearbuffers")

	prof.push("eyes_composite")
	local righteye_pos = props.animface_righteye_position
	local righteye = eyedata:composite(props.animface_righteye_pose,
	                                   "right", props.animface_righteye_dir,
									   eyedata.props.eyes_radius,
									   righteye_pos[1], righteye_pos[2], texture)

	local lefteye_pos = props.animface_lefteye_position
	local lefteye = eyedata:composite(props.animface_lefteye_pose,
	                                   "left", props.animface_lefteye_dir,
									   eyedata.props.eyes_radius,
									   lefteye_pos[1], lefteye_pos[2], texture)
	prof.pop("eyes_composite")

	--love.graphics.setCanvas()
	return texture
end

function AnimFace:pushComposite()
	self.first_composite = false
	local texture = self:composite()
	self.props.animface_decor_reference:getModel():getMesh().mesh:setTexture(texture)
end

function AnimFace:pushTexture()
	local texture = self:getTexture()
	self.props.animface_decor_reference:getModel():getMesh().mesh:setTexture(texture)
end
