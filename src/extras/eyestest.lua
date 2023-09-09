EYETESTMODE = {
}
EYETESTMODE.__index = EYETESTMODE

function EYETESTMODE:load( args )
	EYETESTMODE.testeyes = EyesData:openFilename("models/pianko/eyes.png",
	 {
	  eyes_dimensions = {32,32},
	  eyes_radius = 12,
	  eyes_poses = {
	   {name="neutral"},
	   {name="close_phase1"},
	   {name="close_phase2"},
	   {name="close_phase3"}
	  }
	 }
	 )
end

function EYETESTMODE:update( dt )

end

function EYETESTMODE:draw()
	--love.graphics.draw(
	--	testeyes:sourceImage(),
	--	testeyes:getIris()
	--)
	love.graphics.setCanvas()
	love.graphics.clear(240/255.0, 236/255.0, 209/255.0)
	love.graphics.setColor(1,1,1,1)
	--love.graphics.draw(
	--	testeyes:sourceImage()
	--)
	--love.graphics.draw(
	--	testeyes:sourceImage(),
	--	testeyes:getSclera(1))
	--love.graphics.origin()

	self.testeyes:clearBuffers()

	local poselist = {"neutral", "close_phase1", "close_phase2", "close_phase3", "close_phase2", "close_phase1", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral"
	 }
	local pose = poselist[(math.floor(love.timer.getTime()*30) % #poselist) + 1]

	local dirx,diry = love.mouse.getPosition()
	local right_composite = self.testeyes:composite(pose, "right", {dirx/100-4,diry/100-4,3})
	local left_composite = self.testeyes:composite(pose, "left", {dirx/100-4,diry/100-4,3})
	love.graphics.scale(5)
	love.graphics.setColor(1,1,1,1)
	love.graphics.draw(right_composite, 32, 32)
	love.graphics.draw(left_composite, 80, 32)
	love.graphics.origin()
end
