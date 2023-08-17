--[[ ingame key/mouse inputs should be queried through here
--]]
--

--[[
-- When inputs are to be queried, they are queried at some control lock level.
-- Control locks can be opened/closed, if a control lock is closed
-- all queries at that control lock level will be blocked (false). When
-- control locks are open, only queries for the highest priority lock are
-- enabled. All control locks are placed at unique priority levels.
--
-- This means that controls are only read by one part of the game at a time, e.g.
-- if an inventory menu is opened inputs for character movement which is at a lower
-- priority is blocked.
--
-- A control lock can be forced open to read inputs even if higher priority locks
-- are open. It will be skipped in checking priority for other open locks.
-- A control lock can be given elevated priority to block inputs to all other locks
--
--]]

--[[
-- Use:
--
-- CONTROL_LOCK.lockname() returns if lockname is enabled
--
-- these functions change a locks status
-- CONTROL_LOCK.lockname.Close()
-- CONTROL_LOCK.lockname.Open()
-- CONTROL_LOCK.lockname.ForceOpen()
-- CONTROL_LOCK.lockname.Elevate()
--
--]]

require 'table'

require "timer"
require "keybinds"

-- lower priority number = higher priority
--
-- status
-- 0 = closed
-- 1 = opened
-- 2 = forced open
-- 3 = elevated priority
--
CONTROL_LOCK = {
--              priority | status
	CONSOLE     = {0,        0},

	TOPMENU     = {5,        0},
	MENU4       = {6,        0},
	MENU3       = {7,        0},
	MENU1       = {8,        0},
	MENU1       = {9,        0},

	INGAMETEXT  = {100,      0},
	INGAME      = {101,      0}
}

-- if additional control locks are needed only add them through this
-- ensures priorities dont clash and correct metatables are set
function ADD_CONTROL_LOCK(name, priority)
	for _,lock in pairs(CONTROL_LOCK) do
		if priority == lock[1] then
			print("Failed adding control lock " .. name .. ". Priority level " .. priority
			      .. " already exists")
			return
		end
	end
	CONTROL_LOCK[name] = {priority, 0}
	setmetatable(CONTROL_LOCK, CONTROL_LOCK_METATABLE)
end

-- metatable for each control lock in CONTROL_LOCK
CONTROL_LOCK_METATABLE = {
	Close      = function(lock) lock[2] = 0 end,
	Open       = function(lock) lock[2] = 1 end,
	ForceOpen  = function(lock) lock[2] = 2 end,
	Elevate    = function(lock) lock[2] = 3 end
}
CONTROL_LOCK_METATABLE.__index = function (lock,t)
	return function() CONTROL_LOCK_METATABLE[t](lock) end
end
CONTROL_LOCK_METATABLE.__call  = function(t)
	if t == nil then
		print("Control lock " .. lock_name .. " doesn't exist!")
		return false
	end

	-- closed
	if t[2] == 0 then
		return false
	end

	-- forced open / elevated priority
	if t[2] == 3 or t[2] == 2 then
		return true
	end

	-- open
	-- check if a higher priority lock is open
	for _,lock in pairs(CONTROL_LOCK) do
		if lock ~= t then
			-- ignore this lock if its closed/forced open
			if not (lock[2] == 0 or t[2] == 2) then

				-- if a lock has elevated priority this lock
				-- and all others are disabled
				if lock[2] == 3 then
					return false
				end

				-- if a lock with higher priority is open
				-- this lock is disabled
				if lock[2] == 1 and lock[1] < t[1] then
					return false
				end
			end
		end
	end

	return true
end
setmetatable(CONTROL_LOCK_METATABLE, CONTROL_LOCK_METATABLE)

for _,lock in pairs(CONTROL_LOCK) do
	setmetatable(lock, CONTROL_LOCK_METATABLE)
end

--[[
-- input recording system
--
-- keys that are currently being pressed are added to here using
-- callback functions. includes time information for how long a key has been
-- pressed and such
--
-- each keypress has 3 stages, the first tick where it is down, the ticks after
-- where it is held, and the tick it is released
--]]

CONTROL_KEYS_DOWN = {}

function KEY_PRESS(key, scancode, isrepeat)
	if isrepeat then return end

	CONTROL_KEYS_DOWN[scancode] = { "down" , TimerTick:new() , TimerReal:new() }
	CONTROL_KEYS_DOWN[scancode][2]:Start()
	CONTROL_KEYS_DOWN[scancode][3]:Start()
end

function KEY_RELEASE(key, scancode)
	if CONTROL_KEYS_DOWN[scancode] then
		CONTROL_KEYS_DOWN[scancode][1] = "up"
	end	
end

function UpdateKeys()
	for k,v in pairs(CONTROL_KEYS_DOWN) do
		if v[1] == "down" then
			v[1] = "held"
		elseif v[1] == "up" then
			CONTROL_KEYS_DOWN[k] = nil
		end
	end
end

-- the Love2D input callback functions
function love.keypressed(key, scancode, isrepeat)
	KEY_PRESS(key,scancode,isrepeat)
end
function love.mousepressed(x, y, button, istouch, presses)
	local m = "mouse" .. tostring(button)
	KEY_PRESS(m, m, false)
end
function love.keyreleased(key, scancode)
	KEY_RELEASE(key,scancode,isrepeat)
end
function love.mousereleased(x, y, button, istouch, presses)
	local m = "mouse" .. tostring(button)
	KEY_RELEASE(m, m, false)
end


-- Query functions
-- QueryScancode and QueryKeybind return 3 values
-- first value is either nil,"down","held" or "up"
-- second value is time held in ticks or nil
-- third value is time held in seconds or nil
function QueryScancode(scancode, lock)
	-- block query if disabled lock
	if not lock() then
		return nil,nil,nil
	end

	local k = CONTROL_KEYS_DOWN[scancode]
	if k then
		return k[1], k[2]:Time(), k[3]:Time()
	end
end

function QueryKeybind(keybind, lock)
	local scancode = KEYBINDS[keybind]
	if scancode then
		return QueryScancode(scancode, lock)
	else
		return nil,nil,nil
	end
end

