--[[ keybinds are stored here
--]]
--

VALID_SCANCODES = {
"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
"1","2","3","4","5","6","7","8","9","0",
"return","escape","backspace","tab","space","-","=","[","]","\\","#","*","@","?",";","'","`",",",".","/",
"capslock","f1","f2","f3","f4","f5","f6","f7","f8","f9","f10","f11","f12","f13","f14","f15","f16","f17","f18","f19","f20","f21","f22","f23","f24",
"lctrl","lshift","lalt","lgui","rctrl","rshift","ralt","rgui","printscreen","scrolllock","pause","insert","home",
"numlock","pageup","delete","end","pagedown","right","left","down","up","nonusbackslash","application","execute",
"help","menu","select","stop","again","undo","cut","copy","paste","find","kp/","kp*","kp-","kp+","kp=","kpenter",
"kp1","kp2","kp3","kp4","kp5","kp6","kp7","kp8","kp9","kp0","kp.",
"international1","international2","international3","international4","international5","international6","international7","international8","international9","lang1","lang2","lang3","lang4","lang5",
"mute","volumeup","volumedown","audionext","audioprev","audiostop","audioplay","audiomute","mediaselect",
"www","mail","calculator","computer","acsearch","achome","acback","acforward","acstop","acrefresh","acbookmarks",
"power","brightnessdown","brightnessup","displayswitch","kbdillumtoggle","kbdillumdown","kbdillumup","eject",
"sleep","alterase","sysreq","cancel","clear","prior","return2","separator","out","oper","clearagain","crsel",
"exsel","kp00","kp000","thsousandsseparator","decimalseparator","currencyunit","currencysubunit","app1","app2","unknown",
--
"mouse1","mouse2","mouse3","mouse4","mouse5",
"wheelup","wheeldown"
}

for i,v in ipairs(VALID_SCANCODES) do
	VALID_SCANCODES[v] = true
end

function IS_VALID_SCANCODE(sc)
	if VALID_SCANCODES[sc] then return true end
	return false
end

-- each key_setting can have two keybinds
GAME_KEY_SETTINGS = {

	["move_left"]  = { "left"  , "a" , default = "left"  },
	["move_right"] = { "right" , "d" , default = "right" },
	["move_up"]    = { "up"    , "w" , default = "up"    },
	["move_down"]  = { "down"  , "s" , default = "down"  },
	["action"]     = { "z"     , "space" , default = "z" },
	["back"]       = { "x"     , "lctrl" , default = "x" },
	["hop"]        = { "space" , nil , default = "space" }

}

MAPEDIT_KEY_SETTINGS = {

	["cam_left"]     = { "a"      , nil    , default = "a"     },
	["cam_right"]    = { "d"      , nil    , default = "d"     },
	["cam_forward"]  = { "w"      , nil    , default = "w"     },
	["cam_backward"] = { "s"      , nil    , default = "s"     },
	["cam_up"]       = { "up"     , "space", default = "up"    },
	["cam_down"]     = { "down"   , nil    , default = "down"  },
	["cam_rotate"]   = { "mouse3" , nil    , default = "mouse3" },
	["cam_reset"]    = { "kp0"    , "home" , default = "kp0"   },
	["cam_centre"]   = { "kp."    , "home" , default = "kp."   },
	["cam_zoom_in"]  = { "wheeldown", nil   , default = "wheeldown"},
	["cam_zoom_out"] = { "wheelup" , nil   , default = "wheelup"},

	["super"]           = { "lshift" , nil    , default = "lshift"},
	["ctrl"]            = { "lctrl"  , nil    , default = "lctrl"},
	["alt"]             = { "lalt"   , nil    , default = "lalt"},
	["toggle_anim_tex"] = { "f3"     , nil    , default = "f3"},
	["cycle_vision"]    = { "f9"     , nil    , default = "f9"},

	["edit_select"]     = { "mouse1"   ,  nil   , default = "mouse1" },
	["edit_deselect"]   = { "mouse2"   ,  "q"   , default = "mouse2" },
	["edit_undo"]       = { "pagedown" ,  nil   , default = "mouse2" },
	["edit_redo"]       = { "pageup"   ,  nil   , default = "mouse2" },
	["edit_cycle_tool"] = { "tab"      ,  nil   , default = "tab" },
	["edit_edit_tool"]  = { "1"        ,  nil   , default = "1" },
	["edit_paint_tool"] = { "2"        ,  nil   , default = "2" },
	["edit_overlay_toggle"] = { "o"        ,  nil   , default = "o" },

	["transform_move"]   = { "g"      , nil , default = "g" },
	["transform_rotate"] = { "r"      , nil , default = "r" },
	["transform_scale"]  = { "e"      , nil , default = "p" },
	["transform_cancel"] = { "mouse2" , nil , default = "mouse2" },
	["transform_commit"] = { "mouse1" , nil , default = "mouse1" },
	["transform_x_axis"] = { "x" , nil, default = "x" },
	["transform_y_axis"] = { "y" , nil, default = "y" },
	["transform_z_axis"] = { "z" , nil, default = "z" },

	["cxtm_select"] = { "mouse1" , nil , default = "mouse1" },
	["cxtm_scroll_up"]   = { "up"   , "wheelup"   , default = "up" },
	["cxtm_scroll_down"] = { "down" , "wheeldown" , default = "down" },

	["panel_select"] = { "mouse1" , nil , default = "mouse1" },

	["window_select"] = { "mouse1" , nil , default = "mouse1" },
	["window_move"]   = { "mouse3" , nil , default = "mouse3" },

}

KEY_SETTINGS = GAME_KEY_SETTINGS

function SET_ACTIVE_KEYBINDS(settings)
	KEY_SETTINGS = settings
end

function SET_KEYBIND(bind, scancode)
	if not IS_VALID_SCANCODE(scancode) then
		print(scancode, "is not a valid scancode")
	else
		KEYBINDS[bind] = scancode
	end
end

function keySetting( setting )
	local s = KEY_SETTINGS[setting]
	local s1,s2 = s[1],s[2]

	if not (s1 or s2) then
		return s[s.default], nil
	end

	if s1 then
		return s1,s2 end
	return s2, nil
end

function keyChangeSetting( setting , new_scancode , slot , force_unique_keybinds )
	local slot = slot or 1
	if slot ~= 1 and slot ~= 2 then slot = 1 end

	local is_valid = IS_VALID_SCANCODE(new_scancode)
	if not is_valid then
		print(string.format("keyChangeSetting: \"%s\" is an invalid scancode", new_scancode))
		return
	end

	local s = KEY_SETTINGS[setting]
	if not s then
		print(string.format("keyChangeSetting: no setting \"%s\" exists", setting))
		return
	end

	-- overwrite settings for other keys with same scancode
	-- if force_unique_keybinds
	if force_unique_keybinds then
		for i,set in pairs(KEY_SETTINGS) do
			local overwrite = false
			if set[1] == new_scancode then set[1] = nil overwrite = true end
			if set[2] == new_scancode then set[2] = nil overwrite = true end
			if overwrite then
				print(string.format("keyChangeSetting: changing keybind \"%s\" to \"%s\", setting \"%s\" already bound to \"%s\", over-writing",
					setting, new_scancode, i, new_scancode))
			end
		end
	end

	s[slot] = new_scancode
end

function keyRevertDefault( setting )
	local s = KEY_SETTINGS[setting]
	if not s then
		print(string.format("keyRevertDefault: no setting \"%s\" exists", setting))
	end

	s[1] = s.default
end
