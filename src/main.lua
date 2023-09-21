require "gamestate"
require "render"
require "console"
require "assetloader"

local o_ten_one = require "o-ten-one"
local limit = require "syslimits"

PROF_CAPTURE = false
prof = require("jprof") 

local function __print_info()
	print(limit.sysInfoString())
	print(string.format("Save directory: %s", love.filesystem.getSaveDirectory()))
end

function __parse_args( commandline_args )
	local params = {}
	for i,v in ipairs(commandline_args) do
		local eq_pos = string.find(v, '=')
		if eq_pos then
			local com_pos = {}
			for arg in string.gmatch(string.sub(v,eq_pos+1,-1), "[^,%s]+") do
				table.insert(com_pos, arg)
			end
		end
		params[v] = com_pos
	end
	return params
end

function love.load( args )
	local gamestate_on_launch = Prov
	local params = __parse_args(args)

	local arg_coms = {
	 ["mapedit"] = function(args)
	 	local mapname = args[1]
		assert(mapname,"launch command mapedit expects a map name")
		end
	}

	__print_info()
	getRefreshRate()

	Renderer.load()
	Loader:initThread()

	SPLASH_SCREEN = o_ten_one{background={0,0,0,1}, delay_before=0.0 }
	SPLASH_SCREEN.onDone = function() SET_GAMESTATE(gamestate_on_launch) end
	SET_GAMESTATE(SPLASH_SCREEN)
end

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local dt = 0
	local update_dt_acc = 0
	local max_updates_in_frame = 3
	local sleep_acc = 0

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

		update_dt_acc = update_dt_acc + dt

		prof.push("frame")
		if love.update then love.update( dt ) end -- will pass 0 if love.timer is disabled

		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())

			if love.draw then love.draw() end

			prof.push("present")
			love.graphics.present()
			prof.pop("present")
		end
		prof.pop("frame")

		sleep_acc = sleep_acc + dt
		if sleep_acc > 0.003 then
			sleep_acc = 0
			if love.timer then love.timer.sleep(0.001) end
		end
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
		end
		local time_slept = love.timer.getTime() - start_time
	end
end

function love.update(dt)
	prof.push("update")

	stepTick(dt)

	prof.push("gamestate_update")
	GAMESTATE:update(dt)
	prof.pop("gamestate_update")
	updateKeys()

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
