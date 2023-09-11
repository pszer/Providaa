require "gamestate"
require "render"
require "console"

local o_ten_one = require "o-ten-one"
local limit = require "syslimits"

PROF_CAPTURE = false
prof = require("jprof") 

local function __print_info()
	print(limit.sysInfoString())
	print(love.filesystem.getSaveDirectory())
end

function love.load( args )
	__print_info()

	Renderer.load()

	Textures.loadTextures()
	Textures.generateMissingTexture()
	Models.loadModels()

	SPLASH_SCREEN = o_ten_one()
	SPLASH_SCREEN.onDone = function() SET_GAMESTATE(Prov) end
	--SPLASH_SCREEN.onDone = function() SET_GAMESTATE(EYETESTMODE) end
	SET_GAMESTATE(SPLASH_SCREEN)
end

local DT_COUNTER=0
local FRAMES=0
local TIMER_START=0
function love.update(dt)
	--prof.enabled(not PROFILE_DRAW)
	prof.push("frame")
	prof.push("update")

	GAMESTATE:update(dt)

	DT_COUNTER = DT_COUNTER + dt
	FRAMES=FRAMES+1
	--if (DT_COUNTER > 1.0) then
	if (love.timer.getTime() - TIMER_START > 1.0) then
		TIMER_START = love.timer.getTime()
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

	updateKeys()

	prof.pop("update")
end

function love.draw()
	prof.push("draw")

	GAMESTATE:draw()

	if Console.isOpen() then Console.draw() end
	Renderer.drawFPS()

	prof.pop("draw")
	prof.pop("frame")
end

function love.resize( w,h )
	update_resolution_ratio( w,h )
	Renderer.createCanvas()
end

function love.quit()
	prof.write("prof.mpack")
end

function love.keypressed(key, scancode, isrepeat)
	SPLASH_SCREEN:skip()

	__keypressed(key, scancode, isrepeat)

	if Console.isOpen() then
		Console.keypressed(key)
	end

	if key == "f8" then
		Console.open()
	end
end

function love.keyreleased(key, scancode)
	__keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
	__mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
	__mousereleased(x, y, button, istouch, presses)
end

function love.textinput(t)
	if Console.isOpen() then
		Console.textinput(t)
	end
end
