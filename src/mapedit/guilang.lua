local __lang_fonts = {
	eng = {
		regular = {fname = "AnonymousPro-Regular.ttf"   ,size=12,hinting="normal"},
		bold    = {fname = "AnonymousPro-Bold.ttf"      ,size=12,hinting="normal"},
		italic  = {fname = "AnonymousPro-Italic.ttf"    ,size=12,hinting="normal"},
		ibold   = {fname = "AnonymousPro-BoldItalic.ttf",size=12,hinting="normal"},
	},

	pl = {
		regular = {fname = "AnonymousPro-Regular.ttf"   ,size=12,hinting="normal"},
		bold    = {fname = "AnonymousPro-Bold.ttf"      ,size=12,hinting="normal"},
		italic  = {fname = "AnonymousPro-Italic.ttf"    ,size=12,hinting="normal"},
		ibold   = {fname = "AnonymousPro-BoldItalic.ttf",size=12,hinting="normal"},
	},

	jp = {
		regular = {fname = "KH-Dot-Kodenmachou-12.ttf"   ,size=12,hinting="normal"},
		bold    = {fname = "KH-Dot-Kodenmachou-12-Ki.ttf",size=12,hinting="normal"},
		italic  = {fname = "KH-Dot-Kodenmachou-12-Ki.ttf",size=12,hinting="normal"},
		ibold   = {fname = "KH-Dot-Kodenmachou-12-Ki.ttf",size=12,hinting="normal"},
	}
}

local MapEditGUILanguage = {
	__supported = {"eng","pl","jp"},
	__curr_lang = "jp",
}

local MapEditGUILanguageStrings = {
	["~bCopy"] = {
		pl="~bKopiuj",
		jp="写す",
	},
	["Paste"] = {
		pl="~bPrzyklei",
		jp="張る",
	},
	["Undo"] = {
		pl="Cofnij",
		jp="アンドゥ",
	},
	["Redo"] = {
		pl="Przerób",
		jp="リドゥ",
	},
	["~b~(orange)Delete"]={
		pl="~b~(orange)Skasuj",
		jp="~b~(orange)削除する",
	},
	["~(lpurple)Group"]={
		pl="~(lpurple)Grupa",
		jp="~(lpurple)モデル組",
	},
	["~(green)~bCreate"]={
		pl="~(green)~bUtwórz Grupę",
		jp="~(green)~b作る",
	},
	["Merge Groups"]={
		pl="Połącz Grupy",
		jp="モデル組を合わせる"
	},
	["Add To Group"]={
		pl="Dodaj do Grupy",
		jp="モデル組を加える"
	},
	["~(lpurple)Ungroup"]={
		pl="~(lpurple)Rozgrupuj",
		jp="モデル組を解く"
	},
	["No group"]={
		pl="Nie ma grupy",
		jp="選んでされた組はない",
	},

	["~(lgray)--Transform--"]={
		pl="~(lgray)--Transformuj--",
		jp="~(lgray)トランスフォーマー"
	},
	["Flip"]={
		pl="Odbij",
		jp="反転する",
	},

	["... by ~i~(lred)X~r Axis"]={
		pl="... względem Osi ~i~(lred)X~r",
		jp="。。~i~(lred)Ｘ~rの軸に対して",
	},
	["... by ~i~(lgreen)Y~r Axis"]={
		pl="... względem Osi ~i~(lgreen)Y~r",
		jp="。。~i~(lgreen)Ｙ~rの軸に対して",
	},
	["... by ~i~(lblue)Z~r Axis"]={
		pl="... względem Osi ~i~(lblue)Z~r",
		jp="。。~i~(lblue)Ｚ~rの軸に対して",
	},

	["Rotate"]={
		pl="Obróć",
		jp="~b回転~rする",
	},
	["... around ~i~(lred)X~r Axis"]={
		pl="... dookoła Oś ~i~(lred)X~r",
		jp="。。~i~(lred)Ｘ~rの軸を中心に",
	},
	["... around ~i~(lgreen)Y~r Axis"]={
		pl="... dookoła Oś ~i~(lgreen)Y~r",
		jp="。。~i~(lgreen)Ｙ~rの軸を中心に",
	},
	["... around ~i~(lblue)Z~r Axis"]={
		pl="... dookoła Oś ~i~(lblue)Z~r",
		jp="。。~i~(lblue)Ｚ~rの軸を中心に",
	},
	["~bReset"]={
		pl="Zresetuj",
		jp="リセット",
	},
	["Keybinds"]={
		pl="Ustawienia klawiatury",
		jp="入力設定",
	},
	["Set Language"]={
		pl="Zmień język",
		jp="言語を設定する",
	},
	["~iAbout"]={
		pl="Informacja",
		jp="プログラムについて",
	},
	["~b~(red)Do not click the kappa."]={
		pl="~b~(red)Nie klikaj kappy.",
		jp="~b~(red)カッパを押すな",
	},
	["\nHello :)\n\nKappa map editor © 2023 \nMIT license (see LICENSE.md)"]={
		pl="\nCześć :)\n\nKappa edytor map © 2023 \nMIT licencja\n(zobacz LICENSE.md)",
		jp="\n いらっしゃいませ :)\n\nカッパのマップのエディター(C) 2023\nMIT特許\n(LICENSE.mdを検問しますください)",
	},
	["~bClose."]={
		pl="~bZamknij",
		jp="~b閉じる",
	},
	["Save"]={
		pl="Zapisz",
		jp="セーブ"
	},
	["~iQuit"]={
		pl="~iWyjdź",
		jp="~i出る"
	},
	["File"]={
		pl="Plik",
		jp="ファイル",
	},
	["Edit"]={
		pl="Edytuj",
		jp="変える",
	},
	["Help"]={
		pl="Pomoca",
		jp="介助",
	},
	["Import"]={
		pl="Importuj",
		jp="輸入する",
	},
	["Delete"]={
		pl="Skasuj",
		jp="削除する",
	},

	["default_group_name"]={
		eng="Group",
		pl ="Grupa",
		jp ="組",
	}
}

function MapEditGUILanguage:setLanguage(lang)
	assert(lang and type(lang)=="string")
	local supported = false
	for i,v in ipairs(self.__supported) do
		if v == lang then supported = true break end
	end
	if not supported then
		error(string.format("Unsupported language %s",lang))
	end

	self.__curr_lang = lang
end

function MapEditGUILanguage:getFontInfo()
	local curr_lang = MapEditGUILanguage.__curr_lang
	return __lang_fonts[curr_lang]
end

MapEditGUILanguage.__index = function(table, key)
	local curr_lang = MapEditGUILanguage.__curr_lang

	local t = MapEditGUILanguageStrings[key]
	if t and not t["eng"] and curr_lang=="eng" then
		local key = key
		if key == "" then return " " end
		return key
	end

	if t then
		local S = t[curr_lang]
		if S then
			if S == "" then return " " end
			return S
		end
	end

	return key
end
setmetatable(MapEditGUILanguage, MapEditGUILanguage)
return MapEditGUILanguage
