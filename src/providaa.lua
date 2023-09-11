local matrix = require "matrix"
local cpml = require "cpml"

require "render"
require "map"
require "tick"
require "scene"
require "modelmanager"
require "animatedface"
require "input"
require "entity"
require "event"

local camcontrol = require "cameracontrollers"

local testmap = require "maps.test"

Prov = {
	grid = {},
	scene = Scene:new(),

	ents = {},
	events = {}
}
Prov.__index = Prov

function Prov:load()
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

	local pianko_ent = Entity:new{
		["ent_model"] = instance,
		["ent_position"] = {200, -100, -200},
		["ent_states"] = {
			EntityStatePropPrototype{
				["state_commands"] = {"command_walk"}
			}
		}
	}

	self:addEntity(pianko_ent)

	print("pianko", provtype(pianko_ent))

	local cam = self.scene:getCamera()
	cam:setController(
		camcontrol:followEntityFixed(pianko_ent, {0,-50,80}, {0,0,0})
	)

	sphere = ModelInstance:newInstance(sphere, {model_i_position = {100,-200,-100}, model_i_static = true})
	self.scene:addModelInstance{ sphere, crate_i , crate_inst }

	-- only load once
	self.load = function() end
end

function Prov:update(dt)
	stepTick(dt)
	if tickChanged() then
		self:onTickChange()
	end

	local cam = Prov.scene.props.scene_camera

	--[[if keybindIsDown("w", CTRL.GAME) then
		cam.cam_z = cam.cam_z - 100*dt
	end
	if keybindIsDown("s", CTRL.GAME) then
		cam.cam_z = cam.cam_z + 100*dt
	end
	if keybindIsDown("a", CTRL.GAME) then
		cam.cam_x = cam.cam_x - 100*dt
	end
	if keybindIsDown("d", CTRL.GAME) then
		cam.cam_x = cam.cam_x + 100*dt
	end
	if keybindIsDown("space", CTRL.GAME) then
		cam.cam_y = cam.cam_y - 50*dt
	end
	if keybindIsDown("lctrl", CTRL.GAME) then
		cam.cam_y = cam.cam_y + 50*dt
	end

	if keybindIsDown("right", CTRL.GAME) then
		cam.cam_yaw = cam.cam_yaw + 1*dt
	end

	if keybindIsDown("left", CTRL.GAME) then
		cam.cam_yaw = cam.cam_yaw - 1*dt
	end

	if keybindIsDown("down", CTRL.GAME) then
		cam.cam_pitch = cam.cam_pitch - 1*dt
	end

	if keybindIsDown("up", CTRL.GAME) then
		cam.cam_pitch = cam.cam_pitch + 1*dt
	end]]

	self:updateEnts()

	local cam_p = cam:getPosition()
	local cam_r = cam:getRotation()

	cam:directionMode()

	--instance:setPosition{cam_p[1]+80*math.sin(cam_r[2]),cam_p[2]+60,cam_p[3]-75*math.cos(cam_r[2])}
	
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

function Prov:draw()
	prof.push("scene_draw")
	self.scene:draw()
	prof.pop("scene_draw")

	prof.push("hdr_postprocess")
	Renderer.renderScaled(nil, {hdr_enabled=true})
	prof.pop("hdr_postprocess")
end

function Prov:onTickChange()
	local meshes = self.scene.props.scene_meshes
	for _,mesh in ipairs(meshes) do
		mesh:updateTexture()
	end
end

function Prov:addEntity( ent )
	table.insert(self.ents, ent)
	local model_i = ent.props.ent_model
	self.scene:addModelInstance(model_i)
end

function Prov:removeEntity( ent )
	for i,v in ipairs(self.ents) do
		if v == ent then self:removeEntityAtIndex( i ) end
	end
end

function Prov:removeEntityAtIndex( index )
	local model_inst = self.ents[i].props.ent_model
	table.remove(self.ents, index)
	if model_i then
		self.scene:removeModelInstance(model_inst)
	end
end

-- deletes any entities with an ent_delete_flag
function Prov:deleteFlaggedEntities()
	-- traverse backwards so that the index is always
	-- correct even after removing an entity
	for i=#self.ents,1,-1 do
		local ent = self.ents[i]
		if ent:toBeDeleted() then
			self:removeEntityAtIndex(i)
		end
	end
end

function Prov:updateEnts()
	for i,ent in ipairs(self.ents) do
		ent:update()
	end
end
