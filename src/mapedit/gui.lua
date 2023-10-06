local guirender   = require 'mapedit.guidraw'
local contextmenu = require 'mapedit.context'
local toolbar     = require 'mapedit.toolbar'
local popup       = require 'mapedit.popup'
local guilayout   = require 'mapedit.layout'
local guiscreen   = require 'mapedit.screen'
local guiwindow   = require 'mapedit.window'
local guitextbox  = require 'mapedit.textelement'
local guibutton   = require 'mapedit.button'
local guiimage    = require 'mapedit.image'
local guiscrollb  = require 'mapedit.scrollbar'
local guiimggrid  = require 'mapedit.gridselection'

local export_map = require 'mapedit.export'
local lang = require 'mapedit.guilang'

local maptransform = require "mapedit.transform"

local transobj     = require "transobj"

require "inputhandler"
require "input"

local MapEditGUI = {

	context_menus = {},
	toolbars = {},

	main_panel = nil,

	curr_context_menu = nil,
	curr_popup = nil,
	
	main_toolbar = nil,

	cxtm_input = nil

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

	context["select_models_context"] = 
		contextmenu:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable{ProvMapEdit.active_selection}},
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
		   icon = nil}
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

		 {lang["~bReset"],disable = true, icon = nil}
		 end)

	local region_default_f = function(l) return l.x, l.y, l.w, l.h end
	local region_middle_f = function(l) return l.x+l.w*0.5, l.y+l.h*0.5, l.w, l.h end
	local region_offset_f = function(_x,_y) return function(l) return l.x+l.w*_x, l.y+l.h*_y, l.w, l.h end end
	local region_pixoffset_f = function(_x,_y) return function(l) return l.x+_x, l.y+_y, l.w, l.h end end
	local region_ypixoffset_f = function(_x,_y) return function(l) return l.x+l.w*_x, l.y+_y, l.w, l.h end end

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
			--[[local result, log = export_map(mapedit.props)
			for i,v in ipairs(log) do
				print(v)
			end
			print()
			print(result)--]]
			mapedit:exportAndWriteToFile("test2.lua")
		end},
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
			guitextbox:new(lang["[Drop file here]"],0,0,300,"left","middle","bottom"),
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
		end
	)
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

	self.grid_info_panel_image = guiimage:new(nil,0,0,96,96,function() self:displayPopup("~b~(red)Do not click the kappa.") end,
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
							MapEditGUI:displayPopup(status,5.5)
						end
					end
				end,
				"left", "top")
		},
		0,0,300,100
	)

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
		{"viewport_region", region_pixoffset_f(0,0)}
	)

	local w,h = love.graphics.getDimensions()
	self.main_panel = guiscreen:new(
		panel_layout:new(
		  0,0,w,h,{main_toolbar, self.texture_grid, grid_info_panel_window}),
			function(o) self:handleTopLevelThrownObject(o) end,
			CONTROL_LOCK.MAPEDIT_PANEL,
			CONTROL_LOCK.MAPEDIT_WINDOW
	)
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
