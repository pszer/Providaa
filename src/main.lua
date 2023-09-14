require "gamestate"
require "render"
require "console"

local o_ten_one = require "o-ten-one"
local limit = require "syslimits"

PROF_CAPTURE = false
prof = require("jprof") 

local function __print_info()
	print(limit.sysInfoString())
	print(string.format("Save directory: %s", love.filesystem.getSaveDirectory()))
end

local cpml = require 'cpml'

function love.load( args )
	__print_info()
	getRefreshRate()

	local testchannel = love.thread.newChannel()
	testchannel:push(cpml.mat4.new(1))

	Renderer.load()

	Textures.loadTextures()
	Textures.generateMissingTexture()
	Models.loadModels()

	SPLASH_SCREEN = o_ten_one{background={0,0,0,1}, delay_before=0.0 }
	SPLASH_SCREEN.onDone = function() SET_GAMESTATE(Prov) end
	--SPLASH_SCREEN.onDone = function() SET_GAMESTATE(EYETESTMODE) end
	SET_GAMESTATE(SPLASH_SCREEN)
end

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0

	-- Main loop time.
	return function()
		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end

		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end

		-- Call update and draw
		if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())

			if love.draw then love.draw() end

			love.graphics.present()
		end

		local diff = (1/400 - dt)
		if love.timer and diff>0.0 and diff > 0.001 then love.timer.sleep(diff) end
		--if love.timer then love.timer.sleep(0.001) end
	end
end

local FRAMES=0
local TIMER_START=0
function __updateFramesCounter()
	FRAMES=FRAMES+1
	if (love.timer.getTime() - TIMER_START > 1.0) then
		TIMER_START = love.timer.getTime()
		--FPS = FRAMES
		FRAMES=0
	end
end

function __limitFPS( limit , dt )
	local limit = limit or 0
	if limit > 0 then
		local diff = (1/limit) - dt

		local start_time = love.timer.getTime()
		if diff > 0.0 then
			love.timer.sleep(diff)
			print("slept")
		else
			print("not slept")
		end
		local time_slept = love.timer.getTime() - start_time

		print("fps should be", 1/(dt+time_slept))
	end
end

function love.update(dt)
	prof.push("frame")
	prof.push("update")

	stepTick(dt)

	prof.push("gamestate_update")
	GAMESTATE:update(dt)
	prof.pop("gamestate_update")
	prof.push("updateKeys")
	updateKeys()
	prof.pop("updateKeys")

	FPS = love.timer.getFPS()
	__updateFramesCounter()

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
