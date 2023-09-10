local matrix = require "matrix"
local cpml = require "cpml"

require "render"
require "map"
require "tick"
require "scene"
require "modelmanager"
require "animatedface"

local testmap = require "maps.test"

PROV = {
	grid = {},
	scene = Scene:new(),
}
PROV.__index = PROV

function PROV:load()
	self.scene:loadMap(testmap)
	self.scene.props.scene_lights = {
		Light:new{
			["light_pos"] = {0,0,0,0},
			--["light_dir"] = {0.5,1.0,-0.5},
			["light_dir"] = {-1.0,1.5,-1.0},
			["light_col"] = {255/255, 235/255, 224/255, 10}
		}
	}
	self.scene.props.scene_skybox_hdr_brightness = 14

	pianko = Models.queryModel("pianko.iqm")
	piankoface = Models.queryModel("piankoface.iqm")
	sphere = Models.queryModel("Sphere.iqm")
	crate = Models.queryModel("shittycrate.iqm")

	instance = ModelInstance:newInstance(pianko)

	instance.props.model_i_outline_flag = true
	instance.props.model_i_contour_flag = true

	crate_i = ModelInstance:newInstance(crate, {model_i_position = {300,-24,-240}, model_i_static = true})

	insts = {}

	--for i=1,1000 do
	--	table.insert(insts, ModelInfo.new({0,-i,-i*6},{0,0,0},1))
	--end

	table.insert(insts, ModelInfo.new({300,-60,-256},{0,0,0},1))
	table.insert(insts, ModelInfo.new({256,-300,-700},{0,1,1},1))
	table.insert(insts, ModelInfo.new({256,-48,-350},{0,0,0},2))

	crate_inst = ModelInstance:newInstances(crate,
		insts
	)

	face_decor = ModelDecor:new{
		decor_name = "face",
		decor_reference = piankoface,
		decor_parent_bone = "Head",
		decor_position = {0,0,0.015},
	}
	instance:attachDecoration(face_decor)

	testeyes = EyesData:openFilename("models/pianko/eyes.png",
	 {
	  eyes_dimensions = {32,32},
	  eyes_radius = 12,
	  eyes_poses = {
	   {name="neutral"},
	   {name="close_phase1"},
	   {name="close_phase2"},
	   {name="close_phase3"}
	  }
	 }
	 )

	 animface = AnimFace:new{
		animface_decor_reference = face_decor,
		animface_eyesdata = testeyes,
		animface_texture_dim = {256,256},
		animface_righteye_position = {46,49},
		animface_lefteye_position  = {178,49},
		animface_righteye_pose     = "neutral",
		animface_lefteye_pose      = "neutral",
		animface_righteye_dir      = {0,0,1},
		animface_lefteye_dir       = {0,0,1}
	 }

	sphere = ModelInstance:newInstance(sphere, {model_i_position = {100,-200,-100}, model_i_static = true})
	self.scene:addModelInstance{ sphere, instance, crate_i , crate_inst , instance2, instance3, instance4, instance5, instance6, instance7 ,
	instance8, instance9, instance10, instance11, instance12, instance13 }

	-- only load once
	self.load = function() end
end

function PROV:update(dt)
	stepTick(dt)
	if tickChanged() then
		self:onTickChange()
	end

	local cam = PROV.scene.props.scene_camera.props
	if love.keyboard.isDown("w") then
		cam.cam_z = cam.cam_z - 100*dt
	end
	if love.keyboard.isDown("s") then
		cam.cam_z = cam.cam_z + 100*dt
	end
	if love.keyboard.isDown("a") then
		cam.cam_x = cam.cam_x - 100*dt
	end
	if love.keyboard.isDown("d") then
		cam.cam_x = cam.cam_x + 100*dt
	end
	if love.keyboard.isDown("space") then
		cam.cam_y = cam.cam_y - 50*dt
	end
	if love.keyboard.isDown("lctrl") then
		cam.cam_y = cam.cam_y + 50*dt
	end

	if love.keyboard.isDown("right") then
		cam.cam_yaw = cam.cam_yaw + 1*dt
		--cam.cam_roll = cam.cam_roll - 1*dt
	end

	if love.keyboard.isDown("left") then
		cam.cam_yaw = cam.cam_yaw - 1*dt
		--cam.cam_roll = cam.cam_roll + 1*dt
	end

	if love.keyboard.isDown("down") then
		cam.cam_pitch = cam.cam_pitch - 1*dt
	end

	if love.keyboard.isDown("up") then
		cam.cam_pitch = cam.cam_pitch + 1*dt
	end

	instance:setPosition{cam.cam_x+80*math.sin(cam.cam_yaw),cam.cam_y+60,cam.cam_z-75*math.cos(cam.cam_yaw)}
	
	local poselist = {"neutral", "close_phase1", "close_phase2", "close_phase3", "close_phase3", "close_phase2", "close_phase1", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral"
	 }
	local pose = poselist[math.floor(love.timer.getTime()*20) % #poselist + 1]
	animface.props.animface_lefteye_pose = pose
	animface.props.animface_righteye_pose = pose
	animface:pushComposite()
end

function PROV:draw()
	prof.push("scene_draw")
	self.scene:draw()
	prof.pop("scene_draw")

	prof.push("hdr_postprocess")
	Renderer.renderScaled(nil, {hdr_enabled=true})
	prof.pop("hdr_postprocess")
end

function PROV:onTickChange()
	local meshes = self.scene.props.scene_meshes
	for _,mesh in ipairs(meshes) do
		mesh:updateTexture()
	end
end
