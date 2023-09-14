local clone = require 'clone'

EYES_ATTRIBUTES = {

	["pianko_eyes"] = {
		eyes_filename = "models/pianko/eyes.png",
		eyes_dimensions = {32,32},
		eyes_radius = 12,
		eyes_poses = {
			{name="neutral"},
			{name="close_phase1"},
			{name="close_phase2"},
			{name="close_phase3"}
	  }
	 }
}

return EYES_ATTRIBUTES
