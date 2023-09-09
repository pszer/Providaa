require "model"
require "texturemanager"

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
	local model = Models.openFilename(fname, texture, true)
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

function Models.openFilename(fname, texture_fname, load_anims)
	local fpath = "models/" .. fname

	local attributes = model_attributes[fname] or {}
	local winding    = attributes["model_vertex_winding"] or "ccw"

	local objs = Models.readIQM(fpath)

	if not objs then
		print("Models.openFilename(): model " .. fname .. " does not exist")
	end

	local texture = Textures.loadTexture(texture_fname)

	local mesh = Mesh.newFromMesh(objs.mesh, texture)
	local anims = nil
	local skeleton = nil
	local has_anims = false

	if load_anims and objs.has_anims then
		anims = Models.openAnimations(fname)
		skeleton = anims.skeleton
		has_anims = true
	end

	local model = Model:new{
		["model_name"] = fname,
		["model_texture_fname"] = texture_fname,
		["model_vertex_winding"] = winding,
		["model_mesh"] = mesh,
		["model_skeleton"] = skeleton,
		["model_animations"] = anims,
		["model_animated"] = has_anims
	}

	if load_anims and objs.has_anims then
		model:generateBaseFrames()
		model:generateAnimationFrames()
	end

	model:generateDirectionFixingMatrix()

	return model
end

function Models.openAnimations(fname)
	local fpath = "models/" .. fname
	local anims = Models.readIQMAnimations(fpath)
	if not anims then
		local fpath = "anims/" .. fname
		anims = Models.readIQMAnimations(fpath)
	end
	return anims
end

function Models.readIQM(fname)
	local finfo = love.filesystem.getInfo(fname)
	if not finfo or finfo.type ~= "file" then return nil end

	local objs = iqm.load(fname)
	if not objs then return nil end

	return objs
end

function Models.readIQMAnimations(fname)
	local finfo = love.filesystem.getInfo(fname)
	if not finfo or finfo.type ~= "file" then return nil end

	local anims = iqm.load_anims(fname)
	if not anims then return nil end

	return anims
end
