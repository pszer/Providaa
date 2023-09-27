local guirender   = require 'mapeditguidraw'
local contextmenu = require 'mapeditcontext'
local toolbar     = require 'mapedittoolbar'
local popup       = require 'mapeditpopup'

local maptransform = require "mapedittransform"
local transobj     = require "transobj"

local MapEditGUI = {

	context_menus = {},
	toolbars = {},

	curr_context_menu = nil,

}
MapEditGUI.__index = MapEditGUI


function MapEditGUI:define(mapedit)
	local context = self.context_menus
	local toolbars = self.toolbars

	context["select_models_context"] = 
		contextmenu:define(
		{
		 {"select_objects", "table", nil, PropDefaultTable{ProvMapEdit.active_selection}},
		 {"group_flags", "table", nil, PropDefaultTable{create_enable=false,
		                                                merge_groups_enable=false,
		                                                add_to_group_enable=false,
		                                                ungroup_enable=false}}
		}
		,

		 {"Copy",
		  action=function(props)
		    mapedit:copySelectionToClipboard() end,
		  icon = "mapedit/icon_copy.png"},

		 {"Duplicate",
		  action=function(props)
		    mapedit:pasteClipboard() end,
		  icon = "mapedit/icon_dup.png"},

		 {"~b~(orange)Delete",
		  action=function(props)
		    mapedit:commitCommand("delete_obj", {select_objects=props.select_objects}) end,
		  icon = "mapedit/icon_del.png"},

		 {"Group", suboptions = function(props)
		 	return {
			 {"~(green)~bCreate",
			  disable = not props.group_flags.create_enable,
			   action =
			     function()
			       mapedit:commitCommand("create_group", {select_objects=props.select_objects}) end},
			 {"Merge Groups",
			  disable = not props.group_flags.merge_groups_enable,
			   action =
			     function()
			       mapedit:commitCommand("merge_groups", {groups=groups}) end},
			 {"Add To Group",
			  disable = not props.group_flags.add_to_group_enable,
			   action =
			     function()
			       mapedit:commitCommand("add_to_group", {group=groups[1], models=models_outside}) end},
			 {"~(lpurple)Ungroup",
			  disable = not props.group_flags.ungroup_enable,
			   action =
			     function()
			       mapedit:commitCommand("dissolve_groups", {groups=groups, models=models_outside}) end},

			 }
			end},

		 {"--Transform--"},

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
		 )

	context["main_file_context"] =
		contextmenu:define(
		{
		 -- props
		},
		{"Save"},
		{"Quit"}
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
		}
		)
end

function MapEditGUI:openContextMenu(context_name, props)
	local context_table = self.context_menus
	local context_def = context_table[context_name]
	assert(context_def, string.format("No context menu %s defined", context_name))

	local context = context_def:new(props)
	assert(context)

	CONTROL_LOCK.MAPEDIT_CONTEXT.open()

	self.curr_context_menu = context
	return context
end

--
-- context menu functions
--
function MapEditGUI:exitContextMenu()
	if self.curr_context_menu then
		self.curr_context_menu:release()
		self.curr_context_menu = nil
	end
	CONTROL_LOCK.MAPEDIT_CONTEXT.close()
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

function MapEditGUI:update(dt)
	self:updateContextMenu()
	self:updatePopupMenu()
end

function MapEditGUI:draw()
	self:drawContextMenu()
	self:drawPopup()
end

return MapEditGUI
