require "props.animatedface"
require "facialfeatures"

AnimFace = {__type = "animface"}
AnimFace.__index = AnimFace

function AnimFace:new(props)
	local this = {
		props = AnimFacePropPrototype(props),
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

	love.graphics.setShader()

	love.graphics.setCanvas(texture)
	love.graphics.clear(0,0,0,0)
	love.graphics.origin()
	love.graphics.setColor(1,1,1,1)

	local eyedata = props.animface_eyesdata
	eyedata:clearBuffers()

	local righteye_pos = props.animface_righteye_position
	local righteye = eyedata:composite(props.animface_righteye_pose,
	                                   "right", props.animface_righteye_dir)
	love.graphics.setCanvas(texture)
	love.graphics.setColor(1,1,1,1)
	love.graphics.draw(righteye, righteye_pos[1], righteye_pos[2])

	local lefteye_pos = props.animface_lefteye_position
	local lefteye = eyedata:composite(props.animface_lefteye_pose,
	                                   "left", props.animface_lefteye_dir)
	love.graphics.setCanvas(texture)
	love.graphics.setColor(1,1,1,1)
	love.graphics.draw(lefteye, lefteye_pos[1], lefteye_pos[2])

	love.graphics.setCanvas()
	return texture
end

function AnimFace:pushComposite()
	local texture = self:composite()
	local mesh = self.props.animface_decor_reference:getModel():getMesh().mesh:setTexture(texture)
end
