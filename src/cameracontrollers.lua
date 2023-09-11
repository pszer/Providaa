-- these are functions that create camera controllers to be given to a camera
-- eg. camera:setController( CamController.followEntity( PLAYER_ENTITY ) )

local CamController = {}
CamController.__index = self

-- follows the position of an entity with an offset given by a fixed offset_vector
-- the camera points itself at the centre of the top of entities hitbox, an optional centre_offset
-- vector gives a local offset from this centre to point at.
function CamController:followEntityFixed(ent, offset_vector, centre_offset)
	local ent = ent
	local ent_deleted = false
	local offset_vector = offset_vector
	local centre_offset = centre_offset or {0,0,0}

	return function( camera )

		print("ent")
		-- failsafe in case entity gets deleted
		if ent_deleted or ent:toBeDeleted() then
			ent = nil
			ent_deleted = true
			return
		end

		local x,y,z, dx,dy,dz = ent:getWorldHitbox()
		x = x + dx*0.5
		y = y 
		z = z + dz*0.5

		camera:setPosition{x + offset_vector[1],
		                   y + offset_vector[2],
		                   z + offset_vector[3]}
		camera:setDirection{-offset_vector[1] + centre_offset[1],
                            -offset_vector[2] + centre_offset[2],
							-offset_vector[3] + centre_offset[3]}
	end
end

return CamController
