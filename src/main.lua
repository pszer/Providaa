require "gamestate"
require "render"

function love.load()
	love.graphics.setDefaultFilter( "linear", "nearest" )
	CAM:createCanvas()

	love.graphics.setMeshCullMode( "front" )
	SET_GAMESTATE(PROV)
end

function love.update(dt)
	GAMESTATE:update(dt)
end

function love.draw()
	GAMESTATE:draw()
end

function love.resize( w,h )
	update_resolution_ratio( w,h )
	CAM:createCanvas()
end
