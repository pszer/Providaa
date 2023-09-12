-- hook constructor functions used by providaa.lua
--

require "event"

function __provhooks_controlHook(prov, ent, info)
	local handler   = info.handler
	local keybind   = info.keybind
	local event     = info.event
	local hook_func = info.hook_func

	if not (handler and keybind and event and hook_func) then
		error("__provhooks_controlHook: received incomplete information")
	end

	local func = hook_func(ent)
	if not func or type(func) ~= "function" then
		error(string.format("__provhooks_controlHook: hook_func(ent) is expected to be return a function, got %s", type(func)))
	end

	local the_handler = prov:getInputHandler(handler)
	if not the_handler then
		print(string.format("__provhooks_controlHook: missed! no instance of InputHandler %s was found", handler))
		return nil
	end

	local the_event = the_handler:getEvent(keybind, event)
	if not the_event then
		print(string.format("__provhooks_controlHook: missed! no event %s.%s.%s found", handler,keybind,event))
		return nil
	end

	local hook = Hook:new(func)
	the_event:addHook(hook)
	return hook
end
