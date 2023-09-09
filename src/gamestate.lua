require "providaa"

require "extras/eyestest"

GAMESTATE = {}

function SET_GAMESTATE(gs, args)
	GAMESTATE = gs
	if gs.load then
		gs:load(args)
	end
end
