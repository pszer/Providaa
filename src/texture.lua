-- functions for loading and getting textures

require "props.textureprops"
require "string"
require "tick"

require "math"

local tex_attributes = require "cfg.texture_attributes"

Texture = {__type = "texture"}
Texture.__index = Texture

function Texture:new(props)
	local this = {
		props = TexturePropPrototype(props),
	}

	setmetatable(this,Texture)
	this.props.texture_sequence_length = #this.props.texture_sequence

	return this
end

function Texture:getImage(frame)
	if not self.props.texture_animated then
		return self.props.texture_imgs[1]
	else
		local props = self.props
		local tick = getTick()

		local anim_delay = props.texture_animation_delay
		local anim_length = props.texture_sequence_length * props.texture_animation_delay
		local anim_frame = math.floor((tick%anim_length)/anim_delay) + 1

		local f = props.texture_sequence[anim_frame]

		return props.texture_imgs[f]
	end
end

-- if img/filename exists, loads it as a texture
-- if it doesn`t exist, but img/filename1,2,3... exist
-- then it loads these together into an animted texture
-- otherwise, returns nil
function Texture.openFilename(filename, attributes)
	if not attributes then attributes = tex_attributes[filename] or {} end
	for i,v in pairs(attributes) do print(i,v) end

	local fpath = "img/" .. filename

	local img = Texture.openImage(fpath)
	if img then

		-- non animated texture
		local props = {
			texture_name = filename,
			texture_imgs = {img},
			texture_frames  = 1,
			texture_animated = false,
			texture_type = "2d"
		}
		for i,v in pairs(attributes) do props[i]=v end
		return Texture:new(props)

	else
		-- check if animated texture

		-- first, we get a filepath without a file extension
		-- and have a copy of the file extension itself
		local extension_i = string.find(fpath, "%.")
		-- if no file extension, return nil
		if not extension_i then return nil end

		local fpathsub = string.sub(fpath, 1,extension_i-1)
		local fpathext = string.sub(fpath, extension_i,-1)

		local frames = {}
		local sequence = {}
		local i = 1
		local exists = false

		while true do
			local anim_path = fpathsub .. tostring(i) .. fpathext

			local img = Texture.openImage(anim_path)

			if img then
				exists = true
				frames[i] = img
				sequence[i] = i
				i = i + 1
			else
				break
			end
		end

		if exists then
			local props = {
				texture_name = filename,
				texture_imgs = frames,
				texture_frames  = i-1,
				texture_animated = true,
				texture_sequence = sequence,
				texture_type = "2d"
			}
			for i,v in pairs(attributes) do props[i]=v end
			return Texture:new(props)
		else
			-- texture at filename doesn`t exist
			return nil
		end

	end
end

-- checks if texture exists, if it does
-- calls love.graphics.newImage() along with
-- setting desired texture attributes
function Texture.openImage(f)
	local finfo = love.filesystem.getInfo(f)
	if not finfo or finfo.type ~= "file" then return nil end

	local img = love.graphics.newImage(f)
	if not img then return nil end

	img:setWrap("repeat","repeat")

	return img
end

function Texture:animationChangesThisTick()
	if not self.props.texture_animated then return false end

	local delay = self.props.texture_animation_delay
	if getTick() % delay == 0 then return true end
	return false
end

Textures = {
	loaded = {}
}
Textures.__index = Textures

function Textures.queryTexture(fname)
	return Textures.loaded[fname]
end

function Textures.loadTexture(fname)
	if Textures.queryTexture(fname) then return end -- do nothing if already loaded

	local attributes = tex_attributes[fname] or {}
	local tex = Texture.openFilename(fname, attributes)
	if tex then Textures.loaded[fname] = tex end
end

function Textures.loadTextures()
	love.graphics.setDefaultFilter( "nearest", "nearest" )
	print("loading from cfg/texture_attributes")
	for i,v in pairs(tex_attributes) do
		print("loading",i)
		Textures.loadTexture(i)
	end
end

Textures.loadTextures()
