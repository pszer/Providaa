local clone = require 'clone'

FACE_ATTRIBUTES = {

	["pianko_face"] = {
		animface_eyesdata_name = "pianko_eyes",
		animface_texture_dim   = clone{256,256},
		animface_righteye_position = clone{46,49},
		animface_lefteye_position  = clone{178,49},
		animface_righteye_pose     = "neutral",
		animface_lefteye_pose      = "neutral",
		animface_righteye_dir      = clone{0,0,12},
		animface_lefteye_dir       = clone{0,0,12}
	}
}

FACE_DECOR_ATTRIBUTES = {
	["pianko_face"] = {
		decor_name = "face",
		decor_model_name = "pianko/piankoface.iqm",
		decor_parent_bone = "Head",
		decor_position = clone{0,0,0.015},
		decor_shadow_mult = 0.45
	}
}
