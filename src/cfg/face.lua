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
		animface_lefteye_dir       = clone{0,0,12},

		animface_anims = {

			["neutral"] = {

				loop = true,
				length = 630,

				-- keyframes
				{0  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ 0,0,12}, animface_lefteye_dir = { 0,0,12}},
				{80  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ 0,0,12}, animface_lefteye_dir = { 0,0,12}},
				{89  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ 1.7,0,12}, animface_lefteye_dir = { 1.5,0,12}},

				{90+0 , animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{90+2 , animface_righteye_pose="close_phase2", animface_lefteye_pose="close_phase2",},
				{90+4 , animface_righteye_pose="close_phase3" , animface_lefteye_pose="close_phase3" ,},
				{90+6 , animface_righteye_pose="close_phase2" , animface_lefteye_pose="close_phase2" ,},
				{90+8, animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{90+10, animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,},

				{140  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ 1.5,0,12}, animface_lefteye_dir = { 1.5,0,12}},
				{150  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ -1,1,12}, animface_lefteye_dir = { -1,1,12}},
				{240  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ -1,1,12}, animface_lefteye_dir = { -1,1,12}},
				{249  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ 0,0,12}, animface_lefteye_dir = { 0,0,12}},

				{250+0 , animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{250+2 , animface_righteye_pose="close_phase2", animface_lefteye_pose="close_phase2",},
				{250+4 , animface_righteye_pose="close_phase3" , animface_lefteye_pose="close_phase3" ,},
				{250+6 , animface_righteye_pose="close_phase2" , animface_lefteye_pose="close_phase2" ,},
				{250+8, animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{250+10, animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,},

				{290  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={  0,0,12}, animface_lefteye_dir = {  0,0,12}},
				{300  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ -1,0,12}, animface_lefteye_dir = { -1,0,12}},

				{420+0 , animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{420+2 , animface_righteye_pose="close_phase2", animface_lefteye_pose="close_phase2",},
				{420+4 , animface_righteye_pose="close_phase3" , animface_lefteye_pose="close_phase3" ,},
				{420+6 , animface_righteye_pose="close_phase2" , animface_lefteye_pose="close_phase2" ,},
				{420+8, animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{420+10, animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,},
				{432+0 , animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{432+2 , animface_righteye_pose="close_phase2", animface_lefteye_pose="close_phase2",},
				{432+4 , animface_righteye_pose="close_phase3" , animface_lefteye_pose="close_phase3" ,},
				{432+6 , animface_righteye_pose="close_phase2" , animface_lefteye_pose="close_phase2" ,},
				{432+8, animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{432+10, animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,},

				{450  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ -1,0,12}, animface_lefteye_dir = { -1,0,12}},
				{460  , animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ 0,0,12}, animface_lefteye_dir = { 0,0,12}},

				{500+0 , animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{500+2 , animface_righteye_pose="close_phase2", animface_lefteye_pose="close_phase2",},
				{500+4 , animface_righteye_pose="close_phase3" , animface_lefteye_pose="close_phase3" ,},
				{500+6 , animface_righteye_pose="close_phase2" , animface_lefteye_pose="close_phase2" ,},
				{500+10, animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{500+12, animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,},

				{600+0 , animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{600+2 , animface_righteye_pose="close_phase2", animface_lefteye_pose="close_phase2",},
				{600+4 , animface_righteye_pose="close_phase3" , animface_lefteye_pose="close_phase3" ,},
				{600+6 , animface_righteye_pose="close_phase2" , animface_lefteye_pose="close_phase2" ,},
				{600+10, animface_righteye_pose="close_phase1", animface_lefteye_pose="close_phase1",},
				{600+12, animface_righteye_pose="neutral"     , animface_lefteye_pose="neutral"     ,
				      animface_righteye_dir ={ 0,0,12}, animface_lefteye_dir = { 0,0,12}},

			}
		}
	}
}

FACE_DECOR_ATTRIBUTES = {
	["pianko_face"] = {
		decor_name = "face",
		decor_model_name = "pianko/piankoface.iqm",
		decor_parent_bone = "Head",
		decor_position = clone{0,0,0.015},
		decor_shadow_mult = 0.95
	}
}
