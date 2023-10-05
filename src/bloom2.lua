require 'math'
BloomRender = {}
BloomRender.__index = BloomRender

--local upsample_shader = love.graphics.newShader("upsample.glsl")
local downsample_shader = love.graphics.newShader("shader/bloomdownsample.glsl")

function BloomRender:new(w,h,length)
	local this = {
		--upsample_shader = upsample_shader,
		downsample_shader = downsample_shader,
		viewport_size = {w,h},

		--rgb16f is used instead of rg11b10f. ALL active render targets set with
		--love.graphics.setCanvas() need to be written to in a shader call to avoid
		--errors, having an alpha channel allows for non-destructively writing vec4(0.0).
		buffer = love.graphics.newCanvas(w,h,3,{format="rgba16f",readable=true}),

		chain_length = length,
		full_length = 0,
		targets = {},
		sizes = {},
		dummy_texture = love.graphics.newCanvas(1,1,{format="r8"}),
		commitBlit = function(self,w,h,x,y)
			love.graphics.draw(self.dummy_texture,x,y,0,w,h)
		end,

		bloom_result_layer = 0,
		bloom_result_quad = nil,
		filter_radius=0.006
	}
	this.targets[1]={this.buffer,layer=1}--first buffer target
	this.targets[2]={this.buffer,layer=2}--second buffer target
	this.targets[3]={this.buffer,layer=3}--second buffer target

	this.buffer:setWrap("clamp","clamp")
	this.buffer:setFilter("linear","linear")

	this.downsample_shader:send("texs",this.buffer)
	--this.upsample_shader:send("texs",this.buffer)

	local int = math.floor
	local W,H,y,x,i=w,h,0,0,1
	-- successively scale in half from [w,h]->[1,1]
	while true do
		this.sizes[i] = {W,H, x=x, y=y, w=W, h=H}
		if H==1 and W==1 then break end
		if i>1 then
			x=x+W
		end
		W=int(W*0.5)
		H=int(H*0.5)
		if W<1 then W=1 end
		if H<1 then H=1 end
		y=y+H
		i=i+1
	end
	this.full_length = #(this.sizes)
	local final_size = this.sizes[2]
	this.bloom_result_quad = love.graphics.newQuad(final_size.x,final_size.y,final_size.w,final_size.h,this.buffer)
	this.bloom_viewport = {final_size.x/w, final_size.y/h, final_size.w/w, final_size.h/h}
	local avglum_size = this.sizes[this.full_length]
	this.avglum_result_quad = love.graphics.newQuad(avglum_size.x,0,avglum_size.w,avglum_size.h,this.buffer)
	this.avglum_viewport = {avglum_size.x/w,0,avglum_size.w/w,avglum_size.h/h}

	setmetatable(this, BloomRender)
	return this
end

function BloomRender:reallocate(w,h)
	if false then
	self = {
		--upsample_shader = upsample_shader,
		downsample_shader = downsample_shader,
		viewport_size = {w,h},
		buffer = love.graphics.newCanvas(w,h,3,{format="rgba16f",readable=true}),

		chain_length = self.chain_length,
		full_length = 0,
		targets = {},
		sizes = {},
		dummy_texture = love.graphics.newCanvas(1,1,{format="r8"}),
		commitBlit = function(self,w,h,x,y)
			love.graphics.draw(self.dummy_texture,x,y,0,w,h)
		end,

		bloom_result_layer = 0,
		bloom_result_quad = nil,
		filter_radius=0.006
	}
	self.targets[1]={self.buffer,layer=1}--first buffer target
	self.targets[2]={self.buffer,layer=2}--second buffer target
	self.targets[3]={self.buffer,layer=3}--second buffer target

	self.buffer:setWrap("clamp","clamp")
	self.buffer:setFilter("linear","linear")

	self.downsample_shader:send("texs",self.buffer)

	local int = math.floor
	local W,H,y,x,i=w,h,0,0,1
	-- successively scale in half from [w,h]->[1,1]
	while true do
		self.sizes[i] = {W,H, x=x, y=y, w=W, h=H}
		if H==1 and W==1 then break end
		if i>1 then
			x=x+W
		end
		W=int(W*0.5)
		H=int(H*0.5)
		if W<1 then W=1 end
		if H<1 then H=1 end
		y=y+H
		i=i+1
	end
	self.full_length = #(self.sizes)
	local final_size = self.sizes[2]
	self.bloom_result_quad = love.graphics.newQuad(final_size.x,final_size.y,final_size.w,final_size.h,self.buffer)
	self.bloom_viewport = {final_size.x/w, final_size.y/h, final_size.w/w, final_size.h/h}
	local avglum_size = self.sizes[self.full_length]
	self.avglum_result_quad = love.graphics.newQuad(avglum_size.x,0,avglum_size.w,avglum_size.h,self.buffer)
	self.avglum_viewport = {avglum_size.x/w,0,avglum_size.w/w,avglum_size.h/h}
	end
end

-- renders bloom from given viewport texture
-- the bloom/avgluminance can then be fetched from getBloom() and getAverageLuminance()
function BloomRender:renderBloom(viewport)
	local length = self.chain_length
	love.graphics.setCanvas(self.targets)

	local downsampler = self.downsample_shader
	downsampler:send("filter_radius",self.filter_radius)
	--local upsampler   = self.upsample_shader

	local sizes = self.sizes
	local max_res = sizes[1]

	downsampler:send("max_resolution",max_res)
	--upsampler:send("max_resolution",max_res)

	-- downsample
	love.graphics.setShader(downsampler)
	downsampler:send("mode",0)
	local destination_layer=0 -- 0-indexed
	local depth=nil
	for i=1,length do
		downsampler:send("destination_layer",destination_layer)
		downsampler:send("source_layer",(destination_layer+1)%2)

		local src_size = sizes[i]
		local out_size = sizes[i+1]

		downsampler:send("src_resolution",src_size)
		downsampler:send("src_x",src_size.x)

		if i==1 then
			downsampler:send("u_initial_blit",true)
			love.graphics.draw(viewport,0,0,0,0.5,0.5)
		else
			downsampler:send("u_initial_blit",false)
			self:commitBlit(out_size[1],out_size[2],out_size.x)
		end

		if i~=length then
			destination_layer=(destination_layer+1)%2 -- flipflop between 0<->1
		end
	end-- downsample end
	local downsampled_result_index = destination_layer

	-- further downsampling down to 1x1
	--[[downsampler:send("u_flip_flop_mode",1)--flip flops between layer 3 and 1/2,
	                                      --whichever preserves the downsampled texture
																				--for the upsampling stage--]]
	downsampler:send("u_initial_blit",false)
	self.avglum_result_layer = 3
	for i=length+1,self.full_length-1 do
		destination_layer=(destination_layer+1)%2
		downsampler:send("destination_layer",destination_layer)
		downsampler:send("source_layer",(destination_layer+1)%2)

		local src_size = sizes[i]
		local out_size = sizes[i+1]

		downsampler:send("src_resolution",src_size)
		downsampler:send("src_x",src_size.x)

		self:commitBlit(out_size[1],out_size[2],out_size.x)
	end -- further downsampling end--]]

	-- upsample
	--love.graphics.setShader(upsampler)
	destination_layer = (downsampled_result_index+1)%2
	downsampler:send("mode",1)
	for i=length-1,1,-1 do
		downsampler:send("destination_layer",destination_layer)

		local src_size = sizes[i+2]
		local out_size = sizes[i+1]
		--print("src",i+2,src_size[1],src_size[2],src_size.x,src_size.y)
		--print("out",i+1,out_size[1],out_size[2],out_size.x,out_size.y)
		downsampler:send("src_resolution",src_size)
		downsampler:send("src_x",src_size.x)
		if i==length-1 then
			downsampler:send("src_y",0)
		else
			downsampler:send("src_y",src_size.y)
		end

		self:commitBlit(out_size[1],out_size[2],out_size.x,out_size.y)

		destination_layer=(destination_layer+1)%2 -- flipflop between 0<->1
	end-- upsample end
	destination_layer=(destination_layer+1)%2 -- flipflop between 0<->1

	self.bloom_result_layer = destination_layer
end
--
function BloomRender:getBloom()
	return self.buffer, self.bloom_result_layer+1, self.bloom_result_quad, self.bloom_viewport
end
function BloomRender:getAverageLuminance()
	return self.buffer, self.avglum_result_layer, self.avglum_result_quad, self.avglum_viewport
end
