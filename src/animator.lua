-- animator object to attach to models
--
-- it's functionality is limited, it's simply an object to pass
-- which animation and frame should be applied to a model, with support
-- to play an entire animation and return a callback function upon the
-- animations completion
--

require 'stack'

Animator = {}
Animator.__index = Animator

function Animator:new(model)
	local this = {
		anim_model_ref = model,

		anim_play_animation = false,
		anim_play_start_time = 0,
		anim_curr_animation = nil,
		anim_curr_frame     = nil

	}

	setmetatable(this, Animator)
	return this
end

-- pushes it's current animation state onto its model reference
function Animator:pushToModel( )
	local model = self.anim_model_ref
end
