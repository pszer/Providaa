-- calculating interpolated animations is intensive, we use threads
-- to spread out the load
--

AnimThreads = {}
AnimThreads.__index = AnimThreads

function AnimThreads:new(thread_count)
	local this = {
		threads = {},
		model_inst_map = {},
		channel_in = love.thread.getChannel("anim_thread_in"),
		channel_out = love.thread.getChannel("anim_thread_out"),
		started = false
	}

	for i=1,thread_count do
		this.threads[i] = love.thread.newThread("threads/anim.lua")
	end

	this.model_inst_map[0] = 0

	setmetatable(this, AnimThreads)

	return this
end

function AnimThreads:addToQueue(model_inst, frame1, frame2, parents, interp)
	local i = self.model_inst_map[0] + 1
	self.model_inst_map[i] = model_inst
	self.model_inst_map[0] = i

	self.channel_in:push{["index"]=i, ["frame1"]=frame1, ["frame2"]=frame2, ["parents"]=parents, ["interp"]=interp}
end

function AnimThreads:startProcess()
	if self.started then return end
	for i,thread in ipairs(self.threads) do
		thread:start()
	end
	self.started = true
end

function AnimThreads:stopProcess()
	if not self.started then return end
	while true do
		self.channel_in:push("halt")
		local finished = true
		for i,thread in ipairs(self.threads) do
			if thread:isRunning() then
				finished = false
				break
			end
		end
		if finished then break end
	end
	self.channel_in:clear()
	self.channel_out:clear()
	self.started = false
end

function AnimThreads:finishProcess()
	while true do
		if self.channel_in:getCount()==0 and self.channel_out:getCount()==0 then
			break
		end
		--local data = self.channel_out:pop()
		local data = self.channel_out:pop()

		if data then

			local index = data[1]
			local outframe = data.outframe

			local model_inst = self.model_inst_map[index]
			if model_inst then
				model_inst.bone_matrices = outframe
				self.model_inst_map[index] = nil
			end
		end
	end

	self.model_inst_map[0] = 0
end

--animthread = AnimThreads:new(4)
