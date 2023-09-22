require "map"
require "props/mapeditprops"

require "mapeditcommand"

ProvMapEdit = {}
ProvMapEdit.__index = ProvMapEdit

function ProvMapEdit:load(args)
	
	local lvledit_arg = args["lvledit"]
	assert(lvledit_arg and lvledit_arg[1], "ProvMapEdit:load(): no level specified in lvl edit launch argument")
	local map_name = lvledit_arg[1]
	local map_file, err = pcall(function() return dofile(map.__dir .. map_name) end)

	if not map_file then
		print(string.format("ProvMapEdit:load(): error, no map file %s%s found",map.__dir .. map_name))
	end
end
