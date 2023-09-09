--[[ property table prototype for model object
--]]
--

require "prop"

ModelPropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"model_name"         , "string", "", nil, "model's name" },
	{"model_texture_fname", "string", "", nil, "model's texture filename"},

	{"model_position", "table", nil, PropDefaultTable{0,0,0}, "model's world position", "readonly"},
	{"model_rotation", "table", nil, PropDefaultTable{0,0,0}, "model's world rotation"},
	{"model_scale"   , "table", nil, PropDefaultTable{1,1,1}, "model's scale"},

	{"model_up_vector" , "table", { 0 , -1 ,  0 }, nil, "model`s upward pointing vector",  "readonly"},
	{"model_dir_vector", "table", { 0 ,  0 , -1 }, nil,  "model`s forward pointing vector", "readonly"},
	{"model_vertex_winding", "string", "ccw", PropIsOneOf{"ccw","cw"},  "vertex winding for this model`s mesh", "readonly"},

	{"model_mesh", nil, nil, nil, "model's mesh object"},

	{"model_animations", nil, nil, nil, "model's animations"},
	{"model_skeleton"  , nil, nil, nil, "model's skeleton"},
	{"model_animated"  , "boolean", false, nil, "is model animated?"}
}

ModelInstancePropPrototype = Props:prototype{

	-- prop      prop     prop default    prop input     prop      read
	-- name      type        value        validation     info      only

	{"model_i_reference", nil, nil, nil, "the model this instance is referencing" },

	{"model_i_position", "table", nil, PropDefaultTable{0,0,0}, "model's world position, don't change directly use setPosition"},
	{"model_i_rotation", "table", nil, PropDefaultTable{0,0,0}, "model's world rotation, don't change directly use setRotation"},
	{"model_i_scale"   , "table", nil, PropDefaultTable{1,1,1}, "model's scale, don't change directly use setScale"},

	{"model_i_outline_flag", "boolean", false, nil,                     "whether to draw an outline around this model"},
	{"model_i_outline_colour", "table", nil, PropDefaultTable{0,0,0,1}, "model's outline colour"},
	{"model_i_outline_scale", "number", 1.03, nil,                      "model's outline scale factor"},
	{"model_i_contour_flag", "boolean", false},

	{"model_i_static"    , "boolean", false, nil, "is model instance static?"},

	{"model_i_draw_instances", "boolean", false, nil, [[only for static models, if true then model is drawn several times with different
	                                                   positions, rotations, scale specified in model_i_instances using GPU instancing]], "readonly"},
	{"model_i_instances", "table", nil, PropDefaultTable{}, [[a table of the instances to be drawn of this model with GPU instancing, each entry
	                                                          is of the form {position={x,y,z}, rotation={pitch,yaw,roll}, scale={x,y,z}}.
													     	  these instances do NOT inherit properties from this ModelInstance object

															  once a ModelInstance is created, this table should have a member called ["mesh"]
															  with the vertex attributes for each instane (see love.graphics.drawInstanced())
															  ]], "readonly"},
	{"model_i_instances_count", "number", 0, nil, "count of instances in model_i_instances", "readonly"},

	{"model_i_decorations", "table", nil, PropDefaultTable{}, "model's ModelDecor objects"}
												
}
