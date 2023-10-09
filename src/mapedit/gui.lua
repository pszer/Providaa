local guirender    = require 'mapedit.guidraw'
local contextmenu  = require 'mapedit.context'
local toolbar      = require 'mapedit.toolbar'
local popup        = require 'mapedit.popup'
local guilayout    = require 'mapedit.layout'
local guiscreen    = require 'mapedit.screen'
local guiwindow    = require 'mapedit.window'
local guitextbox   = require 'mapedit.textelement'
local guibutton    = require 'mapedit.button'
local guiimage     = require 'mapedit.image'
local guiscrollb   = require 'mapedit.scrollbar'
local guiimggrid   = require 'mapedit.gridselection'
local guitextinput = require 'mapedit.textinput'

local export_map   = require 'mapedit.export'
local lang         = require 'mapedit.guilang'

local maptransform = require "mapedit.transform"

local transobj     = require "transobj"
local utf8         = require "utf8"

require "inputhandler"
require "input"

local MapEditGUI = {

	context_menus = {},
	toolbars = {},

	main_panel = nil,

	curr_context_menu = nil,
	curr_popup = nil,
	
	main_toolbar = nil,

	cxtm_input = nil,

	textinput_hook = nil

}
MapEditGUI.__index = MapEditGUI

function MapEditGUI:init(mapedit)
	guirender:initAssets()
	self:setupInputHandling()
	self:define(mapedit)
end

function MapEditGUI:define(mapedit)
	local context = self.context_menus
	local toolbars = self.toolbars

	local region_default_f = function(l) return l.x, l.y, l.w, l.h end
	local region_middle_f = function(l) return l.x+l.w*0.5, l.y+l.h*0.5, l.w, l.h end
	local region_offset_f = function(_x,_y) return function(l) return l.x+l.w*_x, l.y+l.h*_y, l.w, l.h end end
	local region_pixoffset_f = function(_x,_y) return function(l) return l.x+_x, l.y+_y, l.w, l.h end end
	local region_ypixoffset_f = function(_x,_y) return function(l) return l.x+l.w*_x, l.y+_y, l.w, l.h end end

	guitextinput:setup(function(i,t) return self:setTextInputHook(i,t)  end,
	                   function( i ) return self:removeTextInputHook(i) end)

	--
	-- translate window
	--
	local translate_win_layout = guilayout:define(
		{id="region",
		 split_type=nil},
		{"region", region_pixoffset_f(10,10)},-- header
		{"region", region_pixoffset_f(10,35)},-- translate toggle
		{"region", region_pixoffset_f(80,35)},-- world toggle
		{"region", region_pixoffset_f(8,65)}, -- X
		{"region", region_pixoffset_f(8,90)}, -- Y
		{"region", region_pixoffset_f(8,115)},-- Z
		{"region", region_pixoffset_f(25,60)}, -- X textbox
		{"region", region_pixoffset_f(25,85)}, -- Y textbox
		{"region", region_pixoffset_f(25,110)},-- Z textbox
		{"region", region_pixoffset_f(10,140)},-- Commit button
		{"region", region_pixoffset_f(80,140)}-- Cancel button
	)
	local translate_win = guiwindow:define({
		win_min_w=160,
		win_max_w=160,
		win_min_h=170,
		win_max_h=170,
		win_focus=true,
	}, translate_win_layout)
	local function make_translate_win(objs)
		local centre,_,_ = mapedit:getObjectsCentreAndMinMax(objs)

		local header = guitextbox:new(lang["Move selection."],0,0,155,"left")

		local local_button,global_button=nil,nil
		local mode = "local"
		local_button = guibutton:new(lang["Locally"],nil,0,0,
			function(self,win)
				mode="local"
				global_button.held=false
			end,"left","top",true,true)
		global_button = guibutton:new(lang["Globally"],nil,0,0,
			function(self,win)
				mode="global"
				local_button.held=false
			end,"left","top",true,false)

		local X_text = guitextbox:new("~b~(lred)X:",0,0,165,nil,nil,nil,true)
		local Y_text = guitextbox:new("~b~(lgreen)Y:",0,0,165,nil,nil,nil,true)
		local Z_text = guitextbox:new("~b~(lblue)Z:",0,0,165,nil,nil,nil,true)
		local X_input = guitextinput:new("0",0,0,125,20,guitextinput.float_validator, guitextinput.float_format_func,"left","top")
		local Y_input = guitextinput:new("0",0,0,125,20,guitextinput.float_validator, guitextinput.float_format_func,"left","top")
		local Z_input = guitextinput:new("0",0,0,125,20,guitextinput.float_validator, guitextinput.float_format_func,"left","top")

		local commit_button = guibutton:new(lang["~bCommit"],nil,0,0,
			function(self,win)
				local X_status = X_input:get()
				local Y_status = Y_input:get()
				local Z_status = Z_input:get()
				if not X_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lred)X") return end
				if not Y_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lgreen)Y") return end
				if not Z_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lblue)Z") return end

				if mode=="local" then
					local transform = maptransform:translateBy(X_status,Y_status,Z_status)
					mapedit:commitCommand("transform", {transform_info=transform})
					win:delete()
				else
					local x,y,z
					x = X_status - centre[1]
					y = Y_status - centre[2]
					z = Z_status - centre[3]
					local transform = maptransform:translateBy(x,y,z)
					mapedit:commitCommand("transform", {transform_info=transform})
					win:delete()
				end
			end,"left","top")
		local close_button = guibutton:new(lang["~bClose."],nil,0,0, function(self,win) win:delete() end,"left","top")

		local win = translate_win:new({},
		{
			header,
			local_button,
			global_button,
			X_text,Y_text,Z_text,
			X_input,Y_input,Z_input,
			commit_button,close_button
		},
		0,0,100,130)
		return win
	end
	--
	-- translate window
	--

	--
	-- scale window
	--
	local scale_win_layout = guilayout:define(
		{id="region",
		 split_type=nil},
		{"region", region_pixoffset_f(10,10)},-- header
		{"region", region_pixoffset_f(8,35)}, -- X
		{"region", region_pixoffset_f(8,60)}, -- Y
		{"region", region_pixoffset_f(8,85)}, -- Z
		{"region", region_pixoffset_f(25,30)}, -- X textbox
		{"region", region_pixoffset_f(25,55)}, -- Y textbox
		{"region", region_pixoffset_f(25,80)}, -- Z textbox
		{"region", region_pixoffset_f(10,110)}, -- Commit button
		{"region", region_pixoffset_f(80,110)}  -- Cancel button
	)
	local scale_win = guiwindow:define({
		win_min_w=160,
		win_max_w=160,
		win_min_h=140,
		win_max_h=140,
		win_focus=true,
	}, scale_win_layout)
	local function make_scale_win(objs)
		local header = guitextbox:new(lang["Scale selection."],0,0,155,"left")

		local X_text = guitextbox:new("~b~(lred)X:",0,0,165,nil,nil,nil,true)
		local Y_text = guitextbox:new("~b~(lgreen)Y:",0,0,165,nil,nil,nil,true)
		local Z_text = guitextbox:new("~b~(lblue)Z:",0,0,165,nil,nil,nil,true)

		local validator = function(t)
			local V = guitextinput.rational_validator(t)
			if not V then return nil end
			if V == 0.0 then return nil end
			return V
		end
		local format_func = function(str)
			local S = guitextinput.rational_format_func(str)
			if tonumber(S)==0.0 then
				return "~(red)"..S
			end
			return S
		end

		local X_input = guitextinput:new("1.0",0,0,125,20,validator, format_func,"left","top")
		local Y_input = guitextinput:new("1.0",0,0,125,20,validator, format_func,"left","top")
		local Z_input = guitextinput:new("1.0",0,0,125,20,validator, format_func,"left","top")

		local commit_button = guibutton:new(lang["~bCommit"],nil,0,0,
			function(self,win)
				local X_status = X_input:get()
				local Y_status = Y_input:get()
				local Z_status = Z_input:get()
				if not X_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lred)X") return end
				if not Y_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lgreen)Y") return end
				if not Z_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lblue)Z") return end

				local transform = maptransform:scaleBy(X_status,Y_status,Z_status)
				mapedit:commitCommand("transform", {transform_info=transform})
				win:delete()
			end,"left","top")
		local close_button = guibutton:new(lang["~bClose."],nil,0,0, function(self,win) win:delete() end,"left","top")

		local win = scale_win:new({},
		{
			header,
			X_text,Y_text,Z_text,
			X_input,Y_input,Z_input,
			commit_button,close_button
		},
		0,0,100,130)
		return win
	end
	--
	-- scale window
	--
	
	--
	-- rotation window
	--
	local rotation_win_layout = guilayout:define(
		{id="region",
		 split_type=nil},
		{"region", region_pixoffset_f(10,10)},-- header
		{"region", region_pixoffset_f(10,30)},-- X toggle
		{"region", region_pixoffset_f(30,30)},-- Y toggle
		{"region", region_pixoffset_f(50,30)},-- Z toggle
		{"region", region_pixoffset_f(8,60)}, -- theta
		{"region", region_pixoffset_f(25,55)}, -- X textbox
		{"region", region_pixoffset_f(10,85)},-- Commit button
		{"region", region_pixoffset_f(80,85)} -- Cancel button
	)
	local rotation_win = guiwindow:define({
		win_min_w=160,
		win_max_w=160,
		win_min_h=115,
		win_max_h=115,
		win_focus=true,
	}, rotation_win_layout)
	local function make_rotation_win(objs, axis)
		local centre,_,_ = mapedit:getObjectsCentreAndMinMax(objs)

		local header = guitextbox:new(lang["Rotate selection."],0,0,155,"left")

		local X_button,Y_button,Z_button = nil,nil,nil
		local mode = axis
		X_button = guibutton:new("~(lred)X",nil,0,0,
			function(self,win)
				mode="X"
				Y_button.held=false
				Z_button.held=false
			end,"left","top",true,axis=="X")
		Y_button = guibutton:new("~(lgreen)Y",nil,0,0,
			function(self,win)
				mode="Y"
				X_button.held=false
				Z_button.held=false
			end,"left","top",true,axis=="Y")
		Z_button = guibutton:new("~(lblue)Z",nil,0,0,
			function(self,win)
				mode="Z"
				X_button.held=false
				Y_button.held=false
			end,"left","top",true,axis=="Z")

		local theta_text = guitextbox:new("~b~(lpurple)θ°",0,0,165,nil,nil,nil,true)
		local theta_input = guitextinput:new("0",0,0,125,20,guitextinput.float_validator, guitextinput.float_format_func,"left","top")

		local commit_button = guibutton:new(lang["~bCommit"],nil,0,0,
			function(self,win)
				local DEG_TO_RAD = 1/(180.0/math.pi)
				local theta_status = theta_input:get()
				if not theta_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,lang["~b~(red)Angle"]) return end
				local transform = maptransform:rotateByAxis(theta_status * DEG_TO_RAD, mode)
				mapedit:commitCommand("transform", {transform_info=transform})
				win:delete()
			end,"left","top")
		local close_button = guibutton:new(lang["~bClose."],nil,0,0, function(self,win) win:delete() end,"left","top")

		local win = rotation_win:new({},
		{
			header,
			X_button,Y_button,Z_button,
			theta_text,theta_input,
			commit_button,close_button
		},
		0,0,100,130)
		return win
	end
	--
	-- rotation window
	--
	
	--
	-- tile texture edit window
	--
	local texedit_win_layout = guilayout:define(
		{id="region",
		 split_type=nil},
		{"region", region_pixoffset_f(10,10)},-- header
		{"region", region_pixoffset_f(5,35)}, -- X-off
		{"region", region_pixoffset_f(5,60)}, -- Y-off
		{"region", region_pixoffset_f(27,30)}, -- X-off textbox
		{"region", region_pixoffset_f(27,55)}, -- Y-off textbox
		{"region", region_pixoffset_f(95,35)}, -- X-scale
		{"region", region_pixoffset_f(95,60)}, -- Y-scale
		{"region", region_pixoffset_f(110,30)}, -- X-scale textbox
		{"region", region_pixoffset_f(110,55)}, -- Y-scale textbox
		{"region", region_pixoffset_f(10,85) }, -- Texture preview
		{"region", region_pixoffset_f(120,140)}, -- Lock scale toggle
		{"region", region_pixoffset_f(120,165)}, -- Lock offset toggle
		{"region", region_pixoffset_f(120,90)},-- Flip X button
		{"region", region_pixoffset_f(120,115)},-- Flip Y button
		{"region", region_pixoffset_f(10,193)},-- Global Scale toggle
		{"region", region_pixoffset_f(10,193+25)},-- Commit button
		{"region", region_pixoffset_f(80,193+25)}  -- Cancel button
	)
	local texedit_win = guiwindow:define({
		win_min_w=230,
		win_max_w=230,
		win_min_h=245,
		win_max_h=245,
		win_focus=false,
	}, texedit_win_layout)
	local function make_texedit_win(objs)
		local tile_exists,wall_exists = false,false
		for i,v in ipairs(objs) do
			local o_type=v[1]
			if o_type=="tile" then
				tile_exists=true
				if wall_exists then
					MapEditGUI:displayPopup(lang["Can't texture edit tiles and walls at the same time"])
					return nil
				end
			elseif o_type=="wall" then
				wall_exists=true
				if tile_exists then
					MapEditGUI:displayPopup(lang["Can't texture edit tiles and walls at the same time"])
					return nil
				end
			end
		end

		if not (tile_exists or wall_exists) then return nil end

		local keep_offset_button,keep_scale_button=nil,nil
		keep_offset_button = guibutton:new(lang["Keep offset"],nil,0,0,
			nil,"left","top",true,false)
		keep_scale_button = guibutton:new(lang["Keep scale"],nil,0,0,
			nil,"left","top",true,false)
		local global_scale_button=nil
		global_scale_button = guibutton:new(lang["Enable global scaling."], nil,0,0,
			nil, "left","top",true,true)

		local header
		if tile_exists then
			header = guitextbox:new(lang["Edit tile texture attributes."],0,0,290,"left")
		else
			header = guitextbox:new(lang["Edit wall texture attributes."],0,0,155,"left")
		end

		-- extends rational number validator/formatter to
		-- not allow 0.0 for scale factors
		local nonzero_validator = function(t)
			local V = guitextinput.rational_validator(t)
			if not V then return nil end
			if V == 0.0 then return nil end
			return V
		end
		local nonzero_format_func = function(str)
			local S = guitextinput.rational_format_func(str)
			if tonumber(S)==0.0 then
				return "~(red)"..S
			end
			return S
		end

		local Xoff_text = guitextbox:new("~b~(lred)Δx",0,0,165,nil,nil,nil,true)
		local Yoff_text = guitextbox:new("~b~(lgreen)Δy",0,0,165,nil,nil,nil,true)
		local Xscale_text = guitextbox:new("~b~(lred)Cx",0,0,165,nil,nil,nil,true)
		local Yscale_text = guitextbox:new("~b~(lgreen)Cy",0,0,165,nil,nil,nil,true)
		local Xoff_input = guitextinput:new("0",0,0,60,20,guitextinput.rational_validator,guitextinput.rational_format_func,"left","top")
		local Yoff_input = guitextinput:new("0",0,0,60,20,guitextinput.rational_validator,guitextinput.rational_format_func,"left","top")
		local Xscale_input = guitextinput:new("1/1",0,0,60,20,nonzero_validator, nonzero_format_func,"left","top")
		local Yscale_input = guitextinput:new("1/1",0,0,60,20,nonzero_validator, nonzero_format_func,"left","top")

		-- find the most common texture in selection
		local tex_occurs = {}
		local max_occur_tex = nil
		local max_occur_c = -1/0
		local start_offset = nil
		local start_scale  = nil
		local start_offset_unique = true
		local start_scale_unique = true
		for i,v in ipairs(objs) do
			local tex = mapedit:getObjectTexture(v)
			if tex then
				local count = tex_occurs[tex]
				if count then
					tex_occurs[tex]=count+1
				else
					tex_occurs[tex]=1
				end

				if tex_occurs[tex] > max_occur_c then
					max_occur_tex = tex
					max_occur_c = tex_occurs[tex]
				end
			end

			if start_offset_unique or start_scale_unique then
				local off,scale = mapedit:getTexOffset(v),mapedit:getTexScale(v)
				if not start_offset then
					start_offset = off
					start_scale  = scale
				else
					local function mod1(x) return x%1 end
					local off_eq = mod1(off[1])==mod1(start_offset[1]) and mod1(off[2])==mod1(start_offset[2])
					local scale_eq = scale[1]==start_scale[1] and scale[2]==start_scale[2]

					if not off_eq then start_offset_unique=false end
					if not scale_eq then start_scale_unique=false end
				end
			end
		end
		if not max_occur_tex then return end
		
		local tex_i = mapedit.props.mapedit_texture_list[max_occur_tex]
		if not tex_i then return end
		local tex = mapedit.props.mapedit_texture_list[tex_i]
		if not tex then return end
		tex = tex[2]
		if not tex then return end

		local last_ok_offset = (start_offset_unique and {unpack(start_offset)}) or {0,0}
		local last_ok_scale  = (start_scale_unique and {unpack(start_scale)}) or {1,1}

		if start_offset_unique then
			Xoff_input:setText(tostring(start_offset[1]))
			Yoff_input:setText(tostring(start_offset[2]))
		end
		if start_scale_unique then
			if start_scale[1] < 1.0 then
				Xscale_input:setText("1/"..tostring(1/start_scale[1]))
			else
				Xscale_input:setText(tostring(start_scale[1]))
			end
			if start_scale[2] < 1.0 then
				Yscale_input:setText("1/"..tostring(1/start_scale[2]))
			else
				Yscale_input:setText(tostring(start_scale[2]))
			end
		end

		local dummy_tex = love.graphics.newCanvas(1,1,{format="r8"})
		dummy_tex:setFilter("linear","linear")
		local tex_preview = guiimage:new(tex,0,0,100,100,function()end,"left","top")
		local shader = mapedit.tex_preview_shader
		shader:send("tex",tex)
		tex_preview.draw = function(self)
			local offset = last_ok_offset
			local scale  = last_ok_scale
			local keep_offset = keep_offset_button.held
			local keep_scale  = keep_scale_button.held
			if not keep_offset then
				local Xoff_s= Xoff_input:get()
				local Yoff_s= Yoff_input:get()
				if Xoff_s and Yoff_s then
					last_ok_offset[1],last_ok_offset[2]=Xoff_s,Yoff_s
				end
			else
				last_ok_offset[1],last_ok_offset[2]=start_offset[1],start_offset[2]
			end
			if not keep_scale then
				local Xscale_s= Xscale_input:get()
				local Yscale_s= Yscale_input:get()
				if Xscale_s and Yscale_s then
					last_ok_scale[1],last_ok_scale[2]=Xscale_s,Yscale_s
				end
			else
				last_ok_scale[1],last_ok_scale[2]=start_scale[1],start_scale[2]
			end

			shader:send("texture_offset", last_ok_offset)
			shader:send("texture_scale", last_ok_scale)
			local x,y,w,h = self.x,self.y,self.w,self.h
			love.graphics.setShader(shader)
			love.graphics.draw(dummy_tex,x,y,0,w,h)
			love.graphics.setShader()
		end

		local flipx_button,flipy_button=nil,nil
		flipx_button = guibutton:new(lang["Flip ~(lred)~bX"],nil,0,0,
			function(self,win)
				local ScaleX = last_ok_scale[1]
				ScaleX = -ScaleX
				last_ok_scale[1] = ScaleX
				local str = Xscale_input.text.string
				if not Xscale_input:get() then
					Xscale_input:setText(tostring(ScaleX))
					return
				end
				local offset = utf8.offset(str,2)
				local first_c = string.sub(str,1,offset-1)
				local rem = string.sub(str,offset,-1)
				if first_c == "-" then
					str = "+"..rem
				elseif first_c == "+" then
					str = "-"..rem
				else
					str = "-"..str
				end
				Xscale_input.text:set(str)
			end,"left","top")
		flipy_button = guibutton:new(lang["Flip ~(lgreen)~bY"],nil,0,0,
			function(self,win)
				local ScaleY = last_ok_scale[2]
				ScaleY = -ScaleY
				last_ok_scale[2] = ScaleY
				local str = Yscale_input.text.string
				if not Yscale_input:get() then
					Yscale_input:setText(tostring(ScaleY))
					return
				end
				local offset = utf8.offset(str,2)
				local first_c = string.sub(str,1,offset-1)
				local rem = string.sub(str,offset,-1)
				if first_c == "-" then
					str = "+"..rem
				elseif first_c == "+" then
					str = "-"..rem
				else
					str = "-"..str
				end
				Yscale_input.text:set(str)
			end,"left","top")

		local commit_button = guibutton:new(lang["~bCommit"],nil,0,0,
			function(self,win)
				local Xoff_status = Xoff_input:get()
				local Yoff_status = Yoff_input:get()
				local Xscale_status = Xscale_input:get()
				local Yscale_status = Yscale_input:get()

				if not Xoff_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lred)Δx") return end
				if not Yoff_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lgreen)Δy") return end
				if not Xscale_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lred)Cx") return end
				if not Yscale_status then MapEditGUI:displayPopup(lang["~(red)%s~(red) is malformed."],2.75,"~b~(lgreen)Cy") return end

				local keep_offset = keep_offset_button.held
				local keep_scale  = keep_scale_button.held
				local global_scaling = global_scale_button.held
				if keep_offset and keep_scale then win:delete() return end

				local offsets={}
				local scales={}

				if not keep_offset then
					local sx,sy
					if not keep_scale then
						sx = Xscale_status
						sy = Yscale_status
					else
						sx = start_scale[1]
						sy = start_scale[2]
					end
					for i,v in ipairs(objs) do
						if global_scaling then
							local _,curry = unpack(mapedit:getTexOffset(v))
							if keep_scale then
								sx,sy = unpack(mapedit:getTexScale(v))
							end
							local x,y = v[2].x, v[2].z
							if v[1]=="wall" then y=curry end
							if sx > 1.0 then x = (x * ((sx-1)/sx)) % 1
							            else x = Xoff_status end
							if sy > 1.0 then y = (y * ((sy-1)/sy)) % 1
							            else y = Yoff_status end
							offsets[i] = {Xoff_status+x, Yoff_status+y}
						else
							offsets[i] = {Xoff_status, Yoff_status}
						end
					end
				end
				if not keep_scale then
					for i,v in ipairs(objs) do
						scales[i] = {Xscale_status, Yscale_status}
					end
				end

				mapedit:commitCommand("change_texture_attributes", {
					objects=objs,
					offsets=offsets,
					scales=scales,
				})
				win:delete()
			end,"left","top")
		local close_button = guibutton:new(lang["~bClose."],nil,0,0, function(self,win) win:delete() end,"left","top")

		local win = texedit_win:new({},
		{
			header,

			Xoff_text,Yoff_text,
			Xoff_input,Yoff_input,
			Xscale_text,Yscale_text,
			Xscale_input,Yscale_input,

			tex_preview,

			keep_scale_button, keep_offset_button,
			flipx_button,flipy_button,
			global_scale_button,

			commit_button,close_button
		},
		0,0,100,130)
		print("swagdem")
		return win
	end
	--
	-- tile texture edit window
	--

	context["select_models_context"] = 
		contextmenu:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable(ProvMapEdit.active_selection)},
		 {"group_info", "table", nil, PropDefaultTable{create_enable=false,
		                                               merge_groups_enable=false,
		                                               add_to_group_enable=false,
		                                               ungroup_enable=false,
		                                               models_outside=nil,
		                                               groups=nil}},
		}
		,
		function(props) return
		 {lang["~bCopy"],
		  action=function(props)
		    mapedit:copySelectionToClipboard() end,
			disable = not mapedit:canCopy(),
		  icon = "mapedit/icon_copy.png"},

		 {lang["Paste"],
		  action=function(props)
		    mapedit:pasteClipboard() end,
			disable = not mapedit:canPaste(),
		  icon = "mapedit/icon_dup.png"},

		 {lang["Undo"],
		  action=function(props)
		    mapedit:commitUndo() end,
			disable = not mapedit:canUndo(),
		  icon = nil},

		 {lang["Redo"],
		  action=function(props)
		    mapedit:commitRedo() end,
			disable = not mapedit:canRedo(),
		  icon = nil},

		 {lang["~b~(orange)Delete"],
		  action=function(props)
		    mapedit:commitCommand("delete_obj", {select_objects=props.select_objects}) end,
		  icon = "mapedit/icon_del.png"},

		 {lang["~(lpurple)Group"], suboptions = function(props)
		  local groups = props.group_info.groups
			local models_outside = props.group_info.models_outside
			local name_tab = ""
			if #groups==0 then
				name_tab = lang["No group"]
			else
				local count=#groups
				for i=1,count do
					local group = groups[i]
					name_tab=name_tab..group.name
					if i~=count then
						name_tab=name_tab..', '
					end
				end
			end
			local str_len = #name_tab
			if str_len > 30 then
				name_tab=string.sub(name_tab,1,24)
				name_tab=name_tab.."..."
			end

		 	return {
			 {name_tab},
			 {lang["~(green)~bCreate"],
			  disable = not props.group_info.create_enable,
			   action =
			     function()
			       mapedit:commitCommand("create_group", {select_objects=props.select_objects}) end},
			 {lang["Merge Groups"],
			  disable = not props.group_info.merge_groups_enable,
			   action =
			     function()
			       mapedit:commitCommand("merge_groups", {groups=groups}) end},
			 {lang["Add To Group"],
			  disable = not props.group_info.add_to_group_enable,
			   action =
			     function()
			       mapedit:commitCommand("add_to_group", {group=groups[1], models=models_outside}) end},
			 {lang["~(lpurple)Ungroup"],
			  disable = not props.group_info.ungroup_enable,
			   action =
			     function()
			       mapedit:commitCommand("dissolve_groups", {groups=groups, models=models_outside}) end},

			 }
			end},

		 {lang["~(lgray)--Transform--"]},

		 {lang["Move"], action = function(props)
		 		return make_translate_win(props.select_objects)
		  end},
		 {lang["Scale"], action = function(props)
		 		return make_scale_win(props.select_objects)
		  end},

		 {lang["Flip"], suboptions = function(props)
		  return {
			 {lang["... by ~i~(lred)X~r Axis"],
			  action=
			    function()
			      mapedit:commitCommand("transform", {transform_info=maptransform.flip_x_const}) end},
			 {lang["... by ~i~(lgreen)Y~r Axis"],
			  action=
			    function()
			       mapedit:commitCommand("transform", {transform_info=maptransform.flip_y_const}) end},
			 {lang["... by ~i~(lblue)Z~r Axis"], action=function()
			   mapedit:commitCommand("transform", {transform_info=maptransform.flip_z_const}) end},
			}
		 end},

		 {lang["Rotate"], suboptions = function(props)
		 	return {
			 {lang["... by angle°"], action = function(props)
		      return make_rotation_win(props.select_objects, "Y")
			 	end},
			 {lang["... around ~i~(lred)X~r Axis"], suboptions = function(props)
			  return {
			    {"+~i90~b°", 
			      action=
			        function()
			          mapedit:commitCommand("transform", {transform_info=maptransform.rot_x_090}) end},
			    {"+~i180~b°",
			      action=
			        function()
			          mapedit:commitCommand("transform", {transform_info=maptransform.rot_x_180}) end},
			     {"+~i270~b°",
			      action=
			        function()
			          mapedit:commitCommand("transform", {transform_info=maptransform.rot_x_270}) end}}
			 end},
			 {lang["... around ~i~(lgreen)Y~r Axis"], suboptions = function(props)
			  return {
			    {"+~i90~b°",
			      action=
			        function() mapedit:commitCommand("transform", {transform_info=maptransform.rot_y_090}) end},
			    {"+~i180~b°",
			      action=
			        function()
			          mapedit:commitCommand("transform", {transform_info=maptransform.rot_y_180}) end},
			    {"+~i270~b°",
			      action=
			        function()
			          mapedit:commitCommand("transform", {transform_info=maptransform.rot_y_270}) end}}
			 end},
			 {lang["... around ~i~(lblue)Z~r Axis"], suboptions = function(props)
			  return {
			    {"+~i90~b°",
			      action=
			        function()
			          mapedit:commitCommand("transform", {transform_info=maptransform.rot_z_090}) end},
			    {"+~i180~b°",
			      action=
			        function()
			          mapedit:commitCommand("transform", {transform_info=maptransform.rot_z_180}) end},
			    {"+~i270~b°",
			      action=
			        function()
			          mapedit:commitCommand("transform", {transform_info=maptransform.rot_z_270}) end}}
			 end},
			}
		 end},

		 {lang["~bReset"],action=function(props)
		   mapedit:commitCommand("reset_transformation", {select_objects = props.select_objects}) end,
		   icon = nil},

		 {lang["~(lgray)--Actions--"]},
		 {lang["Place model"], suboptions = function(props)
		 	local at_sel, at_origin = mapedit:getPlaceModelFunctions()
		 	return {
				{lang["... at ~(lpink)selection~r."], action=at_sel    , disable=not at_sel   },
				{lang["... at world origin."]       , action=at_origin , disable=not at_origin},
			}
		 end}

		 end)
	
	context["select_undef_context"] = 
		contextmenu:define(
		{
		}
		,
		function(props) return
		 {lang["~bCopy"],
		  action=function(props)
		    mapedit:copySelectionToClipboard() end,
			disable = true,
		  icon = "mapedit/icon_copy.png"},

		 {lang["Paste"],
		  action=function(props)
		    mapedit:pasteClipboard() end,
			disable = not mapedit:canPaste(),
		  icon = "mapedit/icon_dup.png"},

		 {lang["Undo"],
		  action=function(props)
		    mapedit:commitUndo() end,
			disable = not mapedit:canUndo(),
		  icon = nil},

		 {lang["Redo"],
		  action=function(props)
		    mapedit:commitRedo() end,
			disable = not mapedit:canRedo(),
		  icon = nil},

		 {lang["~b~(orange)Delete"],
		  icon = "mapedit/icon_del.png",
			disable = true},

		 {lang["~(lpurple)Group"], suboptions = function(props) 
	     return {}
			end, disable = true},

		 {lang["~(lgray)--Transform--"]},

		 {lang["Flip"], suboptions = function(props) 
		  return {} end,
		  disable = true},

		 {lang["Rotate"], suboptions = function(props)
		 	return {} end,
		  disable = true},

		 {lang["~bReset"],disable = true, icon = nil},

		 {lang["~(lgray)--Actions--"]},
		 {lang["Place model"], suboptions = function(props)
		 	local at_sel, at_origin = mapedit:getPlaceModelFunctions()
		 	return {
				{lang["... at ~(lpink)selection~r."], action=at_sel    , disable=not at_sel   },
				{lang["... at world origin."]       , action=at_origin , disable=not at_origin},
			} end}
		 end)

	context["select_mesh_context"] = 
		contextmenu:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable(ProvMapEdit.active_selection)},
		}
		,
		function(props) return
		 {lang["~bCopy"],
		  action=function(props)
		    mapedit:copySelectionToClipboard() end,
			disable = true,
		  icon = "mapedit/icon_copy.png"},

		 {lang["Paste"],
		  action=function(props)
		    mapedit:pasteClipboard() end,
			disable = not mapedit:canPaste(),
		  icon = "mapedit/icon_dup.png"},

		 {lang["Undo"],
		  action=function(props)
		    mapedit:commitUndo() end,
			disable = not mapedit:canUndo(),
		  icon = nil},

		 {lang["Redo"],
		  action=function(props)
		    mapedit:commitRedo() end,
			disable = not mapedit:canRedo(),
		  icon = nil},

		 {lang["Texture Edit"],
		  action = function(props)
		 		return make_texedit_win(props.select_objects)
				end,
			icon=nil},

		 {lang["~(lgray)--Actions--"]},
		 {lang["Place model"], suboptions = function(props)
		 	local at_sel, at_origin = mapedit:getPlaceModelFunctions()
		 	return {
				{lang["... at ~(lpink)selection~r."], action=at_sel    , disable=not at_sel   },
				{lang["... at world origin."]       , action=at_origin , disable=not at_origin},
			} end}
		 end)

	-- About window
	local about_win_layout = guilayout:define(
		{id="image_region",
		 split_type="+x",
		 split_pix=80,
		 sub=
			{id="region",
			 split_type="+y",
			 split_pix=90,
			 sub = {
				id="button_region",
				split_type=nil
			 }
			}
		},
		{"image_region", region_middle_f},
		{"region", region_pixoffset_f(-50,0)},
		{"button_region", region_middle_f}
	)
	local about_win = guiwindow:define({
		win_min_w=300,
		win_max_w=300,
		win_min_h=120,
		win_max_h=120,
	}, about_win_layout)
	-- About window

	-- Language window
	local lang_win_layout = guilayout:define(
		{id="region",
		 split_type=nil},
		{"region", region_ypixoffset_f(0.0,10)},
		{"region", region_ypixoffset_f(0.5,35)},
		{"region", region_ypixoffset_f(0.5,60)},
		{"region", region_ypixoffset_f(0.5,85)}
	)
	local lang_win = guiwindow:define({
		win_min_w=100,
		win_max_w=100,
		win_min_h=115,
		win_max_h=115,
		win_focus=true,
	}, lang_win_layout)
	-- Change map name window
	local mapname_win_layout = guilayout:define(
		{id="region",
		 split_type=nil},
		{"region", region_ypixoffset_f(0.5,10)},
		{"region", region_ypixoffset_f(0.5,25)},
		{"region", region_ypixoffset_f(0.5,50)}
	)
	local mapname_win = guiwindow:define({
		win_min_w=200,
		win_max_w=200,
		win_min_h=75,
		win_max_h=75,
		win_focus=true,
	}, mapname_win_layout)

	context["help_context"] = 
		contextmenu:define(
		{
		}
		,
		function(props) return
		 {lang["Keybinds"],
		  action=function(props)
		    return end,
			disable = false},

		 {lang["Set Language"],
		  action=function(props)
		    return lang_win:new({},
				{
					guitextbox:new(lang["Set Language"],0,0,100,"center"),
					guibutton:new("English","mapedit/flag_en.png",0,0, function(self,win) lang:setLanguage("eng")
					                                                    guirender:loadFonts(lang:getFontInfo())
					                                                    MapEditGUI:define(mapedit) end,"middle","top"),
					guibutton:new("Polish","mapedit/flag_pl.png",0,0, function(self,win) lang:setLanguage("pl")
					                                                   guirender:loadFonts(lang:getFontInfo())
					                                                   MapEditGUI:define(mapedit) end,"middle","top"),
					guibutton:new("Japanese","mapedit/flag_jp.png",0,0, function(self,win) lang:setLanguage("jp")
					                                                     guirender:loadFonts(lang:getFontInfo())
					                                                     MapEditGUI:define(mapedit) end,"middle","top"),
				},
				0,0,100,115)
				end,
			disable = false},

		 {lang["~iAbout"],
		  action=function(props)
		    return about_win:new({},
				{
					guiimage:new("mapedit/ic.png",0,0,80,120,function() self:displayPopup(lang["~b~(red)Do not click the kappa."]) end),
					guitextbox:new(lang["\nWelcome!\n\nKappa map editor © 2023 \nMIT license (see LICENSE.md)"],0,0,300,"center"),
					guibutton:new(lang["~bClose."],nil,0,0, function(self,win) win:delete() end,"middle","bottom")}
					,256,256,256,256)
				end,
			disable = false}
		 end)

	context["main_file_context"] =
		contextmenu:define(
		{
		 -- props
		},
		function(props) return
		{lang["Save"],action=function()
			mapedit:exportAndWriteToFile("test2.lua")
		end},
		{lang["Open"],action=function()
		end},
		{" --- "},
		{lang["Set map name"],action=function(props)
			local curr_map_name = mapedit.props.mapedit_map_name
			return mapname_win:new({},
			{
				guitextbox:new(lang["Type in new name."],0,0,300,"left","middle","top"),
				guitextinput:new(curr_map_name,0,0,180,20,guitextinput.identity_validator, guitextinput.identity_format_func,"middle","top"),
				guibutton:new(lang["~bClose."],nil,0,0, function(self,win) win:delete() end,"middle","top")}
				,0,0,200,80)
		end},
		{" --- "},
		{lang["~iQuit"],action=function()love.event.quit()end}
		end
		)

	toolbars["main_toolbar"] =
		toolbar:define(
		{

		},

		{lang["File"],
		 generate =
		   function(props)
			   return context["main_file_context"], {}
		   end
		},
		{lang["Edit"],
		 generate =
		   function(props)
			   --return context["main_file_context"], {}
				 local cxtn_name, props = mapedit:getSelectionContextMenu()
				 if not cxtn_name then return nil end
				 return context[cxtn_name], props
		   end
		},
		{lang["Help"],
		 generate =
		   function(props)
				 return context["help_context"], {}
		   end
		}
		)

	local main_toolbar = toolbars["main_toolbar"]:new({},0,0,1000,10)

	local file_dropper_layout = guilayout:define(
		{id="region",
		 split_type=nil},
		{"region", region_pixoffset_f(10,10)},
		{"region", region_pixoffset_f(260,175)},
		{"region", region_pixoffset_f(260,335)}
	)
	local file_dropper_window = guiwindow:define({
		win_min_w=520,
		win_max_w=520,
		win_min_h=340,
		win_max_h=340,
	}, file_dropper_layout)
	local texture_file_dropped_win = function ()
		local hook = function(file)
			mapedit:textureFileDropProcessor(file)
		end

		local win = file_dropper_window:new({},
		{
			guiimage:new("mapedit/dropper.png",0,0,500,300,function()end,"left","top"),
			guitextbox:new(lang["[Drop texture here]"],0,0,300,"left","middle","bottom"),
			guibutton:new(lang["~bClose."],nil,0,0, function(self,win) win:delete() end,"middle","bottom")
		},
		540,370
		)
		mapedit:setFileDropHook(hook)
			local del = win.delete
			win.delete = function(self) del(self) mapedit:setFileDropHook(nil) end
		return win
	end
	local model_file_dropped_win = function ()
		local hook = function(file)
			mapedit:modelFileDropProcessor(file)
		end

		local win = file_dropper_window:new({},
		{
			guiimage:new("mapedit/dropper.png",0,0,500,300,function()end,"left","top"),
			guitextbox:new(lang["[Drop model here]"],0,0,300,"left","middle","bottom"),
			guibutton:new(lang["~bClose."],nil,0,0, function(self,win) win:delete() end,"middle","bottom")
		},
		540,370
		)
		mapedit:setFileDropHook(hook)
		local del = win.delete
		win.delete = function(self) del(self) mapedit:setFileDropHook(nil) end
		return win
	end

	self.texture_grid = guiimggrid:new(
		mapedit.props.mapedit_texture_list,
		function (self)
			local selection = self.curr_selection
			if selection then
				MapEditGUI.grid_info_panel_image:setImage(selection[2])
			end
		end)

	self.model_grid = guiimggrid:new(
		mapedit.props.mapedit_model_list,
		function (self)
			local selection = self.curr_selection
			if selection then
				MapEditGUI.model_info_panel_image:setImage(selection[2])
			end
		end)

	local grid_info_panel_layout = guilayout:define(
		{id="image_region",
		 split_type="+x",
		 split_pix=110,
		 sub=
			{id="button_region",
			 split_pix=nil
			}
		},
		{"image_region", region_middle_f},
		{"button_region", region_pixoffset_f(0,10)},
		{"button_region", region_pixoffset_f(0,35)}
	)
	local grid_info_panel_window_def = guiwindow:define({
		win_min_w=212,
		win_max_w=5000,
		win_min_h=100,
		win_max_h=5000,
	}, grid_info_panel_layout)

	self.grid_info_panel_image = guiimage:new(nil,0,0,96,96,function() end,
	 "middle","middle",{0,0,0,1})
	self.model_info_panel_image = guiimage:new(nil,0,0,96,96,function() end,
	 "middle","middle",{0,0,0,1})
	local grid_info_panel_window = grid_info_panel_window_def:new(
		{},
		{
			self.grid_info_panel_image,
			guibutton:new(lang["Import"],nil,0,0,
				function(self,win)
					return texture_file_dropped_win()
				end, "left", "top"),
			guibutton:new(lang["Delete"],nil,0,0,
				function(self,win)
					local g_sel = MapEditGUI.texture_grid:getGridSelectedObject()
					if g_sel then
						local tex_name=g_sel[1]
						local ok, status = mapedit:removeTexture(tex_name)
						if not ok then
							MapEditGUI:displayPopup(tostring(status),5.5)
						end
					end
				end,
				"left", "top")
		},
		0,0,300,100)

	local model_info_panel_window = grid_info_panel_window_def:new(
		{},
		{
			self.model_info_panel_image,
			guibutton:new(lang["Import"],nil,0,0,
				function(self,win)
					return model_file_dropped_win()
				end, "left", "top"),
			guibutton:new(lang["Delete"],nil,0,0,
				function(self,win)
					local g_sel = MapEditGUI.model_grid:getGridSelectedObject()
					if g_sel then
						local model=g_sel[3]
						local ok, status = mapedit:removeModelFromList(model)
						if not ok then
							MapEditGUI:displayPopup(tostring(status),5.5)
						end
					end
				end,
				"left", "top")
		},
		0,0,300,100)

	local panel_layout = guilayout:define(
		{id="toolbar_region",
		 split_type="+y",
		 split_pix=20,
		 sub = {
			id="viewport_region",
			split_type="-x",
			split_pix=192+20,
			sub = {
			 id = "grid_info_panel",
			 split_type="+y",
			 split_pix=110,
			 sub = {
				id = "grid_region",
				split_type=nil
			 }
			}
		 }
		},

		{"toolbar_region", function(l) return l.x,l.y,l.w,l.h end},
		{"grid_region", function(l) return l.x,l.y,l.w,l.h end},
		{"grid_info_panel", region_default_f},
		{"grid_region", function(l) return l.x,l.y,l.w,l.h end},
		{"grid_info_panel", region_default_f},
		{"viewport_region", region_pixoffset_f(0,0)}
	)

	local w,h = love.graphics.getDimensions()
	self.main_panel = guiscreen:new(
		panel_layout:new(
		  0,0,w,h,{main_toolbar,
				self.texture_grid, grid_info_panel_window,
				self.model_grid, model_info_panel_window,
				}),
			function(o) self:handleTopLevelThrownObject(o) end,
			CONTROL_LOCK.MAPEDIT_PANEL,
			CONTROL_LOCK.MAPEDIT_WINDOW
	)

	function MapEditGUI:showTexturePanel()
		self.main_panel:disableElement(self.model_grid)
		self.main_panel:disableElement(model_info_panel_window)
		self.main_panel:enableElement(self.texture_grid)
		self.main_panel:enableElement(grid_info_panel_window)
	end
	function MapEditGUI:showModelPanel()
		self.main_panel:enableElement(self.model_grid)
		self.main_panel:enableElement(model_info_panel_window)
		self.main_panel:disableElement(self.texture_grid)
		self.main_panel:disableElement(grid_info_panel_window)
	end
	self:showModelPanel()
end

--
-- context menu functions
--

function MapEditGUI:openContextMenu(context_name, props)
	local context_table = self.context_menus
	local context_def = context_table[context_name]
	assert(context_def, string.format("No context menu %s defined", context_name))

	local context = context_def:new(props)
	assert(context)

	CONTROL_LOCK.MAPEDIT_CONTEXT.elevate()
	self.curr_context_menu = context
	return context
end

function MapEditGUI:loadContextMenu(cxtm)
	if not cxtm then return end
	CONTROL_LOCK.MAPEDIT_CONTEXT.open()
	self.curr_context_menu = cxtm
	return cxtm
end

function MapEditGUI:exitContextMenu()
	if self.curr_context_menu then
		--self.curr_context_menu:release()
		self.curr_context_menu = nil
	end
	CONTROL_LOCK.MAPEDIT_CONTEXT.queueClose()
end

function MapEditGUI:drawContextMenu()
	local cxtm = self.curr_context_menu
	if not cxtm then return end
	cxtm:draw()
end
function MapEditGUI:updateContextMenu()
	if not self.curr_context_menu then
		self.context_menu_hovered = false
		return
	end
	local x,y = love.mouse.getX(), love.mouse.getY()
	self.context_menu_hovered = self.curr_context_menu:updateHoverInfo(x,y)
end

--
-- context menu functions
--

--
-- popup menu functions
--
function MapEditGUI:displayPopup(str, ...)
	self.curr_popup = popup:throw(str, ...)
end
function MapEditGUI:drawPopup()
	local p = self.curr_popup
	if not p then return end
	p:draw()
end
function MapEditGUI:updatePopupMenu()
	if not self.curr_popup then return end
	local p = self.curr_popup
	if p:expire() then
		p:release()
		self.curr_popup = nil
	end
end
--
-- popup menu functions
--

--
-- main screen panel functions
--
function MapEditGUI:updateMainPanel()
	self.main_panel:update()
end
function MapEditGUI:drawMainPanel()
	self.main_panel:draw()
end
--
--
--

function MapEditGUI:setupInputHandling()
	self.cxtm_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_CONTEXT,
	                                   {"cxtm_select","cxtm_scroll_up","cxtm_scroll_down"})

	local cxtm_select_option = Hook:new(function ()
		local cxtm = self.curr_context_menu
		if not cxtm then
			self:exitContextMenu()
			return
		end
		local hovered_opt = cxtm:getCurrentlyHoveredOption()
		if not hovered_opt then
			self:exitContextMenu()
			return
		end
		local action = hovered_opt.action
		if action then
			local gui_object = action()
			if gui_object then
				self:handleTopLevelThrownObject(gui_object)
			end
		end
		self:exitContextMenu()
	end)
	self.cxtm_input:getEvent("cxtm_select", "down"):addHook(cxtm_select_option)



	self.panel_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_PANEL,
	                                   {"panel_select","window_move"})
	local panel_select_option = Hook:new(function ()
		local m = self.main_panel
		local gui_object = m:click()
		if gui_object then
			self:handleTopLevelThrownObject(obj)
		end
	end)
	self.panel_input:getEvent("panel_select", "down"):addHook(panel_select_option)

	self.win_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_WINDOW,
	                                 {"window_select","window_move"})
	local window_select_option = Hook:new(function ()
		local m = self.main_panel:clickOnWindow()
	end)
	self.win_input:getEvent("window_select", "down"):addHook(window_select_option)

	local window_move_m_start_x = 0
	local window_move_m_start_y = 0
	local window_move_start_x = 0
	local window_move_start_y = 0
	local window_move_flag = false
	local window_move_window = nil

	local window_move_start = Hook:new(function ()
		local win = self.main_panel:getCurrentlyHoveredWindow()
		if not win then return end
		window_move_flag = true
		window_move_m_start_x, window_move_m_start_y = love.mouse.getPosition()
		window_move_window = win
		window_move_start_x, window_move_start_y = win.x, win.y
	end)

	local window_move_action = Hook:new(function ()
		if not window_move_flag then return end
		local win = window_move_window
		if not win then return end
		local x,y = love.mouse.getPosition()
		local dx,dy = x-window_move_m_start_x, y-window_move_m_start_y
		win:setX(window_move_start_x + dx)
		win:setY(window_move_start_y + dy)
	end)

	local window_move_finish = Hook:new(function ()
		window_move_flag = false
	end)

	self.win_input:getEvent("window_move", "down"):addHook(window_move_start)
	self.win_input:getEvent("window_move", "held"):addHook(window_move_action)
	self.win_input:getEvent("window_move", "up"):addHook(window_move_finish)

end

function MapEditGUI:handleTopLevelThrownObject(obj)
	local o_type = provtype(obj)
	if o_type == "mapeditcontextmenu" then
		self:loadContextMenu(obj)
	elseif o_type == "mapeditwindow" then
		self.main_panel:pushWindow(obj)
	end
end

function MapEditGUI:poll()
	self.cxtm_input:poll()
	self.panel_input:poll()
	self.win_input:poll()
end

function MapEditGUI:setTextInputHook(t) 
	if not t then return self.textinput_hook end
	love.keyboard.setKeyRepeat(true)
	self.textinput_hook = t
	return t
end
function MapEditGUI:removeTextInputHook(i)
	if self.textinput_hook == i then
		love.keyboard.setKeyRepeat(false)
		self.textinput_hook = nil
	end
end
function MapEditGUI:textinput(t)
	local hook = self.textinput_hook
	if hook then hook(t) end
end
function MapEditGUI:keypressed(key,scancode,isrepeat)
	if scancode=="backspace" then
		self:textinput("\b")
	elseif scancode=="home" then
		self:textinput("\thome")
	elseif scancode=="end" then
		self:textinput("\tend")
	elseif scancode=="right" then
		self:textinput("\tright")
	elseif scancode=="left" then
		self:textinput("\tleft")
	elseif scancode=="v" then
		local ctrl = scancodeIsPressed("lctrl", CONTROL_LOCK.META) or
		             scancodeIsPressed("rctrl", CONTROL_LOCK.META)
		if ctrl then
			local clipboard = love.system.getClipboardText()
			if clipboard and clipboard ~= "" then
				self:textinput(clipboard)
			end
		end
	end
end

function MapEditGUI:update(dt)
	self:updateMainPanel()
	self:updatePopupMenu()
	self:updateContextMenu()
	self:poll()
end

function MapEditGUI:draw()
	self:drawMainPanel()
	self:drawPopup()
	self:drawContextMenu()
end

return MapEditGUI
