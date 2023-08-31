Textures = {
	loaded = {},
	missing_texture = nil
}
Textures.__index = Textures

function Textures.queryTexture(fname)
	local tex = Textures.loaded[fname]
	if tex then
		return tex
	else
		return Textures.missing_texture
	end
end

function Textures.isTextureLoaded(fname)
	return Textures.loaded[fname] ~= nil
end

function Textures.loadTexture(fname)
	if Textures.isTextureLoaded(fname) then return Textures.queryTexture(fname) end -- do nothing if already loaded

	local attributes = tex_attributes[fname] or {}
	local tex = Texture.openFilename(fname, attributes)
	if tex then Textures.loaded[fname] = tex end
	return tex
end

function Textures.loadTextures()
	love.graphics.setDefaultFilter( "nearest", "nearest" )
	print("loading from cfg/texture_attributes")
	for i,v in pairs(tex_attributes) do
		Textures.loadTexture(i)
	end
end

-- returns an image with all the textures on one texture and
-- a table with texture coordinates for each entry in argument <--- removed
-- returns how many images are put side by side in the x direction and y direction
--
-- the textures in the argument are expected to be raw love2d images
function Textures.mergeTextures(textures)
	local count = #textures

	if count==1 then
		--return textures[1], {{0,0},{1,0},{1,1},{0,1}}
		return textures[1], 1, 1
	end

	if count == 0 then return nil, nil end
	local square_side = math.ceil(math.sqrt(count))

	local max_w,max_h = 0,0
	-- find biggest texture width and height
	for i = 1, count do
		local tex = textures[i]
		local w,h = tex:getWidth(), tex:getHeight()

		if w > max_w then max_w = w end
		if h > max_h then max_h = h end
	end

	local canvas = love.graphics.newCanvas(max_w * square_side, max_h * square_side, {type="2d"})
	love.graphics.push("all")
	love.graphics.reset()
	love.graphics.setCanvas(canvas)

	local texcoords_table = {}

	local coordstep = 1/square_side

	local x,y = 1,1
	for i = 1,count do

		local tx,ty = x-1, y-1

		local drawx,drawy = tx*max_w, ty*max_h

		love.graphics.draw(textures[i], drawx, drawy)

		texcoords_table[i] = {}

		texcoords_table[i][1] = {tx*coordstep,ty*coordstep}
		texcoords_table[i][2] = {(tx+1)*coordstep,ty*coordstep}
		texcoords_table[i][3] = {(tx+1)*coordstep,(ty+1)*coordstep}
		texcoords_table[i][4] = {tx*coordstep,(ty+1)*coordstep}
		
		x=x+1
		if  x>square_side then
			x=1
			y=y+1
		end
	end

	love.graphics.setCanvas()
	love.graphics.pop()
	--return love.graphics.newImage(canvas:newImageData()), texcoords_table
	return love.graphics.newImage(canvas:newImageData()), square_side, square_side
end

function Textures.generateMissingTexture()
	local canvas = love.graphics.newCanvas(16,16,{type="2d"})

	love.graphics.push("all")
	love.graphics.reset()
	love.graphics.setCanvas(canvas)

	love.graphics.clear(1,0,1,1)
	love.graphics.setColor(0,0,0,1)
	for y = 0,14,2 do
		for x = 0,16,4 do
			love.graphics.rectangle("fill",x+y%4,y,2,2)
		end
	end

	love.graphics.setCanvas()
	love.graphics.pop()

	local tex = Texture:new{
		texture_name = "missing",
		texture_imgs = {love.graphics.newImage(canvas:newImageData())},
		}
	Textures.missing_texture = tex
end
