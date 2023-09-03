require "providaa"

GAMESTATE = {}

function SET_GAMESTATE(gs)
	GAMESTATE = gs
	if gs.load then
		gs:load()
	end
end
