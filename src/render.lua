require 'math'

require "camera"
require "resolution"
require "texturemanager"
require "bloom"
local shadersend = require 'shadersend'

--CAM = Camera:new()

Renderer = {
	--vertex_shader = love.graphics.newShader("shader/vertex.glsl")
	vertex_shader  = nil,
	skybox_shader  = nil,
	shadow_shader  = nil,
	avglum_shader  = nil,
	outline_shader = nil, 
	contour_shader = nil,
	hdr_shader     = nil,
	mask_shader    = nil,
	facecomp_shader= nil,
	dt_exposure_shader = nil,

	skybox_model = nil,

	scene_viewport               = nil,
	scene_postprocess_viewport   = nil,
	scene_outline_viewport       = nil,
	scene_buffer  = {nil, nil},
	scene_postprocess_viewport   = nil,
	scene_depthbuffer   = nil,

	scene_avglum_buffer = nil,
	scene_dt_exposure_buffer = nil,

	bloom_renderer = nil,

	viewport_w = 1000,
	viewport_h = 1000,

	enable_hdr = true,
	hdr_exposure = 0.15,
	hdr_exposure_min = 0.1,
	hdr_exposure_max = 2.0,
	hdr_exposure_nudge = 1.08,
	hdr_exposure_adjust_speed = 2.5,

	fps_draw_obj = nil,

	avglum_buffer_size = 1024,
	avglum_mipmap_count = -1,

	nil_cubemap = nil,
}

Renderer.__index = Renderer

function Renderer.load()
	love.graphics.setDefaultFilter( "nearest", "nearest" )
	Renderer.loadShaders()
	Renderer.createCanvas()
	Renderer.setupSkyboxModel()
end

function Renderer.loadShaders()
	Renderer.vertex_shader  = love.graphics.newShader("shader/vertex.glsl")
	Renderer.contour_shader = love.graphics.newShader("shader/contour.glsl")
	Renderer.skybox_shader  = love.graphics.newShader("shader/skybox.glsl")
	Renderer.shadow_shader  = love.graphics.newShader("shader/shadow.glsl")
	Renderer.avglum_shader  = love.graphics.newShader("shader/avglum.glsl")
	Renderer.hdr_shader     = love.graphics.newShader("shader/hdr.glsl")
	Renderer.outline_shader = love.graphics.newShader("shader/outline.glsl")
	Renderer.blur_shader    = love.graphics.newShader("shader/blur.glsl")
	Renderer.mask_shader    = love.graphics.newShader("shader/mask.glsl")
	Renderer.facecomp_shader= love.graphics.newShader("shader/facecomposite.glsl")
	Renderer.dt_exposure_shader  = love.graphics.newShader("shader/dt_exposure.glsl")
end

function Renderer.createCanvas()
	local w,h = get_resolution()

	local function release_if_exists(canv) if canv then canv:release() end end

	release_if_exists(Renderer.scene_viewport)
	release_if_exists(Renderer.scene_postprocess_viewport)
	release_if_exists(Renderer.scene_bloom_viewport)
	release_if_exists(Renderer.scene_buffer[1])
	release_if_exists(Renderer.scene_buffer[2])
	release_if_exists(Renderer.scene_avglum_buffer)
	release_if_exists(Renderer.scene_dt_exposure_buffer)
	release_if_exists(Renderer.scene_outline_viewport)
	release_if_exists(Renderer.scene_outline_depthbuffer)

	Renderer.scene_viewport                   = love.graphics.newCanvas (w,h, {format = "rgba16f"})
	Renderer.scene_postprocess_viewport       = love.graphics.newCanvas (w,h, {format = "rgba16f"})
	Renderer.scene_bloom_viewport             = love.graphics.newCanvas (w,h, {format = "rgba16f"})
	Renderer.scene_buffer[1] = love.graphics.newCanvas (w,h, {format = "rgba16f"})
	Renderer.scene_buffer[2] = love.graphics.newCanvas (w,h, {format = "rgba16f"})
	Renderer.scene_avglum_buffer = love.graphics.newCanvas(Renderer.avglum_buffer_size, Renderer.avglum_buffer_size,
	                                                             {format = "r16f", mipmaps = "manual"})
	Renderer.scene_dt_exposure_buffer = love.graphics.newCanvas(1,1, {format = "rgba16f"})
	Renderer.scene_outline_viewport           = love.graphics.newCanvas(w,h, {format = "rgba16f"})
	Renderer.scene_depthbuffer                = love.graphics.newCanvas(w,h, {format = "depth24stencil8"})
	if Renderer.bloom_renderer then
		Renderer.bloom_renderer:reallocateMips(w,h)
	else
		Renderer.bloom_renderer = BloomRenderer:new(w,h)
	end

	if not Renderer.nil_cubemap then Renderer.nil_cubemap = love.graphics.newCanvas(1,1,{format="depth16",type="cube",readable=true})end

	Renderer.viewport_w = w
	Renderer.viewport_h = h
end

function Renderer.enableHDR()
	Renderer.enable_hdr = true end
function Renderer.disableHDR()
	Renderer.enable_hdr = false end
function Renderer.setHDRExposure(new_exposure)
	Renderer.hdr_exposure = new_exposure
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

function Renderer.renderScaled(canvas, hdr)
	local canvas = canvas or Renderer.scene_viewport
	local hdr = hdr or {}
	local exposure = hdr.exposure or Renderer.hdr_exposure
	local exposure_min   = hdr.exposure_min or Renderer.hdr_exposure_min
	local exposure_max   = hdr.exposure_max or Renderer.hdr_exposure_max
	local exposure_nudge = hdr.exposure_nudge or Renderer.hdr_exposure_nudge
	local gamma_value    = hdr.gamma or Renderer.gamma_value

	--love.graphics.setCanvas()
	--love.graphics.origin()
	--love.graphics.scale(RESOLUTION_RATIO)

	local w,h = get_resolution()
	local W,H = love.graphics.getWidth() / RESOLUTION_RATIO, love.graphics.getHeight() / RESOLUTION_RATIO
	local wpad, hpad = 0,0

	if RESOLUTION_PADW then
		wpad = (W-w)/2
	else
		hpad = (H-h)/2
	end

	--if hdr.hdr_enabled then
		love.graphics.setColor(1,1,1,1)
		Renderer.renderLuminance( Renderer.scene_viewport , Renderer.scene_avglum_buffer )
		Renderer.stepGradualExposure( love.timer.getDelta() , Renderer.hdr_exposure_adjust_speed )

		local bloom = Renderer.bloom_renderer:renderBloomTexture(Renderer.scene_viewport, 0.006)

		love.graphics.setShader(Renderer.hdr_shader)

		Renderer.hdr_shader:send("exposure_min", exposure_min)
		Renderer.hdr_shader:send("exposure_max", exposure_max)
		Renderer.hdr_shader:send("exposure_nudge", exposure_nudge)
		Renderer.hdr_shader:send("bloom_blur", bloom)
		Renderer.hdr_shader:send("gradual_luminance", Renderer.scene_dt_exposure_buffer)
		
		--love.graphics.setCanvas(Renderer.scene_postprocess_viewport)
		--love.graphics.origin()
		--love.graphics.draw(canvas)
		love.graphics.setCanvas()
		love.graphics.origin()
		love.graphics.scale(RESOLUTION_RATIO)
		love.graphics.draw(canvas,wpad,hpad)

		--love.graphics.origin()
		--love.graphics.setShader()
		--love.graphics.setCanvas()
		--love.graphics.scale(RESOLUTION_RATIO)
		--love.graphics.draw(Renderer.scene_postprocess_viewport,wpad,hpad)
	--else
	--	love.graphics.setShader()
	--	love.graphics.draw(canvas, wpad, hpad)
	--end

	Renderer.dropCanvas()
end

function Renderer.transformCoordsFor3D()
	local w,h = Renderer.viewport_w, Renderer.viewport_h
	love.graphics.origin()
	love.graphics.scale(w/2,h/2)
	love.graphics.translate(1,1)
end

function Renderer.blurCanvas(canvas, blur_amount)

	love.graphics.setShader(Renderer.blur_shader)
	love.graphics.origin()

	local horizontal = true
	local first_iteration = true

	local i1,i2 = 0,0

	for i=0,blur_amount*2-1 do

		i1 =   i%2 + 1
		i2 = (i+1)%2 + 1

		love.graphics.setCanvas( Renderer.scene_buffer[i1] )
		if first_iteration then
			love.graphics.draw( canvas )
		else
			love.graphics.draw( Renderer.scene_buffer[i2])
		end

		Renderer.blur_shader:send("horizontal_flag", horizontal)

		horizontal = not horizontal
		first_iteration = false
	end

	love.graphics.setCanvas()
	love.graphics.setShader()

	return Renderer.scene_buffer[i1]
end

function Renderer.enlargeOutline(outline, size)

	if size > 8 then
		size=8
	elseif size < 0 then
		size=0
	end

	love.graphics.setShader()
	love.graphics.setCanvas(Renderer.scene_buffer[1])
	love.graphics.clear(0,0,0,0)

	love.graphics.setShader(Renderer.outline_shader)
	love.graphics.origin()

	local kernel = {}

	for i = 0, (size*2+1)*(size*2+1)-1 do
		local x = i % (size*2+1)
		local y = math.floor(i / (size*2+1))

		local dx = math.abs(x - size)
		local dy = math.abs(y - size)

		if (dx+dy <= size) then
			kernel[i+1] = 1.0
		else
			kernel[i+1] = 0.0
		end
	end

	shadersend(Renderer.outline_shader, "kernel", unpack(kernel))
	shadersend(Renderer.outline_shader, "outline_size", size)

	love.graphics.setCanvas( Renderer.scene_buffer[1] )
	love.graphics.draw( outline )

	love.graphics.setCanvas()
	love.graphics.setShader()

	return Renderer.scene_buffer[1]
end

function Renderer.drawOutlineBuffer(canvas, outline, size)
	local outline_result = Renderer.enlargeOutline(outline, size)
	love.graphics.setShader()
	love.graphics.setCanvas{canvas,
		depthstencil = Renderer.scene_depthbuffer, stencil=true , depth=true}

	love.graphics.setStencilTest ("less", 1)
	love.graphics.setDepthMode("less", false)
	love.graphics.origin()
	love.graphics.setColor(1,1,1,1)

	love.graphics.draw(outline_result)
	love.graphics.setStencilTest ()
	love.graphics.setDepthMode("less", false)
end

function Renderer.sendLuminance(shader)
	local shader = shader or love.graphics.getShader()
	shadersend(shader, "luminance", Renderer.scene_avglum_buffer)
	shadersend(shader, "luminance_mipmap_count", Renderer.avglum_mipmap_count)
end

function Renderer.sendGradualLuminance(shader)
	local shader = shader or love.graphics.getShader()
	shadersend(shader, "gradual_luminance", Renderer.scene_dt_exposure_buffer)
	--shadersend(shader, "luminance_mipmap_count", Renderer.avglum_mipmap_count)
end

function Renderer.renderLuminance(canvas, avglum_buffer)
	local cw,ch = canvas:getDimensions()
	local lw,lh = avglum_buffer:getDimensions()

	love.graphics.setCanvas(avglum_buffer)
	love.graphics.setShader(Renderer.avglum_shader)
	love.graphics.origin()
	love.graphics.draw(canvas, 0,0,0, lw/cw, lh/ch)

	avglum_buffer:generateMipmaps()
	Renderer.avglum_mipmap_count = avglum_buffer:getMipmapCount()

	love.graphics.setCanvas()
	love.graphics.setShader()
end

function Renderer.stepGradualExposure( dt , speed )
	local shader = Renderer.dt_exposure_shader
	love.graphics.setCanvas(Renderer.scene_dt_exposure_buffer)
	love.graphics.setShader(shader)
	Renderer.sendLuminance(shader)
	shader:send("dt", dt * speed )

	love.graphics.origin()
	love.graphics.draw(Renderer.scene_avglum_buffer, 0,0,0, 1/Renderer.avglum_buffer_size)
end

function Renderer.resetLuminance(avglum_buffer)
	love.graphics.setCanvas(avglum_buffer)
	love.graphics.clear(1,1,1,1)
	love.graphics.setCanvas()
end

function Renderer.setupCanvasFor3D()
	if not Renderer.scene_viewport then
		Renderer.createCanvas()
	end

	--love.graphics.setCanvas{Renderer.scene_viewport, Renderer.scene_outline_viewport,
	--	depthstencil = Renderer.scene_depthbuffer,
	--	depth=true, stencil=true}
	love.graphics.setCanvas{Renderer.scene_viewport,
		depthstencil = Renderer.scene_depthbuffer,
		depth=true, stencil=false}
	love.graphics.setDepthMode( "less", true  )
	love.graphics.setMeshCullMode("front")

	love.graphics.setShader(Renderer.vertex_shader, Renderer.vertex_shader)
	return Renderer.vertex_shader
end

function Renderer.setupCanvasForContour()
	love.graphics.setCanvas{ Renderer.scene_viewport, depthstencil = Renderer.scene_depthbuffer,
		depth=true }
	love.graphics.setDepthMode( "less", true  )
	love.graphics.setMeshCullMode("back")

	love.graphics.setShader(Renderer.contour_shader)
end

function Renderer.setupCanvasForSkybox()
	love.graphics.setMeshCullMode("none")
	love.graphics.setDepthMode( "always", false )
	love.graphics.setCanvas(Renderer.scene_viewport)
	love.graphics.setShader(Renderer.skybox_shader)
end

function Renderer.setupCanvasForDirShadowMapping(light, map_type, keep_shader)
	if map_type == "static" then
		love.graphics.setCanvas{depthstencil = light.props.light_static_depthmap, depth=true}
	else
		love.graphics.setCanvas{depthstencil = light.props.light_depthmap, depth=true}
	end
	if not keep_shader then
		love.graphics.setDepthMode( "less", true )
		love.graphics.setMeshCullMode("front")
		love.graphics.setShader(Renderer.shadow_shader)
	end
end

function Renderer.setupCanvasForPointShadowMapping(light, side, keep_shader)
	love.graphics.setCanvas{depthstencil = {light:getCubeMap(), ["face"]=side}, depth=true}
	if not keep_shader then
		love.graphics.setDepthMode( "less", true )
		love.graphics.setMeshCullMode("front")
		love.graphics.setShader(Renderer.shadow_shader)
	end
end

function Renderer.dropCanvas()
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.setDepthMode()
	love.graphics.setMeshCullMode("front")
	love.graphics.origin()
end

function Renderer.clearCanvases()
	love.graphics.setShader()
	love.graphics.setCanvas()
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
	elseif (FPS < 460) then
		love.graphics.setColor(0,1,0,1)
	else
		love.graphics.setColor(0,1,1,1)
	end
	love.graphics.draw(Renderer.fps_draw_obj, sw-w-3,3)
	love.graphics.setColor(1,1,1,1)
	love.graphics.pop()
end

return Renderer
