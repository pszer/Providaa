-- takes in all the attributes for a complete face
-- and gives a final ModelDecor that can then be
-- given to a model
--

local eyes_atts = require 'cfg/eyes'
local feature_atts = require 'cfg.features'

require 'cfg.face'
local face_decor_atts = FACE_DECOR_ATTRIBUTES
local face_atts = FACE_ATTRIBUTES

require 'modelaccessory'
require 'animatedface'
require 'modelmanager'

-- returns a ModelDecor and AnimFace
function faceFromCfg(name)
	local decor_props = face_decor_atts[name]
	local face_props  = face_atts[name]

	if not decor_props then
		error(string.format("faceDecorFromCfg: %s not found in FACE_DECOR_ATTRIBUTES (cfg/face)", name)) end
	if not face_props then
		error(string.format("faceDecorFromCfg: %s not found in FACE_ATTRIBUTES (cfg/face)", name)) end

	local decor_model = Models.loadModel(decor_props.decor_model_name)
	if not decor_model then
		error(string.format("faceDecorFromCfg: model %s not found for face decor %s in FACE_DECOR_ATTRIBUTES (cfg/face)",
			tostring(decor_props.decor_model_name), name))
	end
	local decor = ModelDecor:newInstance(decor_model, decor_props)

	local eyes_data = EyesData:fromCfg(face_props.animface_eyesdata_name)
	if not eyes_data then
		error(string.format("faceDecorFromCfg: eyes %s couldn't be loaded for face %s in FACE_ATTRIBUTES (cfg/face)",
			face_props.animface_eyesdata_name, name))
	end

	local features_attrs = face_props.animface_features
	local features = {}
	for i,attr in ipairs(features_attrs) do
		local feature = {}
		for i,v in pairs(attr) do
			feature[i]=v
		end

		local f_name = feature.name
		if not f_name then
			error(string.format("faceDecorFromCfg: %s, no name supplied for face feature at index %d supplied", name, i))
		end

		local feature_attrs = feature_atts[f_name]
		if not feature_attrs then
			error(string.format("faceDecorFromCfg: %s, no feature with name %s found in FACE_DECOR_ATTRIBUTES (cfg/features)", name, tostring(f_name)))
		end

		local feature_data = FacialFeatureData:fromCfg(f_name)
		if not feature_data then
			error(string.format("faceDecorFromCfg: %s, error loading feature with name %s", name, tostring(f_name)))
		end

		feature.data = feature_data
		table.insert(features, feature)
	end

	face_props.animface_eyesdata = eyes_data
	face_props.animface_features = features
	face_props.animface_decor_reference = decor
	local animface = AnimFace:new(face_props)
	decor.props.decor_animated_face = animface

	return decor, animface
end
