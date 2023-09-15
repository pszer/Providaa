local matrix = require "matrix"
local cpml = require "cpml"

require "render"
require "map"
require "tick"
require "scene"
require "modelmanager"
require "input"
require "entity"
require "event"
require "inputhandler"
require "provhooks"
require "facedecor"
require "gameinterface"
require "partition"

local camcontrol = require "cameracontrollers"

local testmap = require "maps.test"

Prov = {
	grid = {},
	scene = Scene:new(),

	ents = {},
	events = {},

	ent_bins = nil,

	input_handlers = {},

	__dt = 0
}
Prov.__index = Prov

function Prov:load()
	self:addInputHandler("overworld",
		InputHandler:new(CONTROL_LOCK.GAME,
		{"move_left","move_right","move_up","move_down","action","back"}))

	self.scene:loadMap(testmap)
	self.scene.props.scene_lights = {
		Light:new{
			["light_pos"] = {0,0,0,0},
			["light_dir"] = {-0.8,1.7,-1.5},
			["light_col"] = {255/255, 235/255, 224/255, 10}
		}
	}
	self.scene.props.scene_skybox_hdr_brightness = 14

	pianko = Models.queryModel("pianko/pianko.iqm")
	piankoface = Models.queryModel("pianko/piankoface.iqm")
	sphere = Models.queryModel("Sphere.iqm")
	crate = Models.queryModel("shittycrate.iqm")

	crate_i = ModelInstance:newInstance(crate, {model_i_position = {300,-24,-240}, model_i_static = true})

	insts = {}

	table.insert(insts, ModelInfo.new({300,-60,-256},{0,0,0},1))
	table.insert(insts, ModelInfo.new({256,-300,-700},{0,1,1},1))
	table.insert(insts, ModelInfo.new({256,-48,-350},{0,0,0},2))

	crate_inst = ModelInstance:newInstances(crate,
		insts
	)

	instance = ModelInstance:newInstance(pianko)

	instance.props.model_i_outline_flag = true
	instance.props.model_i_contour_flag = true

	decor,animface = faceFromCfg("pianko_face")
	instance:attachDecoration(decor)

	pianko_ent = Entity:new{
		["ent_identifier"] = "player",
		["ent_model"] = instance,
		["ent_position"] = {200, -24, -200},
		["ent_states"] = {
			["state_walking"] =
			EntityStatePropPrototype{
				["state_commands"] = {
					["entity_walk_towards"] = function(ent, state, dir) print(unpack(dir)) end
				},

				["state_enter"] = function(ent) print("enter") end
			}
		},
		["ent_hooks_info"] = {
			{type="control", handler="overworld", keybind="move_up", event="press",
			 hook_func = function(ent)
			 	return function(ticktime, realtime)
					ent:callCommand("entity_walk_towards", { 0 , 0 , -1 })
				end
			 end},

			{type="control", handler="overworld", keybind="move_down", event="press",
			 hook_func = function(ent)
			 	return function(ticktime, realtime)
					ent:callCommand("entity_walk_towards", { 0 , 0 , 1 })
				end
			 end},

			{type="control", handler="overworld", keybind="move_left", event="press",
			 hook_func = function(ent)
			 	return function(ticktime, realtime)
					ent:callCommand("entity_walk_towards", { -1 , 0 , 0 })
				end
			 end},

			{type="control", handler="overworld", keybind="move_right", event="press",
			 hook_func = function(ent)
			 	return function(ticktime, realtime)
					ent:callCommand("entity_walk_towards", { 1 , 0 , 0 })
				end
			 end}
		}
	}

	pianko_ent:enableStateByName("state_walking")
	self:addEntity(pianko_ent)

	local cam = self.scene:getCamera()
	cam:setController(
		camcontrol:followEntityFixed(pianko_ent, {0,-5,90}, {0.5,0.55,0.5})
	)

	sphere = ModelInstance:newInstance(sphere, {model_i_position = {100,-200,-100}, model_i_static = true})
	self.scene:addModelInstance{ sphere, crate_i }

	self:fitNewEntityPartitionSpace()

	--local frame1,frame2,parents,interp = pianko:getAnimationFramesDataForThread("Walk",2.5)
	--animthread:addToQueue(instance, frame1, frame2, parents, interp)
	--animthread:process()
	--
	GameData:setupFromProv(self)

	-- only load once
	self.load = function() end
end

function Prov:update(dt)
	self.__dt = dt

	if tickChanged() then
		self:onTickChange()
	end

	local c = math.cos(getTick()*1/60)
	c = c*c*c*c*c
	local s = math.sin(getTick()*1.5/60)
	s = s*s*s*s*s
	animface.props.animface_righteye_dir = {3*c,3*s,12}
	animface.props.animface_lefteye_dir  = {3*c,3*s,12}

	--if scancodeIsDown("space", CTRL.GAME) then
	--	pianko_ent:delete()
	--end

	prof.push("pollinputhandlers")
	self:pollInputHandlers()
	prof.pop("pollinputhandlers")
	prof.push("update_ents")
	self:updateEnts()
	prof.pop("update_ents")

	prof.push("scene_update")
	self.scene:update()
	prof.pop("scene_update")

	if gfxSetting("multithread_animation") then
		self.scene.animthreads:startProcess()
		self.scene:pushModelAnimationsThreaded()
	else
		self.scene.animthreads:stopProcess()
		self.scene:updateModelAnimationsUnthreaded()
	end

	local pos = pianko_ent:getPosition()
	local rot = pianko_ent:getRotation()
	--pianko_ent:setPosition{pos[1], pos[2]+3*dt, pos[3]}	
	--pianko_ent:setPosition{pos[1], pos[2], pos[3]}	
	--pianko_ent:setRotation{rot[1], rot[2]+0.5*dt, rot[3], "rot"}
	--

	-- this will all need to be done by a FaceAnimator
	local poselist = {"neutral", "close_phase1", "close_phase2", "close_phase3", "close_phase3", "close_phase2", "close_phase1", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral",
	 "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral", "neutral"
	 }
	prof.push("push_composite")
	local pose = poselist[math.floor(love.timer.getTime()*20) % #poselist + 1]
	animface.props.animface_lefteye_pose = pose
	animface.props.animface_righteye_pose = pose
	prof.pop("push_composite")

	prof.push("update_ent_partition_space")
	self:updateEntityPartitionSpace()
	prof.pop("update_ent_partition_space")

	if gfxSetting("multithread_animation") then
		self.scene:finishModelAnimationsThreaded()
	end

	self:deleteFlaggedEntities()
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

function Prov:makeUniqueEntityIdentifier(name)
	local new_id_candidate = name
	local number_suffix = 2
	while true do
		local already_existing_ent = self.ents[new_id_candidate]
		if already_existing_ent then
			new_id_candidate = name .. tostring(number_suffix)
			number_suffix = number_suffix + 1
		else
			return new_id_candidate
		end
	end
end

function Prov:addEntity( ent )
	local id = self:makeUniqueEntityIdentifier( ent.props.ent_identifier )

	table.insert(self.ents, ent)
	self.ents[id] = ent

	local model_i = ent.props.ent_model
	self:establishEntityHooks( ent )
	self.scene:addModelInstance( model_i )
end

function Prov:removeEntity( ent )
	self.ent_bins:remove(ent)

	for i,v in ipairs(self.ents) do
		if v == ent then self:removeEntityAtIndex( i ) end
	end
end

function Prov:removeEntityAtIndex( index )
	local ent = self.ents[index]
	ent:clearHooks()

	local ent_id = ent.props.ent_identifier
	self.ents[ent_id] = nil

	local model_inst = self.ents[index].props.ent_model
	table.remove(self.ents, index)
	if model_inst then
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

function Prov:getEntities()
	return self.ents
end

function Prov:updateEnts()
	for i,ent in ipairs(self.ents) do
		ent:internalUpdate()
	end
end

function Prov:getInputHandler(id)
	return self.input_handlers[id]
end

function Prov:addInputHandler(id, input_handler)
	self.input_handlers[id] = input_handler
end

function Prov:removeInputHandler(id)
	self.input_handlers[id]:clearAllHooks()
	self.input_handlers[id] = nil
end

function Prov:pollInputHandlers()
	for i,handler in pairs(self.input_handlers) do
		handler:poll()
	end
end

function Prov:fitNewEntityPartitionSpace()
	local scene = self.scene
	local scenew, sceneh = scene.props.scene_width, scene.props.scene_height
	local w = (scenew+2) * TILE_SIZE
	local h = (sceneh+2) * TILE_SIZE
	local x = -TILE_SIZE
	local y = -(sceneh)*TILE_SIZE - TILE_SIZE

	self.ent_bins = GridPartition:new(x,y,w,h, 16, 16)
end

function Prov:updateEntityPartitionSpace()
	local ents = self:getEntities()
	local bins = self.ent_bins
	for _,ent in ipairs(ents) do
		if ent:areBoundsChanged() then
			bins:remove(ent)
			local pos, size = ent:getWorldHitboxPosSize()
			bins:insert(ent, pos[1], pos[3], size[1], size[3])
			ent:informNewBoundsAreHandled()
		end
	end
end

function Prov:establishEntityHooks(ent)
	local info_table = ent:getHooksInfo()
	local constructors = {
		["control"] = __provhooks_controlHook
	}

	for i,info in ipairs(info_table) do
		local hook_type = info.type
		local create_hook = constructors[hook_type]

		if not create_hook then
			error(string.format("Prov:establishEntityHooks(): unexpected hook requested, type=\"%s\"", tostring(hook_type)))
		end
		local hook = create_hook(self, ent, info)

		if hook then
			ent:addHook(hook)
		end
	end
end

-- see's what entities have their hitbox intersect with a given point
-- in 3D space
function Prov:queryEntitiesAtPoint( point_vec )
	local partition = self.ent_bins

	local ents, outside = partition:getInsideRectangle( point_vec[1] , point_vec[3], 0.1,0.1)

	for i=#ents,1,-1 do
		local ent = ents[i]
		local pos, size = ent:getWorldHitboxPosSize()

		local inside = testPointInBoundingBox(point_vec, pos, size)

		if not inside then
			table.remove(ents, i)
		end
	end

	for i,ent in ipairs(outside) do
		local pos, size = ent:getWorldHitboxPosSize()

		local inside = testPointInBoundingBox(point_vec, pos, size)

		if inside then
			table.insert(ents, ent)
		end
	end

	return ents
end

-- see's what entities have their hitbox intersect with a given rectangle
function Prov:queryEntitiesInRegion( rect_pos , rect_size )
	local partition = self.ent_bins 

	local ents, outside = partition:getInsideRectangle(rect_pos[1], rect_pos[3], rect_size[1], rect_size[3])

	for i=#ents,1,-1 do
		local ent = ents[i]
		local pos, size = ent:getWorldHitboxPosSize()

		local inside = testBoxInBoxPosSize(pos, size, rect_pos, rect_size)

		if not inside then
			table.remove(ents, i)
		end
	end

	for i,ent in ipairs(outside) do
		local pos, size = ent:getWorldHitboxPosSize()

		local inside = testBoxInBoxPosSize(pos, size, rect_pos, rect_size)

		if inside then
			table.insert(ents, ent)
		end
	end

	return ents
end
