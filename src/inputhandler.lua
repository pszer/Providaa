-- input handler
--

InputHandler = {__type="inputhandler"}
InputHandler.__index = InputHandler

require "input"

-- creates a new input handler
-- takes in a table of keybind aliases. for each keybind it creates
-- an event for key down, key held, key up and key pressed (which actives during both key down and key held).
--
-- it also expects a control lock level at which it operates in (see input.lua), if a different level is needed for some specific
-- keybind, its entry in keybinds should be { keybind, level }.
--
-- the events output ticktime,realtime
-- where they are the duration the key has been held in ticks and seconds respectively
function InputHandler:new( level , keybinds )
	local this = {}

	for i,v in ipairs(keybinds) do
		local keybind, k_level
		if type(v) == "string" then
			keybind, k_level = v, level
		elseif type(v) == "table" then
			keybind, k_level = v[1], v[2]
		else
			error(string.format("InputHandler:new(): unexpected argument at index %d of type %s", i, type(v)))
		end

		this[v] = {
			down  = Event:new(),
			held  = Event:new(),
			up    = Event:new(),
			press = Event:new(),

			level = k_level
		}
	end

	setmetatable(this, InputHandler)
	return this
end

function InputHandler:hookToKeybind(hook, keybind)

end

-- goes over all of its keybinds and checks their status, raising the appropiate events
local __temptable = {}
function InputHandler:poll()
	for keybind,events in pairs(self) do
		local level = events.level

		local status, ticks, realtime = queryKeybind(keybind, level)

		__temptable = {ticks, realtime}

		prof.push("raise_events")
		if status == "down" then
			events.down:raise(__temptable)

		elseif status == "held" then
			events.held:raise(__temptable)

		elseif status == "up" then
			events.up:raise(__temptable)

		end

		if status == "down" or status == "held" then
			events.press:raise(__temptable)
		end
		prof.pop("raise_events")
	end
end

function InputHandler:clearAllHooks()
	for keybind,events in pairs(self) do
		events.down:clearAllHooks()
		events.held:clearAllHooks()
		events.up:clearAllHooks()
		events.press:clearAllHooks()
	end
end

function InputHandler:getEvent(keybind, state)
	local events = self[keybind]
	if events then
		return events[state]
	end
end
