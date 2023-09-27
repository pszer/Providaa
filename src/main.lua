require "gamestate"
require "render"
require "console"
require "assetloader"
--require "mapedit"

local o_ten_one = require "o-ten-one"
local limit = require "syslimits"

PROF_CAPTURE = false
prof = require("jprof") 

local function __print_info()
	print(limit.sysInfoString())
	print("---------------------------------------------------------")
	print(string.format("Save directory: %s", love.filesystem.getSaveDirectory()))
	print("---------------------------------------------------------")
end

function __parse_args( commandline_args )
	local params = {}
	for i,v in ipairs(commandline_args) do
		local eq_pos = string.find(v, '=')
		local com_pos = {}
		if eq_pos then
			for arg in string.gmatch(string.sub(v,eq_pos+1,-1), "[^,%s]+") do
				table.insert(com_pos, arg)
			end
			params[string.sub(v,1,eq_pos-1)] = com_pos
		end
	end
	return params
end

function love.load( args )
	local gamestate_on_launch = Prov
	local params = __parse_args(args)

	local arg_coms = {
	 ["lvledit"] = function(args)
	 	local mapname = args[1]
		assert(mapname,"launch command lvledit expects a map name")
		require "mapedit"
		gamestate_on_launch = ProvMapEdit
		end
	}
	for param,args in pairs(params) do
		local com = arg_coms[param]
		if not com then error(string.format("unrecognised launch parameter %s",tostring(param))) end
		com(args)
	end

	__print_info()
	getRefreshRate()

	Renderer.load()
	Loader:initThread()

	SPLASH_SCREEN = o_ten_one{background={0,0,0,1}, delay_before=0.0 }
	SPLASH_SCREEN.onDone = function() SET_GAMESTATE(gamestate_on_launch, params) end
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
		--if sleep_acc > 0.0025 then
		if sleep_acc > 0.0018 then
			sleep_acc = 0
			if love.timer then love.timer.sleep(0.001) end
		end
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

	if GAMESTATE.resize then GAMESTATE:resize(w,h) end
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
	if GAMESTATE.keypressed then GAMESTATE:keypressed(t) end
end

function love.keyreleased(key, scancode)
	__keyreleased(key, scancode)
	if GAMESTATE.keyreleased then GAMESTATE:keyreleased(t) end
end

function love.mousepressed(x, y, button, istouch, presses)
	__mousepressed(x, y, button, istouch, presses)
	if GAMESTATE.mousepressed then GAMESTATE:mousepressed(t) end
end

function love.mousereleased(x, y, button, istouch, presses)
	__mousereleased(x, y, button, istouch, presses)
	if GAMESTATE.mousereleased then GAMESTATE:mousereleased(t) end
end

function love.mousemoved(x,y,dx,dy,istouch)
	if GAMESTATE.mousemoved then GAMESTATE:mousemoved(x,y,dx,dy,istouch) end
end

function love.wheelmoved(x,y)
	__wheelmoved(x,y)
	if GAMESTATE.wheelmoved then GAMESTATE:wheelmoved(x,y) end
end

function love.textinput(t)
	if Console.isOpen() then
		Console.textinput(t)
	else
		if GAMESTATE.textinput then GAMESTATE:textinput(t) end
	end
end
