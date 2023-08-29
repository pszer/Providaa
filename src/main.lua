require "gamestate"
require "render"
require "console"

local profiler = require "profiler"

function love.load()
	love.graphics.setDefaultFilter( "nearest", "nearest" )
	Renderer.loadShaders()
	Renderer.createCanvas()
	Renderer.setupSkyboxModel()

	Textures.loadTextures()
	Textures.generateMissingTexture()
	--profiler.start()
	SET_GAMESTATE(PROV)
end

counter=0
frames=0
function love.update(dt)
	GAMESTATE:update(dt)

	counter = counter + dt
	frames=frames+1
	if (counter > 1.0) then
		FPS = frames
		frames=0
		counter = 0
	end

	if love.keyboard.isDown("p") then
		drawgame = not drawgame
	end

	if love.keyboard.isDown("o") then
		drawanim = not drawanim
	end
end

local cpml = require "cpml"

drawanim = false
drawgame = true

function love.draw()
	
	local w,h = Renderer.viewport_w, Renderer.viewport_h
	love.graphics.origin()
	love.graphics.scale(7,7)
	love.graphics.translate(w/14,h/14)


	--[[
	local matrices = alekin:calculateBoneMatrices(alekin.props.model_animations["Walk"], getTick(), 0.0)

	local mesh = alekin.props.model_mesh.mesh
	local lasttotal_position = {0,0,0,0}
	for i=1,mesh:getVertexCount() do
		local x,y,z = mesh:getVertexAttribute(i,1)

		local pos = {x,y,z,1.0}
		local b,w = {},{}

		b[1],b[2],b[3],b[4] = mesh:getVertexAttribute(i,5)
		w[1],w[2],w[3],w[4] = mesh:getVertexAttribute(i,6)
		--print(w[1],w[2],w[3],b[4])	
		--print()
		--print(b[1]*255,b[2]*255,b[3]*255,b[4]*255)	
		--print(b[1]*255,b[2]*255,b[3]*255,b[4]*255)	

		--love.graphics.points(x,-z)
		--love.graphics.points(250*x/(y+250),-250*z/(y+250))
		--love.graphics.points(x/(y*10),-z/(y*10))
		--love.graphics.points(10*y/(z+10),-10*x/(z+10))
		
		local bones = {}
		local weights = {}

		bones[1] = matrices[math.floor(b[1]*255.0)];
		bones[2] = matrices[math.floor(b[2]*255.0)];
		bones[3] = matrices[math.floor(b[3]*255.0)];
		bones[4] = matrices[math.floor(b[4]*255.0)];
		
		local total_position = {0,0,0,0}

		for i = 1,4 do
			local local_position = {pos[1],pos[2],pos[3],pos[4]}
			local_position = cpml.mat4.mul_vec4(local_position, bones[i], local_position)

			total_position[1] = total_position[1] + local_position[1] * w[i]
			total_position[2] = total_position[2] + local_position[2] * w[i]
			total_position[3] = total_position[3] + local_position[3] * w[i]
			total_position[4] = total_position[4] + local_position[4] * w[i]
		end

		--print(unpack(total_position))
		--love.graphics.line(total_position[1], total_position[3], lasttotal_position[1], lasttotal_position[3])
		love.graphics.points(total_position[1], total_position[3])

		lasttotal_position = total_position
	end


	local skeleton = alekin.props.model_skeleton

	for i,v in ipairs(skeleton) do
		local point = {0,0,0,1}
		local offset = v.offset

		cpml.mat4.mul_vec4(point, offset, point)

		--love.graphics.line(0,0,point[1],-point[3])
	end--]]

	if drawgame then
		GAMESTATE:draw()
	end

	if Console.isOpen() then Console.draw() end
	Renderer.drawFPS()
end

function love.resize( w,h )
	update_resolution_ratio( w,h )
	Renderer.createCanvas()
end

function love.quit()
	--profiler.stop()
end

function love.keypressed(key)
	if Console.isOpen() then
		Console.keypressed(key)
	end

	if key == "f8" then
		Console.open()
	end
end

function love.textinput(t)
	if Console.isOpen() then
		Console.textinput(t)
	end
end
