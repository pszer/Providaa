require 'math'

require "camera"
require "resolution"
require "3d"

CAM = Camera:new()

Renderer = {
	vertex_shader = love.graphics.newShader("shader/vertex.glsl")
}

Renderer.__index = Renderer

function renderScaled(cam)
	local canvas = cam or CAM.props.cam_viewport
	love.graphics.setCanvas()
	love.graphics.origin()
	love.graphics.scale(RESOLUTION_RATIO)

	local w,h = get_resolution()
	local W,H = love.graphics.getWidth() / RESOLUTION_RATIO, love.graphics.getHeight() / RESOLUTION_RATIO
	local wpad, hpad = 0,0

	if RESOLUTION_PADW then
		wpad = (W-w)/2
	else
		hpad = (H-h)/2
	end

	love.graphics.draw(canvas, wpad,hpad )
end
