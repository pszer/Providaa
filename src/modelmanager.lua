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
function Models.loadModels()
	print("loading from cfg/model_attributes (Model.loadModels() should not be used!)")
	for i,v in pairs(model_attributes) do
		Models.loadModel(i)
	end
end
