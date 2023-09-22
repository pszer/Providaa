require "props/mapeditprops"
require "map"
require "camera"
require "render"

require "mapeditcommand"

ProvMapEdit = {

	props = nil,

	map_edit_shader = nil,

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

	self.props = MapEditPropPrototype()
end

function ProvMapEdit:resetCamera()
	self.props.mapedit_cam = Camera:new{
		["cam_bend_enabled"] = false,
		["cam_fov"] = 90.0
	}
end

function ProvMapEdit:update(dt)
	local map_mesh = self.props.mapedit_map_mesh
	if map_mesh then map_mesh:updateUvs() end
end

function ProvMapEdit:drawViewport()
	local map_mesh = self.props.mapedit_map_mesh
	local shader = self.map_edit_shader

	love.graphics.origin()
	love.graphics.setShader(shader)
	love.graphics.setCanvas(Renderer.scene_viewport)

	if map_mesh then
		map_mesh:pushAtlas()
		love.graphics.draw(map_mesh.mesh)
		shadersend(shader,"u_uses_tileatlas", false)
	end
end

function ProvMapEdit:draw()
	self:drawViewport()
	Renderer.renderScaledDefault()
end
