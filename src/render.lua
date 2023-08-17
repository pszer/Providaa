require 'math'

require "camera"
require "resolution"
require "3d"

CAM = Camera:new()

function renderScaled(can)
	local canvas = can or CAM.props.cam_viewport
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

function render_viewport()
	local canvas = CAM.props.cam_viewport
	local w,h = CAM:getViewportCoords()

	CAM:transformCoords2()
	CAM:setupCanvas()

	love.graphics.clear(0,0,0)
	love.graphics.setColor(1,1,1,1)

	local a,b = CAM:map3DCoords(-1,-1)
	local c,d = CAM:map3DCoords(2,2)
	local e,f = CAM:map3DCoords(1,1)
	love.graphics.rectangle("line",a,b,c,d)
	love.graphics.line(a,b,-a,-b)
	love.graphics.line(a,-b,-a,b)

	renderScaled()
end
