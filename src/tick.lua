local TICK = 0
local TICK_CHANGED = false
local tick_dt_counter = 0
local tick_rate = 60
local tick_rate_inv = 1/tick_rate

FPS = 0
FPS_LIMIT = 0
REFRESH_RATE = 60

function getTick()
	return TICK
end

function getRefreshRate()
	local w,h,flags = love.window.getMode()

	local rate = flags.refreshrate
	if rate > 0 then
		print(string.format("getRefreshRate: Refresh rate is %dHz", rate))
	else
		rate = 60
		print("getRefreshRate: Cannot determine refresh rate, falling back to 60Hz")
	end

	REFRESH_RATE = rate
	return rate
end

function getTickSmooth()
	return TICK + tick_dt_counter * tick_rate
end

function setTick(i)
	TICK = i
end

function stepTick(dt)
	TICK_CHANGED = false
	tick_dt_counter = tick_dt_counter + dt

	if (tick_dt_counter > tick_rate_inv) then
		TICK_CHANGED = true

		TICK = TICK + 1
		tick_dt_counter = tick_dt_counter - tick_rate_inv
	end
end

function tickChanged()
	return TICK_CHANGED
end

function tickRate()
	return tick_rate
end

--
-- Helper function in tick limiting code
-- e.g. only calc new lightspace matrices every tick instead of every frame
--
function periodicUpdate(delay)
	--local timer_start = getTickSmooth()
	local timer_start = -100000000.0
	local delay = delay
	return function()
		local t = getTickSmooth()
		if t - timer_start > delay then
			timer_start = t
			return true
		end
		return false
	end
end
