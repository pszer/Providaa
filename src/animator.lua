-- animator object to attach to models
--

require 'stack'

Animator = {}
Animator.__index = Animator

function Animator:new(model)
	local this = {
		queue = {},
	}
end

-- info = 
-- {type="normal", anim="animation_name", offset="now", speed=1.0, }
function Animator:push(info)

end
