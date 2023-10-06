--
-- generates thumbnails for models
-- used by the map editor
--

require "render"

local shader = love.graphics.newShader("shader/thumbnail.glsl","shader/thumbnail.glsl")
local cpml = require 'cpml'
local proj = cpml.mat4.from_perspective(75.0, 1, 0.1, 2000)
local depth_c = love.graphics.newCanvas(256,256,{format="depth16"})
local function genThumbnail(model)
	local shader = shader

	local canvas = love.graphics.newCanvas(256,256,{format="rgba4"})
	canvas:setFilter("linear","linear")
	love.graphics.setCanvas{canvas,depthstencil=depth_c}
	love.graphics.setShader(shader)
	
	love.graphics.origin()
	love.graphics.clear(0,0,0,0)
	love.graphics.setColor(1,1,1,1)

	local bbox = model:correctBoundingBox()

	local centre_x = (bbox.min[1] + bbox.max[1])*0.5
	local centre_y = (bbox.min[2] + bbox.max[2])*0.5
	local centre_z = (bbox.min[3] + bbox.max[3])*0.5

	local _x = (bbox.min[1]-centre_x) 
	local _y = (bbox.min[2]-centre_y)
	local _z = (bbox.min[3]-centre_z)
	local radius = (_x^2 + _y^2 + _z^2)^0.5

	local pos = cpml.vec3.new(0.06*radius,0.0*radius,-1.5*radius)
	local trans_v = -cpml.vec3.new(centre_x,centre_y,centre_z) + pos

	local view_m = cpml.mat4.new()
	view_m:translate(view_m,trans_v)

	local model_m = model:getDirectionFixingMatrix()
	local rot = cpml.mat4.new()
	rot:rotate(rot,-math.pi/12,cpml.vec3.unit_y)
	rot:rotate(rot,-math.pi/12,cpml.vec3.unit_x)
	model_m=cpml.mat4.mul(rot,rot,model_m)

	shader:send("u_model", "column", model_m)
	shader:send("u_proj" , "column", proj   )
	shader:send("u_view" , "column", view_m )

	love.graphics.setMeshCullMode("none")
	love.graphics.setDepthMode("less",true)
	love.graphics.draw(model.props.model_mesh)

	love.graphics.setDepthMode()
	love.graphics.setCanvas()
	love.graphics.setShader()

	return canvas
end

return genThumbnail
