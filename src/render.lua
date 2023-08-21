require 'math'

require "camera"
require "resolution"
require "3d"

require "texture"

--CAM = Camera:new()

Renderer = {
	--vertex_shader = love.graphics.newShader("shader/vertex.glsl")
	vertex_shader = nil,
	skybox_shader = nil,

	skybox_model = nil,

	scene_viewport = nil,
	scene_depthbuffer = nil,

	viewport_w = 1000,
	viewport_h = 1000,

	fps_draw_obj = nil
}

Renderer.__index = Renderer

function Renderer.loadShaders()
	Renderer.vertex_shader = love.graphics.newShader("shader/vertex.glsl")
	Renderer.skybox_shader = love.graphics.newShader("shader/skybox.glsl")
end

function Renderer.setupSkyboxModel()
	local vertices = {
        -- Top
        {-1, -1, 1}, {1, -1, 1},
        {1, 1, 1}, {-1, 1, 1},

        -- Bottom
        {1, -1, -1}, {-1, -1, -1},
        {-1, 1, -1}, {1, 1, -1},

        -- Front
        {-1, -1, -1}, {1, -1, -1},
        {1, -1, 1}, {-1, -1, 1},

        -- Back
        {1, 1, -1}, {-1, 1, -1},
        {-1, 1, 1}, {1, 1, 1},

        -- Right
        {1, -1, -1}, {1, 1, -1},
        {1, 1, 1}, {1, -1, 1},

        -- Left
        {-1, 1, -1}, {-1, -1, -1},
        {-1, -1, 1}, {-1, 1, 1}
	}

    local indices = {
        1, 2, 3, 3, 4, 1,
        5, 6, 7, 7, 8, 5,
        9, 10, 11, 11, 12, 9,
        13, 14, 15, 15, 16, 13,
        17, 18, 19, 19, 20, 17,
        21, 22, 23, 23, 24, 21,
    }

    local layout = {
        {"VertexPosition", "float", 3},
    }

	Renderer.skybox_model = love.graphics.newMesh(layout, vertices, "triangles", "static")
	Renderer.skybox_model:setVertexMap(indices)
end

function Renderer.renderScaled(canvas)
	canvas = canvas or Renderer.scene_viewport

	love.graphics.setCanvas()
	love.graphics.origin()
	love.graphics.scale(RESOLUTION_RATIO)

	local w,h = get_resolution()
	local W,H = love.graphics.getWidth() / RESOLUTION_RATIO, love.graphics.getHeight() / RESOLUTION_RATIO
	local wpad, hpad = 0,0

	if RESOLUTION_PADW then
		wpad = (W-w)/2
	else
		hpad = (H-h)/2
	end

	love.graphics.draw( canvas, wpad,hpad )
end

function Renderer.createCanvas()
	local w,h = get_resolution()

	Renderer.scene_viewport    = love.graphics.newCanvas (w,h, {format = "rgba8"})
	Renderer.scene_depthbuffer = love.graphics.newCanvas (w,h, {format = "depth24"})
	Renderer.viewport_w = w
	Renderer.viewport_h = h
end

function Renderer.transformCoordsFor3D()
	local w,h = Renderer.viewport_w, Renderer.viewport_h
	love.graphics.origin()
	love.graphics.scale(w/2,h/2)
	love.graphics.translate(1,1)
end

function Renderer.setupCanvasFor3D()
	if not Renderer.scene_viewport then
		Renderer.createCanvas()
	end

	love.graphics.setCanvas{Renderer.scene_viewport, depthstencil = Renderer.scene_depthbuffer, depth=true}
	love.graphics.setDepthMode( "less", true  )
	love.graphics.setMeshCullMode("front")

	love.graphics.setShader(Renderer.vertex_shader, Renderer.vertex_shader)
	
	love.graphics.origin()
	Renderer.transformCoordsFor3D()
end

function Renderer.setupCanvasForSkybox()
	love.graphics.setMeshCullMode("none")
	love.graphics.setDepthMode( "always", false )
	love.graphics.setCanvas(Renderer.scene_viewport)
	love.graphics.setShader(Renderer.skybox_shader, Renderer.skybox_shader)

	love.graphics.origin()
	Renderer.transformCoordsFor3D()
end

function Renderer.dropCanvas()
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.setDepthMode()
	love.graphics.setMeshCullMode("none")
	love.graphics.origin()
end

function Renderer.drawFPS()
	love.graphics.push("all")
	love.graphics.reset()

	local text = tostring(FPS)

	if not Renderer.fps_draw_obj then
		Renderer.fps_draw_obj = love.graphics.newText(love.graphics.getFont(), text)
	end
	Renderer.fps_draw_obj:set(text)

	love.graphics.setColor(0,0,0,0.3)

	local sw,sh = love.graphics.getDimensions()
	local w,h = Renderer.fps_draw_obj:getWidth(), Renderer.fps_draw_obj:getHeight()

	local rw,rh=w+6,h+6
	love.graphics.rectangle("fill",sw-rw,0,rw,rh)

	if (FPS < 60) then
		love.graphics.setColor(1,0,0,1)
	elseif (FPS < 120) then
		love.graphics.setColor(1,1,0,1)
	else
		love.graphics.setColor(0,1,0,1)
	end
	love.graphics.draw(Renderer.fps_draw_obj, sw-w-3,3)
	love.graphics.pop()
end
