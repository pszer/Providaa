require "gamestate"
require "render"
require "console"

local o_ten_one = require "o-ten-one"

local profiler = require "profiler"

function love.load()
 	local major, minor, revision, codename = love.getVersion( )
	local str = string.format("Version %d.%d.%d - %s", major, minor, revision, codename)
	print(str)

	love.graphics.setDefaultFilter( "nearest", "nearest" )
	Renderer.loadShaders()
	Renderer.createCanvas()
	Renderer.setupSkyboxModel()

	Textures.loadTextures()
	Textures.generateMissingTexture()
	Models.loadModels()

	SPLASH_SCREEN = o_ten_one()
	SPLASH_SCREEN.onDone = function() SET_GAMESTATE(PROV) end
	SET_GAMESTATE(SPLASH_SCREEN)
	--SET_GAMESTATE(PROV)
end

local DT_COUNTER=0
local FRAMES=0
function love.update(dt)
	GAMESTATE:update(dt)

	DT_COUNTER = DT_COUNTER + dt
	FRAMES=FRAMES+1
	if (DT_COUNTER > 1.0) then
		FPS = FRAMES
		FRAMES=0
		DT_COUNTER = 0
	end

	if FPS_LIMIT > 0 then
		local diff = (1/FPS_LIMIT) - dt

		local start_time = love.timer.getTime()
		if diff > 0.0 then
			love.timer.sleep(diff)
		end
		local time_slept = love.timer.getTime() - start_time
		DT_COUNTER = DT_COUNTER + time_slept
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
	--profiler.report("prof.log")
end

function love.keypressed(key)
	SPLASH_SCREEN:skip()

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
