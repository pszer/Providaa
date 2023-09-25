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
	__cxtm_bb = nil,
	__cxtm_tt = nil,
	__cxtm_rr = nil,
	__cxtm_ll = nil,
	__cxtm_tr = nil,
	__cxtm_tl = nil,
	__cxtm_br = nil,
	__cxtm_bl = nil,

	icons = {}
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

	local icon_list = {
		"mapedit/icon_del.png",
		"mapedit/icon_dup.png",
		"mapedit/icon_copy.png",
		"mapedit/icon_sub.png"
	}
	for i,v in ipairs(icon_list) do
		self.icons[v] = Loader:getTextureReference(v)
	end
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
-- example, the word example will be drawn in bold and the substring "sent" in
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
		["lgray"]   = 0xBBBBBB
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

return MapEditGUIRender
