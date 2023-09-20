require "model"
require "texturemanager"
require "assetloader"

local model_attributes = require 'cfg.model_attributes'
local iqm = require 'iqm-exm'
local cpml = require 'cpml'

Models = {
	loaded = {},
}
Models.__index = Models

-- a simple query
function Models.queryModel(fname)
	local model = Models.loaded[fname]
	if model then
		return model
	else
		return nil
	end
end

function Models.isModelLoaded(fname)
	return Models.loaded[fname] ~= nil
end

function Models.loadModel(fname)
	if Models.isModelLoaded(fname) then return Models.queryModel(fname) end -- do nothing if already loaded

	local attributes = model_attributes[fname] or {}
	local texture    = attributes["model_texture_fname"]
	--local model = Models.openFilename(fname, texture, true)
	local model = Model:fromLoader(fname)
	if model then Models.loaded[fname] = model end
	return model
end

-- loads all models in cfg/model_attributes
-- not a good idea
--[[function Models.loadModels()
	print("loading from cfg/model_attributes (Model.loadModels() should not be used!)")
	for i,v in pairs(model_attributes) do
		Models.loadModel(i)
	end
end--]]

-- releases all currently loaded models apart from entries given in it's set
-- argument
-- if called with an empty set then it releases ALL loaded models
function Models.releaseModelsOutsideSet( set )
	assert( type(set) == "table" )

	local function in_set(set,x)
		for i,v in ipairs(set) do
			if v == x then return true end
		end
		return false
	end

	for name,model in pairs(Models.loaded) do
		if not in_set(set, model) then
			model:release()
		end
	end
end
