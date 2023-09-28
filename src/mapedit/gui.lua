local guirender   = require 'mapedit.guidraw'
local contextmenu = require 'mapedit.context'
local toolbar     = require 'mapedit.toolbar'
local popup       = require 'mapedit.popup'
local guilayout   = require 'mapedit.layout'
local guiscreen   = require 'mapedit.screen'

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
		 {"~bCopy",
		  action=function(props)
		    mapedit:copySelectionToClipboard() end,
			disable = not mapedit:canCopy(),
		  icon = "mapedit/icon_copy.png"},

		 {"Paste",
		  action=function(props)
		    mapedit:pasteClipboard() end,
			disable = not mapedit:canPaste(),
		  icon = "mapedit/icon_dup.png"},

		 {"Undo",
		  action=function(props)
		    mapedit:commitUndo() end,
			disable = not mapedit:canUndo(),
		  icon = nil},

		 {"Redo",
		  action=function(props)
		    mapedit:commitRedo() end,
			disable = not mapedit:canRedo(),
		  icon = nil},

		 {"~b~(orange)Delete",
		  action=function(props)
		    mapedit:commitCommand("delete_obj", {select_objects=props.select_objects}) end,
		  icon = "mapedit/icon_del.png"},

		 {"~(lpurple)Group", suboptions = function(props)
		  local groups = props.group_info.groups
			local models_outside = props.group_info.models_outside
			local name_tab = ""
			if #groups==0 then
				name_tab = "No group"
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
			 {"~(green)~bCreate",
			  disable = not props.group_info.create_enable,
			   action =
			     function()
			       mapedit:commitCommand("create_group", {select_objects=props.select_objects}) end},
			 {"Merge Groups",
			  disable = not props.group_info.merge_groups_enable,
			   action =
			     function()
			       mapedit:commitCommand("merge_groups", {groups=groups}) end},
			 {"Add To Group",
			  disable = not props.group_info.add_to_group_enable,
			   action =
			     function()
			       mapedit:commitCommand("add_to_group", {group=groups[1], models=models_outside}) end},
			 {"~(lpurple)Ungroup",
			  disable = not props.group_info.ungroup_enable,
			   action =
			     function()
			       mapedit:commitCommand("dissolve_groups", {groups=groups, models=models_outside}) end},

			 }
			end},

		 {"~(lgray)--Transform--"},

		 {"Flip", suboptions = function(props)
		  return {
			 {"... by ~i~(lred)X~r Axis",
			  action=
			    function()
			      mapedit:commitCommand("transform", {transform_info=maptransform.flip_x_const}) end},
			 {"... by ~i~(lgreen)Y~r Axis",
			  action=
			    function()
			       mapedit:commitCommand("transform", {transform_info=maptransform.flip_y_const}) end},
			 {"... by ~i~(lblue)Z~r Axis", action=function()
			   mapedit:commitCommand("transform", {transform_info=maptransform.flip_z_const}) end},
			}
		 end},

		 {"Rotate", suboptions = function(props)
		 	return {
			 {"... around ~i~(lred)X~r Axis", suboptions = function(props)
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
			 {"... around ~i~(lgreen)Y~r Axis", suboptions = function(props)
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
			 {"... around ~i~(lblue)Z~r Axis", suboptions = function(props)
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

		 {"~bReset",action=function(props)
		   mapedit:commitCommand("reset_transformation", {select_objects = props.select_objects}) end,
		   icon = nil}
		 end)
	
	context["select_undef_context"] = 
		contextmenu:define(
		{
		}
		,
		function(props) return
		 {"~bCopy",
		  action=function(props)
		    mapedit:copySelectionToClipboard() end,
			disable = true,
		  icon = "mapedit/icon_copy.png"},

		 {"Paste",
		  action=function(props)
		    mapedit:pasteClipboard() end,
			disable = not mapedit:canPaste(),
		  icon = "mapedit/icon_dup.png"},

		 {"Undo",
		  action=function(props)
		    mapedit:commitUndo() end,
			disable = not mapedit:canUndo(),
		  icon = nil},

		 {"Redo",
		  action=function(props)
		    mapedit:commitRedo() end,
			disable = not mapedit:canRedo(),
		  icon = nil},

		 {"~b~(orange)Delete",
		  icon = "mapedit/icon_del.png",
			disable = true},

		 {"~(lpurple)Group", suboptions = function(props) 
	     return {}
			end, disable = true},

		 {"~(lgray)--Transform--"},

		 {"Flip", suboptions = function(props) 
		  return {} end,
		  disable = true},

		 {"Rotate", suboptions = function(props)
		 	return {} end,
		  disable = true},

		 {"~bReset",disable = true, icon = nil}
		 end)

	context["help_context"] = 
		contextmenu:define(
		{
		}
		,
		function(props) return
		 {"Keybinds",
		  action=function(props)
		    return end,
			disable = false},

		 {"Set Language言語あああああああああああ",
		  action=function(props)
		    return end,
			disable = false},

		 {"~iAbout",
		  action=function(props)
		    return end,
			disable = false}
		 end)

	context["main_file_context"] =
		contextmenu:define(
		{
		 -- props
		},
		function(props) return
		{"Save",action=function()end},
		{"~iQuit",action=function()love.event.quit()end}
		end
		)

	toolbars["main_toolbar"] =
		toolbar:define(
		{

		},

		{"File",
		 generate =
		   function(props)
			   return context["main_file_context"], {}
		   end
		},
		{"Edit",
		 generate =
		   function(props)
			   --return context["main_file_context"], {}
				 local cxtn_name, props = mapedit:getSelectionContextMenu()
				 if not cxtn_name then return nil end
				 return context[cxtn_name], props
		   end
		},
		{"Help",
		 generate =
		   function(props)
				 return context["help_context"], {}
		   end
		}
		)

	self.main_toolbar = toolbars["main_toolbar"]:new({},0,0,1000,10,CONTROL_LOCK.MAPEDIT_PANEL)
	local main_toolbar = toolbars["main_toolbar"]:new({},0,0,1000,10)
	--CONTROL_LOCK.MAPEDIT_PANEL.open()
	--

	local panel_layout = guilayout:define(
		{id="toolbar_region",
		 split_type="+y",
		 split_dist=20,
		 sub = {
			id="region1",
			split_type="+x",
			split_dist=160,
		 }
		},

		{"toolbar_region", function(l) return l.x,l.y,l.w,l.h end}
	)

	local w,h = love.graphics.getDimensions()
	self.main_panel = guiscreen:new(
		panel_layout:new(
		  0,0,w,h,{main_toolbar}),
			function(o) self:handleTopLevelThrownObject(o) end,
			CONTROL_LOCK.MAPEDIT_PANEL
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
			action()
		end
		self:exitContextMenu()
	end)
	self.cxtm_input:getEvent("cxtm_select", "down"):addHook(cxtm_select_option)



	self.panel_input = InputHandler:new(CONTROL_LOCK.MAPEDIT_PANEL,
	                                   {"panel_select"})
	local panel_select_option = Hook:new(function ()
		local m = self.main_panel
		m:click()
	end)
	self.panel_input:getEvent("panel_select", "down"):addHook(panel_select_option)



end

function MapEditGUI:handleTopLevelThrownObject(obj)
	local o_type = provtype(obj)
	if o_type == "mapeditcontextmenu" then
		self:loadContextMenu(obj)
	end
end

function MapEditGUI:poll()
	self.cxtm_input:poll()
	self.panel_input:poll()
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
