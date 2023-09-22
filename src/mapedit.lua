require "props/mapeditprops"
require "map"
require "camera"

require "mapeditcommand"

ProvMapEdit = {

	props = nil,

	mapedit_shader = nil,

}
ProvMapEdit.__index = ProvMapEdit

function ProvMapEdit:load(args)

	if not self.mapedit_shader then
		self.mapedit_shader = love.graphics.newShader("shader/mapedit.glsl") end
	
	local lvledit_arg = args["lvledit"]
	assert(lvledit_arg and lvledit_arg[1], "ProvMapEdit:load(): no level specified in lvl edit launch argument")
	local map_name = lvledit_arg[1]
	local dir = love.filesystem.getSource()
	local fullpath = dir .. Map.__dir .. map_name
	local map_file, err = pcall(function() return dofile(fullpath) end)

	if not map_file then
		error(string.format("ProvMapEdit:load(): [%s] %s", fullpath, tostring(err)))
	else
		print(string.format("ProvMapEdit:load(): loaded %s", fullpath))
	end

	props = MapEditPropPrototype()
end

function ProvMapEdit:resetCamera()
	self.props.mapedit_cam = Camera:new{
		["cam_bend_enabled"] = false,
		["cam_fov"] = 90.0
	}
end

function ProvMapEdit:update(dt)

end

function ProvMapEdit:drawViewport()
	love.graphics.origin()
	love.graphics.setShader(mapedit_shader)
	love.graphics.setCanvas(Render.scene_viewport)
end

function ProvMapEdit:draw()
	Renderer.renderScaledDefault()
end
