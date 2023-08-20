require "gamestate"
require "render"

local profiler = require "profiler"

function love.load()
	love.graphics.setDefaultFilter( "nearest", "nearest" )
	CAM:createCanvas()

	--profiler.start()
	SET_GAMESTATE(PROV)
end

counter=0
frames=0
function love.update(dt)
	GAMESTATE:update(dt)

	counter = counter + dt
	frames=frames+1
	if (counter > 1.0) then
		print(frames)
		frames=0
		counter = 0
	end
end

function love.draw()
	GAMESTATE:draw()
end

function love.resize( w,h )
	update_resolution_ratio( w,h )
	CAM:createCanvas()
end

function love.quit()
	--profiler.stop()
end
