local custom_atts = require "cfg.custommodel"

require "modelmanager"
require "model"
require "facedecor"

CustomModel = {}
CustomModel.__index = CustomModel

function CustomModel:fromCfg(name)
	local props = custom_atts[name]
	if not props then
		error(string.format("CustomModel:fromCfg: no custom model %s found in cfg/custommodel", name))
	end
	return self:load(props)
end

function CustomModel:load(props)
	local model_name = props.model_name
	local model_face = props.model_face
	local model_contour = props.model_contour

	local model_contour_colour = props.model_contour_colour
	if model_contour_colour then
		model_contour_colour = {unpack(model_contour_colour)}
	end

	local model_ref = Models.loadModel(model_name)
	assert(model_ref)

	local decor,animface = nil,nil
	if model_face then
		decor,animface = faceFromCfg(model_face)
	end

	local inst = ModelInstance:newInstance(model_ref,
	{
		["model_i_outline_flag"] = model_contour,
		["model_i_contour_flag"] = model_contour,
		["model_i_outline_colour"] = model_contour_colour,
	})

	inst:attachDecoration(decor)
	return inst
end
