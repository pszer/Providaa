require "math"

BloomBuffer = {__type = "bloombuffer"}
BloomBuffer.__index = BloomBuffer

BloomRenderer = {__type = "bloomrenderer",
                 chain_length = CONSTS.BLOOM_CHAIN_LENGTH}
BloomRenderer.__index = BloomRenderer

function BloomBuffer:new(w, h, chain_length)
	local this = {
		buffer_w = w,
		buffer_h = h,
		mip_count = chain_length,
		mips = {}
	}

	setmetatable(this,BloomBuffer)

	this:allocateMips(w,h,chain_length)

	return this
end

function BloomRenderer:new(w,h)
	local this = {
		buffer = BloomBuffer:new(w,h, BloomRenderer.chain_length),
		upsample_shader = love.graphics.newShader("shader/upsample.glsl"),
		downsample_shader = love.graphics.newShader("shader/downsample.glsl"),
		src_viewport_size = {w,h}
	}

	setmetatable(this,BloomRenderer)

	return this
end

function BloomRenderer:renderBloomTexture(src_canvas, filter_radius)
	self:renderDownSamples(src_canvas)
	self:renderUpSamples(filter_radius)
	return self.buffer.mips[1].canvas
end

function BloomRenderer:renderDownSamples(src_canvas)
	love.graphics.setShader(self.downsample_shader)
	self.downsample_shader:send("src_resolution", self.src_viewport_size)

	local src = src_canvas
	local mips = self.buffer.mips

	for i=1, self.buffer.mip_count do
		local mip = mips[i]
		love.graphics.setCanvas(mip.canvas)
		love.graphics.draw(src,0,0,0,0.5)

		src = mip.canvas
		self.downsample_shader:send("src_resolution", {mip.size[1], mip.size[2]})
	end
end

function BloomRenderer:renderUpSamples(filter_radius)
	love.graphics.setShader(self.upsample_shader)
	self.upsample_shader:send("filter_radius", filter_radius)

	local mips = self.buffer.mips

	for i=self.buffer.mip_count-1, 1, -1 do
		local mip = mips[i]
		local src = mips[i+1]
		love.graphics.setCanvas(mip.canvas)
		love.graphics.draw(src.canvas,0,0,0,2)
	end
end

function BloomRenderer:reallocateMips(w,h)
	if self.buffer then
		self.buffer:release() end
	self.buffer = BloomBuffer:new(w,h, BloomRenderer.chain_length)
end

function BloomBuffer:allocateMips(w, h, chain_length)
	local int = function(A) return math.floor(A) end

	local mip_size = {w,h}
	local mip_int_size = {int(w), int(h)}

	for i=1, chain_length do
		local mip = {
			canvas = nil,
			size = nil,
			int_size = nil,
		}

		mip_size[1] = mip_size[1] / 2.0
		mip_size[2] = mip_size[2] / 2.0
		mip_int_size[1] = int(mip_size[1])
		mip_int_size[2] = int(mip_size[2])
		mip.size = {mip_size[1], mip_size[2]} -- clone the vector
		mip.int_size = {mip_int_size[1], mip_int_size[2]} -- clone the vector

		mip.canvas = love.graphics.newCanvas(mip_int_size[1], mip_int_size[2], {format="rg11b10f"})
		mip.canvas:setFilter("linear", "linear")
		mip.canvas:setWrap("clamp", "clamp")

		self.mips[i] = mip
	end
end

function BloomBuffer:release()
	if self.mips then
		for i,mip in ipairs(self.mips) do
			mip.canvas:release()
		end
	end
end
