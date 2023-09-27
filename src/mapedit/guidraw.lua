--
-- gui rendering functions used by mapedit.lua
--

require "string"
require "bit"
require "math"

local MapEditGUIRender = {
	font        = nil,
	font_bold   = nil,
	font_italic = nil,
	__font_fname        = "LibreBaskerville-Regular.ttf",
	__font_bold_fname   = "LibreBaskerville-Bold.ttf",
	__font_italic_fname = "LibreBaskerville-Italic.ttf",

	cxtm_bg_col = {0.094,0.161,0.290},
	__cxtm_bb = nil, -- bottom border for a context menu box
	__cxtm_tt = nil, -- top border for a context menu box
	__cxtm_rr = nil, -- right border for a context menu box
	__cxtm_ll = nil, -- left border
	__cxtm_tr = nil, -- top right corner
	__cxtm_tl = nil, -- top left corner
	__cxtm_br = nil, -- bottom right corner
	__cxtm_bl = nil, -- bottom left 

	icons = {},

	grayscale = love.graphics.newShader(
	[[
	 uniform float interp;
   	 vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
   	 {
        vec4 texcolor = Texel(tex, texture_coords) * color;
		float lum = dot(texcolor.xyz, vec3(0.299, 0.587, 0.114));
        return vec4(lum,lum,lum,texcolor.a) * (1.0-interp) + texcolor * interp;
    }
	]],
	[[
	 vec4 position( mat4 transform_projection, vec4 vertex_position )
	    {
   	     return transform_projection * vertex_position;
   	 }
	]]),

	cube_mesh = nil,
	cube_solid_mesh = nil,
	checkerboard_tex = nil
}
MapEditGUIRender.__index = MapEditGUIRender

function MapEditGUIRender:initAssets()
	-- get the font filedata from Loader
	self.font = Loader:getTTFReference(self.__font_fname)
	-- convert to a love2d font object
	self.font = love.graphics.newFont(self.font, 16, "light")
	assert(self.font)

	self.font_bold = Loader:getTTFReference(self.__font_bold_fname)
	self.font_bold = love.graphics.newFont(self.font_bold, 16, "light")
	assert(self.font_bold)

	self.font_italic = Loader:getTTFReference(self.__font_italic_fname)
	self.font_italic = love.graphics.newFont(self.font_italic, 16, "light")
	assert(self.font_italic)

	self.__cxtm_bb = Loader:getTextureReference("mapedit/cxtm_bb.png")
	self.__cxtm_tt = Loader:getTextureReference("mapedit/cxtm_tt.png")
	self.__cxtm_ll = Loader:getTextureReference("mapedit/cxtm_ll.png")
	self.__cxtm_rr = Loader:getTextureReference("mapedit/cxtm_rr.png")
	self.__cxtm_br = Loader:getTextureReference("mapedit/cxtm_br.png")
	self.__cxtm_bl = Loader:getTextureReference("mapedit/cxtm_bl.png")
	self.__cxtm_tr = Loader:getTextureReference("mapedit/cxtm_tr.png")
	self.__cxtm_tl = Loader:getTextureReference("mapedit/cxtm_tl.png")

	self.checkerboard_tex = Loader:getTextureReference("mapedit/checkerboard.png")
	self.checkerboard_tex:setWrap("repeat","repeat")

	self.grayscale:send("interp",0.1)

	local icon_list = {
		"mapedit/icon_del.png",
		"mapedit/icon_dup.png",
		"mapedit/icon_copy.png",
		"mapedit/icon_sub.png"
	}
	for i,v in ipairs(icon_list) do
		self.icons[v] = Loader:getTextureReference(v)
	end

	local layout = {
			{"VertexPosition", "float", 3},
			{"VertexNormal", "float", 3},
	}
	local vertices2 = {
        -- Top
        {0, 0, 1,0,0,1}, {1, 0, 1,0,0,1},
        {1, 1, 1,0,0,1}, {0, 1, 1,0,0,1},
        -- Bottom
        {1, 0, 0,0,0,-1}, {0, 0, 0,0,0,-1},
        {0, 1, 0,0,0,-1}, {1, 1, 0,0,0,-1},
        -- Front
        {0, 0, 0,0,-1,0}, {1, 0, 0,0,-1,0},
        {1, 0, 1,0,-1,0}, {0, 0, 1,0,-1,0},
        -- Back
        {1, 1, 0,0,1,0}, {0, 1, 0,0,1,0},
        {0, 1, 1,0,1,0}, {1, 1, 1,0,1,0},
        -- Right
        {1, 0, 0,1,0,0}, {1, 1, 0,1,0,0},
        {1, 1, 1,1,0,0}, {1, 0, 1,1,0,0},
        -- Left
        {0, 1, 0,-1,0,0}, {0, 0, 0,-1,0,0},
        {0, 0, 1,-1,0,0}, {0, 1, 1,-1,0,0},
	}

	local indices2 = {
			1, 2, 3, 3, 4, 1,
			5, 6, 7, 7, 8, 5,
			9, 10, 11, 11, 12, 9,
			13, 14, 15, 15, 16, 13,
			17, 18, 19, 19, 20, 17,
			21, 22, 23, 23, 24, 21,
	}
	self.cube_solid_mesh = love.graphics.newMesh(layout,vertices2,"triangles","static")
	self.cube_solid_mesh:setVertexMap(indices2)
	self.cube_solid_mesh:setTexture(self.checkerboard_tex)

	local vertices = {
		{0,0,0}, {1,0,0}, {0,1,0}, {0,0,1},
		{1,1,0}, {1,0,1}, {0,1,1}, {1,1,1}
	}
	local indices = {
		1,2,1,
		1,3,1,
		1,4,1,
		8,7,8,
		8,6,8,
		8,5,8,
		3,7,3,
		4,7,4,
		2,5,2,
		2,6,2,
		4,6,4,
		3,5,3
	}

	self.cube_mesh = love.graphics.newMesh(layout,vertices,"triangles","static")
	self.cube_mesh:setVertexMap(indices)
end

--
-- ~N ~n newline
--
-- ~B ~b toggles bold text on/off
-- ~I ~i toggles italic tex on/off
-- (upper and lowercase are equivalent)
--
-- ~(0xFFFFFF) switches to hexadecimal RGB coloured text, can be the name of a
-- predefined colour like ~(red), ~(white), ~(blue) etc. Default colour is white.
--
-- ~R ~r reset to default
--
-- example, the word "example" will be drawn in bold and the substring "sent" in
-- the word sentence will be red
-- This is an ~Bexample~B ~(0xFF0000)sent~(0xFFFFFF)ence
--
-- if you want to use a tilde character as part of the text, escape it using double tilde ~~
--
function MapEditGUIRender:createDrawableText(string, font, font_bold, font_italic)
	assert_type(string, "string")
	local font = font or self.font
	local font_bold = font_bold or self.font_bold
	local font_italic = font_italic or self.font_italic
	assert(font and font_bold and font_italic)

	-- gets the position of a non-escaped tilde character
	-- with an optional start index i
	--
	-- this string.find pattern cannot find tildes at the beginning of the string
	-- quick and dirty fix is to simply add a junk character at the beginning of the string
	function get_tilde_pos(str, i)
		local a,b = string.find(' '..str,"[^~]~[^~]", i)
		if not (a and b) then return nil end
		return b-2
	end

	local substrs = {}

	local i = 1
	local j = 1

	local curr_type = "regular" -- "bold", "italic"
	local curr_col  = 0xFFFFFF
	local new_line  = false

	local nilstr = ""

	local col_table = {
		["white"]   = 0xFFFFFF,
		["gray"]    = 0x808080,
		["grey"]    = 0x808080,
		["lgray"]   = 0xBBBBBB,
		["lgrey"]   = 0xBBBBBB,
		["black"]   = 0x000000,

		["red"]     = 0xFF0000,
		["green"]   = 0x00FF00,
		["indigo"]  = 0x0000FF,

		["yellow"]  = 0xFFFF00,
		["magenta"] = 0xFF00FF,
		["cyan"]    = 0x00FFFF,

		["orange"]  = 0xFF8000,
		["pink"]    = 0xFF0080,
		["purple"]  = 0x8000FF,
		["blue"]    = 0x0080FF,
		["emerald"] = 0x00FF80,
		["vert"]    = 0x80FF00,

		["lyellow"] = 0xFFFF80,
		["lgreen"]  = 0x80FF80,
		["lblue"]   = 0x8080FF,
		["lred"]    = 0xFF8080,
		["lpurple"] = 0xbb78ff
	}

	while true do
		local t_pos = get_tilde_pos(string, j)
		if not t_pos then i=j break end

		i = j
		j = t_pos
		if i < j then
			local substr = string.sub(string, i,j-1)
			table.insert(substrs, {substr,curr_type,curr_col,new_line})
		end
		new_line = false

		local char_after_tilde = string.sub(string, j+1,j+1)
		if char_after_tilde == nilstr then
			error(string.format("MapEditGUIRender:createDrawableText(): %s ill-formated string, character expected after ~", string))
		end

		if char_after_tilde == "N" or char_after_tilde == "n" then
			new_line = true
			j = j+2
		elseif char_after_tilde == "B" or char_after_tilde == "b" then
			if curr_type ~= "bold" then curr_type = "bold"
			                       else curr_type = "regular" end
			j = j+2
		elseif char_after_tilde == "I" or char_after_tilde == "i" then
			if curr_type ~= "italic" then curr_type = "italic"
			                         else curr_type = "regular" end
			j = j+2
		elseif char_after_tilde == "R" or char_after_tilde == "r" then
			curr_type = "regular"
			curr_col  = 0xFFFFFF
			j = j+2
		elseif char_after_tilde == "(" then
			local a,b,in_bracket = string.find(string, "%((.-)%)", j+1)

			if not in_bracket then
				error(string.format("MapEditGUIRender:createDrawableText(): %s ill-formated string, expected ~(col) after ~(", string))
			end

			local in_col_table = col_table[in_bracket]
			--print("in_bracket", in_bracket)
			if in_col_table then
				curr_col = in_col_table
			else
				curr_col = tonumber(in_bracket, 16)
			end

			j = b+1
		else
			error(string.format("MapEditGUIRender:createDrawableText(): %s ill-formated string, unrecognised character after ~", string))
		end
	end

	j = #string
	if i<=j then
		table.insert(substrs, {string.sub(string,i,j),curr_type,curr_col,new_line})
	end

	local function HexToRGB(hex)
	    local r = math.floor(hex / 65536) % 256 
	    local g = math.floor(hex / 256)   % 256  
   		local b = hex % 256
		return r,g,b
	end

	local texts = {}
	local tinfo = {}
	for i,v in ipairs(substrs) do
		local str   = v[1]
		local ttype = v[2]
		local col   = v[3]
		local nl    = v[4]

		local f = nil
		if     ttype == "regular" then f = font
		elseif ttype == "bold"    then f = font_bold
		elseif ttype == "italic"  then f = font_italic
		end
		local r,g,b = HexToRGB(col)
		texts[i] = love.graphics.newText(f, {{r/255,g/255,b/255},str})
		local t = texts[i]

		tinfo[i] = {t:getWidth(), t:getHeight(), nl}
	end

	local min,max = math.min, math.max
	local maxw,maxh = 0,0
	local w,h = 0,0
	for i,v in ipairs(tinfo) do
		local tw,th,nl = v[1],v[2],v[3]
		if nl then
			maxw = math.max(w,maxw)
			maxh = maxh + h
			w,h=tw,th
		else
			w,h = w+tw,math.max(h,th)
		end
	end
	maxw = math.max(w,maxw)
	maxh = maxh + h

	local canvas = love.graphics.newCanvas(maxw,maxh)
	love.graphics.origin()
	love.graphics.setShader()
	love.graphics.setColor(1,1,1,1)
	love.graphics.setCanvas(canvas)
	h=0
	local x,y=0,0
	for i,v in ipairs(tinfo) do
		local text = texts[i]
		local tw,th,nl = v[1],v[2],v[3]
		if nl then
			y=y+h
			h=0
			x=0
		end

		love.graphics.draw(text,x,y)
		x,h = x+tw,math.max(h,th)
	end
	love.graphics.setCanvas()

	return canvas
end

function MapEditGUIRender:drawableFormatString(name, props)
	assert(name)
	local input_type = type(name)
	local str = nil
	if input_type == "string" then
		str = name
	elseif input_type == "table" then
		local str_f = name[1]
		local str_d = {}
		for i=2,#name do
			str_d[i-1] = this.props[name[i]]
		end
		str = string.format(str_f, unpack(str_d))
	else
		error("MapEditGUIRender:drawableFormatString(): expected string/table in name field", 2)
	end
	local drawable_text = self:createDrawableText(str)
	local w,h = drawable_text:getDimensions()
	return drawable_text,w,h
end

function MapEditGUIRender:createContextMenuBackground(w,h, col)
	local canvas = love.graphics.newCanvas(w,h)

	cxtm_bb = self.__cxtm_bb 
	cxtm_tt = self.__cxtm_tt 
	cxtm_rr = self.__cxtm_rr 
	cxtm_ll = self.__cxtm_ll 
	cxtm_tr = self.__cxtm_tr 
	cxtm_tl = self.__cxtm_tl 
	cxtm_br = self.__cxtm_br 
	cxtm_bl = self.__cxtm_bl

	local bg_col = self.cxtm_bg_col
	local col = col or {1,1,1}

	love.graphics.origin()
	love.graphics.setShader()
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bg_col[1],bg_col[2],bg_col[3],1)
	love.graphics.setColor(col[1],col[2],col[3],1)

	love.graphics.draw(cxtm_tl,0  ,0,   0, 1,1)
	love.graphics.draw(cxtm_tr,w-2,0,   0, 1,1)
	love.graphics.draw(cxtm_bl,0  ,h-2, 0, 1,1)
	love.graphics.draw(cxtm_br,w-2,h-2, 0, 1,1)

	local w2 = w-4
	local h2 = h-4
	love.graphics.draw(cxtm_ll,0  ,2  , 0, 1 ,h2)
	love.graphics.draw(cxtm_rr,w-2,2  , 0, 1 ,h2)
	love.graphics.draw(cxtm_tt,2  ,0  , 0, w2,1 )
	love.graphics.draw(cxtm_bb,2  ,h-2, 0, w2,1 )

	love.graphics.setColor(1,1,1,1)
	love.graphics.setCanvas()
	return canvas
end

local cpml = require 'cpml'
local __tempcubemat4 = cpml.mat4.new()
local __id = cpml.mat4.new()
local __tempvec3t = cpml.vec3.new()
local __tempvec3s = cpml.vec3.new()
function MapEditGUIRender:draw3DCube(shader, min, max, col, solid, solid_col)
	local shadersend = require 'shadersend'
	shadersend(shader, "u_solid_colour_enable", true)

	local model_mat = __tempcubemat4
	-- initialize to an identity matrix
	for i=1,16 do
		model_mat[i] = __id[i]
	end

	local pos = __tempvec3t
	pos.x,pos.y,pos.z = min[1],min[2],min[3]
	local size = __tempvec3s
	size.x,size.y,size.z = max[1]-min[1],max[2]-min[2],max[3]-min[3]

	model_mat:scale(model_mat, size)
	model_mat:translate(model_mat, pos)
	shadersend(shader, "u_model", "column", model_mat)
	love.graphics.setColor(col)
	love.graphics.draw(self.cube_mesh)

	shadersend(shader, "u_solid_colour_enable", false)

	if solid then
		local w = love.graphics.isWireframe()
		local mode, alphamode = love.graphics.getBlendMode()
		love.graphics.setColor(solid_col)
		love.graphics.setBlendMode("screen","premultiplied")
		love.graphics.setMeshCullMode("front")
		love.graphics.setWireframe( false )
		shadersend(shader, "u_global_coord_uv_enable", true)
		love.graphics.draw(self.cube_solid_mesh)
		shadersend(shader, "u_global_coord_uv_enable", false)
		love.graphics.setWireframe( w )
		love.graphics.setBlendMode(mode,alphamode)
		love.graphics.setMeshCullMode("none")
	end

	shadersend(shader, "u_model", "column", __id)
	love.graphics.setColor(1,1,1,1)
end


function MapEditGUIRender:drawGenericOption(x,y,w,h, bg, txt, icon, arrow, state, buffer_info)
	local bl = buffer_info.l_no_icon
	if icon then
		bl = buffer_info.l
	end
	love.graphics.draw(bg,x,y)

	-- if hoverable
	if state == "hover" then

		local mode, alphamode = love.graphics.getBlendMode()
		love.graphics.setColor(255/255,161/255,66/255,0.8)
		love.graphics.setBlendMode("add","alphamultiply")

		love.graphics.rectangle("fill",x,y,w,h)

		love.graphics.setColor(1,1,1,1)
		love.graphics.setBlendMode("subtract","alphamultiply")

		love.graphics.draw(txt,x+bl,y+buffer_info.r)

		if icon then
			love.graphics.draw(icon,x+buffer_info.icon_l,y+buffer_info.icon_t)
		end

		love.graphics.setBlendMode(mode, alphamode)

	elseif state ~= "disable" then
		love.graphics.draw(txt,x+bl,y+buffer_info.r)
		if icon then
			love.graphics.draw(icon,x+buffer_info.icon_l,y+buffer_info.icon_t)
		end
	else
		love.graphics.setShader(self.grayscale)
		love.graphics.setColor(0.9,0.9,1,0.3)

		love.graphics.draw(txt,x+bl,y+buffer_info.r)
		if icon then
			love.graphics.draw(icon,x+buffer_info.icon_l,y+buffer_info.icon_t)
		end

		love.graphics.setShader()
	end
	if arrow then
		love.graphics.draw(self.icons["mapedit/icon_sub.png"],
			x + w - buffer_info.arrow_r, y + buffer_info.arrow_t)
	end

	love.graphics.setColor(1,1,1,1)
end

return MapEditGUIRender