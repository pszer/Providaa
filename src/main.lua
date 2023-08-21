require "gamestate"
require "render"
require "console"

local profiler = require "profiler"

function love.load()
	love.graphics.setDefaultFilter( "nearest", "nearest" )
	Renderer.loadShaders()
	Renderer.createCanvas()
	Renderer.setupSkyboxModel()

	Textures.loadTextures()
	Textures.generateMissingTexture()
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
		FPS = frames
		frames=0
		counter = 0
	end
end

function love.draw()
	GAMESTATE:draw()

	if Console.isOpen() then Console.draw() end
	Renderer.drawFPS()
end

function love.resize( w,h )
	update_resolution_ratio( w,h )
	Renderer.createCanvas()
end

function love.quit()
	--profiler.stop()
end

function love.keypressed(key)
	if Console.isOpen() then
		Console.keypressed(key)
	end

	if key == "f8" then
		Console.open()
	end
end

function love.textinput(t)
	if Console.isOpen() then
		Console.textinput(t)
	end
end
