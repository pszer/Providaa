require "provtype"

Loader = {__type = "loader",

	models   = {__dir="models/"},
	textures = {__dir="img/",  },
	sounds   = {__dir="sfx/",  },
	music    = {__dir="music/",  },
	ttf      = {__dir="ttf/" },

	type_str_to_asset_table = {},

	request_channel  = love.thread.getChannel( "loader_requests" ),
	finished_channel = love.thread.getChannel( "loader_finished" ),

	requests = {},
	requests_count = 0,

	demand_timeout = 5.0

}

Loader.__index = Loader
Loader.type_str_to_asset_table = {
	["model"] = Loader.models,
	["texture"] = Loader.textures,
	["sound"] = Loader.sounds,
	["music"] = Loader.music,
	["ttf"] = Loader.ttf
}

function Loader:sendRequest( type , base_dir , filename )
	local id = self.request_channel:push{ type , fname }
	-- add to list of ongoing requests
	self.requests[base_dir .. filename] = id
	self.requests_count = self.requests_count + 1
end

-- returns true if it popped something
-- otherwise false
-- finished requests are in the format { type , filename , asset , error_str }
-- failed requests have asset set to nil and give an error_str
--
-- if argument demand is set, it demands from the queue with a timeout of Loader.demand_timeout seconds
-- or timeout given
function Loader:popRequest( demand , timeout )
	local data = self.finished_channel:pop()
	if demand and not data then
		data = self.finished_channel:demand( timeout or self.demand_timeout )
	end

	if not data then return false end

	-- remove from active requests
	self.requests_count = self.requests_count - 1

	local asset_type = data[1]
	local filename = data[2]
	local asset = data[3]
	local error_str = data[4]

	local asset_table = self.type_str_to_asset_table[asset_type]
	assert(asset_table)

	if not asset then
		print(string.format("Loader: failed to load %s%s, %s", asset_table.__dir, filename or "(nil)", error_str or ""))
		return true
	end

	asset_table[filename] = asset
	-- remove from active requests
	self.requests[base_dir .. filename] = nil
	return true
end

function Loader:finishQueue()
	while self.requests_count > 0 do
		self:popRequest( true , 0.1)
	end
end

-- the openX functions send a request to load an asset
-- if an asset is needed you use the getX functions
function Loader:openModel(filename)
	assert_type(filename, "string")
	local assets = self.models
	local base_dir = assets.__dir
	if assets[filename] then return end
	self:sendRequest( "model" , base_dir , filename )
end

function Loader:openTexture(filename) 
	assert_type(filename, "string")
	local assets = self.textures
	local base_dir = assets.__dir
	if assets[filename] then return end
	self:sendRequest( "texture" , base_dir , filename )
end

function Loader:openSound(filename)
	assert_type(filename, "string")
	local assets = self.sounds
	local base_dir = assets.__dir
	if assets[filename] then return end
	self:sendRequest( "sound" , base_dir , filename )
end

function Loader:openMusic(filename)
	assert_type(filename, "string")
	local assets = self.music
	local base_dir = assets.__dir
	if assets[filename] then return end
	self:sendRequest( "music" , base_dir , filename )
end

function Loader:openTTF(filename)
	assert_type(filename, "string")
	local assets = self.ttf
	local base_dir = assets.__dir
	if assets[filename] then return end
	self:sendRequest( "ttf" , base_dir , filename )
end
