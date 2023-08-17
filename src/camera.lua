require "resolution"

require "props/cameraprops"

Camera = {__type = "camera"}
Camera.__index = Camera

function Camera:new(props)
	local this = {
		props = CameraPropPrototype(props),

		__viewport_w_half=0,
		__viewport_h_half=0
	}

	setmetatable(this,Camera)
	this:setupCanvas()

	return this
end

function Camera:createCanvas()
	local w,h = get_resolution()
	local props = self.props

	if props.cam_viewport then props.cam_viewport:release() end
	props.cam_viewport = love.graphics.newCanvas(w,h)
	props.cam_viewport_w = w
	props.cam_viewport_h = h
	self.__viewport_w_half = w/2
	self.__viewport_h_half = h/2

end

function Camera:transformCoords()
	local w,h = self.props.cam_viewport_w, self.props.cam_viewport_h
	love.graphics.origin()
	love.graphics.translate(w/2,h/2)
end

function Camera:transformCoords2()
	local w,h = self.props.cam_viewport_w, self.props.cam_viewport_h
	love.graphics.origin()
	love.graphics.scale(w/2,h/2)
	love.graphics.translate(1,1)
end

function Camera:setupCanvas()
	love.graphics.setCanvas(self.props.cam_viewport)
	love.graphics.origin()
	self:transformCoords()
end

function Camera:dropCanvas()
	love.graphics.setCanvas()
	love.graphics.origin()
end

function Camera:getViewportCoords()
	return self.__viewport_w_half, self.__viewport_h_half
end

function Camera:map3DCoords(x,y)
	if RESOLUTION_ASPECT == "16:9" then
		return x*self.__viewport_w_half,
		       y*self.__viewport_h_half
	else
		return x*self.__viewport_w_half * 0.875,
		       y*self.__viewport_h_half
	end
end
