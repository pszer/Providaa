-- these are functions that create camera controllers to be given to a camera
-- eg. camera:setController( CamController.followEntity( PLAYER_ENTITY ) )

local CamController = {}
CamController.__index = self

-- follows the position of an entity with an offset given by a fixed offset_vector
-- the position of the camera (if offset_vector were 0,0,0) is located in the middle of the top plane
-- of the entities hitbox
--
-- where the camera points is set by vec3 look_at_coords argument,
-- look_at_coords = {  0,  0,  0} points the camera at the minimum point of the entity's hitbox
-- look_at_coords = {  1,  1,  1} points the camera at the maximum point of the entity's hitbox
-- look_at_coords = {0.5,0.5,0.5} points the camera at the middle of the entity's hitbox
-- etc
--
function CamController:followEntityFixed(ent, offset_vector, look_at_coords)
	local ent = ent
	local ent_deleted = false
	local offset_vector = offset_vector
	local look_at_coords = look_at_coords or {0.5,0,0.5}

	return function( camera )

		-- failsafe in case entity gets deleted
		if ent_deleted or ent:toBeDeleted() then
			ent = nil
			ent_deleted = true
			return
		end

		local pos, size = ent:getWorldHitboxPosSize()
		--local x,y,z, dx,dy,dz = ent:getWorldHitbox()
		local x,y,z = unpack(pos)
		local dx,dy,dz = unpack(size)
		--x = x + dx*look_at_coords[1]
		--y = y + dy*look_at_coords[2]
		--z = z + dz*look_at_coords[3]
		x = x + dx*0.5
		y = y
		z = z + dz*0.5

		local camx = x + offset_vector[1]
		local camy = y + offset_vector[2]
		local camz = z + offset_vector[3]

		local lookat_x = pos[1] + dx*look_at_coords[1]
		local lookat_y = pos[2] + dy*look_at_coords[2]
		local lookat_z = pos[3] + dz*look_at_coords[3]

		local dirx = lookat_x - camx
		local diry = lookat_y - camy
		local dirz = lookat_z - camz

		camera:setPosition{camx,camy,camz}
		camera:setDirection{dirx,diry,dirz}
	end
end

return CamController
