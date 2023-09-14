local cpml = require 'cpml'

require "love.timer"

function calc_mats(frame1, frame2, parents, interp)
	--local outframe = self.outframes
	local interp_i = 1.0 - interp
	local mat4new = cpml.mat4.new
	local mat4mul = cpml.mat4.mul

	local outframe = {nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil}

	for i,pose1 in ipairs(frame1) do
		pose2 = frame2[i]

		local pose_interp = { 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0 }

		for i=1,16 do
			pose_interp[i] =
			 interp_i*pose1[i] + interp*pose2[i]
		end

		local mat = mat4new(pose_interp)

		local parent_i = parents[i]
		if parent_i > 0 then
			outframe[i] = mat4new()
			outframe[i] = mat4mul(outframe[i], outframe[parent_i], mat)
		else
			outframe[i] = mat
		end
	end

	return outframe
end -- calc_mats

channel_in  = love.thread.getChannel("anim_thread_in")
channel_out = love.thread.getChannel("anim_thread_out")

while true do
	local info = channel_in:demand(0.001)
	--local info = channel_in:pop()

	if info then
		if info == "halt" then return end

		local index = info.index
		local frame1 = info.frame1
		local frame2 = info.frame2
		local parents = info.parents
		local interp = info.interp

		local outframe = calc_mats(frame1, frame2, parents, interp)
		channel_out:push{index, ["outframe"]=outframe}

	else
		--if channel_in:getCount() == 0 then
		--	love.timer.sleep(0.001)
		--end
	end

	--if channel_in:getCount() == 0 then break end
end
