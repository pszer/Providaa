TESTMODE = {
}
TESTMODE.__index = TESTMODE

function TESTMODE:load()
	testeyes = EyesData:openFilename("models/pianko/eyes.png",
	 {
	  eyes_dimensions = {32,32},
	  eyes_poses = {
	   {name="neutral"},
	   {name="close_phase1"},
	   {name="close_phase2"},
	   {name="close_phase3"}
	  }
	 })
end

function TESTMODE:update( dt )

end

function TESTMODE:draw()

end
