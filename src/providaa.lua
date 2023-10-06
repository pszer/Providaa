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
require "assetloader"

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
	SET_ACTIVE_KEYBINDS(GAME_KEY_SETTINGS)
	self:addInputHandler("overworld",
		InputHandler:new(CONTROL_LOCK.GAME,
		{"move_left","move_right","move_up","move_down","action","back"}))
	CONTROL_LOCK.GAME.open()

	self.scene:loadMap(testmap)

	self.scene.props.scene_lights = {
		Light:new{
			["light_pos"] = {0,0,0,0},
			["light_dir"] = {-0.8,2.7,-1.5},
			["light_col"] = {277.95/255, 277.95/255, 242/255, 14.0},
			["light_static"] = true
		},

		
		Light:new{
			["light_pos"] = {250,-90,1500,1},
			["light_col"] = {277.95/255, 255/255, 224/255,1000},
			["light_size"] = 1000,
			["light_static"] = true
		},

		--[[Light:new{
			["light_pos"] = {800,-130,-250+2048,1},
			["light_col"] = {277.95/255,255/255,224/255,1000},		
			["light_size"] = 250,
			["light_static"] = true
		},

		Light:new{
			["light_pos"] = {1200,-120,-200+2048,1},
			["light_col"] = {500/255,235/255,224/255,1000},
			["light_size"] = 250,
			["light_static"] = true
		},

		--[[Light:new{
			["light_pos"] = {2400,-30,-280,1},
			["light_col"] = {255/255,235/255,224/255,10},
			["light_size"] = 500,
			["light_static"] = true
		},

		Light:new{
			["light_pos"] = {300,-80,-680,1},
			["light_col"] = {255/255,235/255,224/255,10},
			["light_size"] = 500,
			["light_static"] = true
		},

		Light:new{
			["light_pos"] = {600,-80,-680,1},
			["light_col"] = {255/255,235/255,224/255,10},
			["light_size"] = 500,
			["light_static"] = true
		},

		Light:new{
			["light_pos"] = {1000,-80,-680,1},
			["light_col"] = {255/255,235/255,224/255,10},
			["light_size"] = 500,
			["light_static"] = true
		},--]]
	}
	self.scene.props.scene_skybox_hdr_brightness = 20.0

	self:fitNewEntityPartitionSpace()
	GameData:setupFromProv(self)

	local playerproto  = require "ent.player"
	theent = self:addEntityFromPrototype(playerproto, {ent_rotation = {0.0,0.0,1.0,"dir"}, ent_position = {300,-16,1500}})
	theent:enableStateByName("state_walking")

	local cam = self.scene:getCamera()
	cam:setController(
		camcontrol:followEntityFixed(theent, {0,-15,95}, {0.5,0.55,0.5}))

	-- only load once
	self.load = function() end
end

function Prov:update(dt)
	self.__dt = dt

	if tickChanged() then
		self:onTickChange()
	end

	if scancodeIsDown("p", CTRL.GAME) then
		self.scene:__removeAllModels()
		Models.releaseModelsOutsideSet({})

		Loader:cleanupAssets()
	end

	prof.push("pollinputhandlers")
	self:pollInputHandlers()
	prof.pop("pollinputhandlers")

	prof.push("update_ents")
	self:updateEnts(dt)
	prof.pop("update_ents")

	self.scene:updateModelMatrices()

	--if gfxSetting("multithread_animation") then
	--	self.scene.animthreads:startProcess()
	--	self.scene:pushModelAnimationsThreaded()
	--else
	--	self.scene.animthreads:stopProcess()
		self.scene:updateModelAnimationsUnthreaded()
	--end

	prof.push("update_ent_partition_space")
	self:updateEntityPartitionSpace()
	prof.pop("update_ent_partition_space")

	--if gfxSetting("multithread_animation") then
	--	self.scene:finishModelAnimationsThreaded()
	--end

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

function Prov:updateEnts(dt)
	for i,ent in ipairs(self.ents) do
		ent:internalUpdate(dt)
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

function Prov:createEntityFromPrototype(prototype, props)
	local ent = prototype(props)

	local model_name = ent.ent_model_name
	local ent_states = ent.ent_states
	local ent_states = ent.ent_states

	local ent_hitboxsize = ent.ent_hitbox_size

	if model_name then
		local model_i = nil
		if type(model_name == "string") then
			model_i = CustomModel:fromCfg(model_name)
		else
			model_i = CustomModel:load(model_name)
		end
		
		if model_i then
			ent.ent_model = model_i
		end
	end

	if ent_states then
		for i,v in pairs(ent_states) do
			ent_states[i] = Entity:stateFromPrototype(GameData, v)
		end
	end

	return Entity:newFromPrototype(prototype, ent)
end

function Prov:addEntityFromPrototype(prototype, props)
	local ent = self:createEntityFromPrototype(prototype, props)
	self:addEntity(ent)
	return ent
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
