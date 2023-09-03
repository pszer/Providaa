local TICK = 0
local TICK_CHANGED = false
local tick_dt_counter = 0
local tick_rate = 60
local tick_rate_inv = 1/tick_rate

FPS = 0
FPS_LIMIT = 0

function getTick()
	return TICK
end

function getTickSmooth()
	return TICK + tick_dt_counter/tick_rate_inv
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
