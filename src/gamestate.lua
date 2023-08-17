require "providaa"

GAMESTATE = {}

function SET_GAMESTATE(gs)
	GAMESTATE = gs
	gs:load()
end
