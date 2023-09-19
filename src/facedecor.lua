-- takes in all the attributes for a complete face
-- and gives a final ModelDecor that can then be
-- given to a model
--

local eyes_atts = require 'cfg/eyes'

require 'cfg/face'
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

	--decor.props.decor_reference = decor_model

	local eyes_data = EyesData:fromCfg(face_props.animface_eyesdata_name)
	if not eyes_data then
		error(string.format("faceDecorFromCfg: eyes %s couldn't be loaded for face %s in FACE_ATTRIBUTES (cfg/face)",
			face_props.animface_eyesdata_name, name))
	end

	--face_props.animface_eyesdata = eyes_data
	--face_props.animface_decor_reference = decor

	local animface = AnimFace:new(face_props)
	animface.props.animface_eyesdata = eyes_data
	animface.props.animface_decor_reference = decor
	decor.props.decor_animated_face = animface

	return decor, animface
end
