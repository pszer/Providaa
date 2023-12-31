require "assetloader"

local tex_attributes = require 'cfg.texture_attributes'

local Material = {
	__type="material",
}
Material.__index = Material

local function def_pixel_canvas(col,format,filter,wrap,w,h)
	local col = col or {0,0,0,0}
	local format = format or "rgba8"
	local w = w or 2
	local h = h or 2
	local filter = filter or "nearest"
	local canv = love.graphics.newCanvas(w,h,{format=format})
	canv:setFilter(filter)
	love.graphics.setCanvas(canv)
	if not love.graphics.isGammaCorrect() then
		love.graphics.clear(col)
	else
		local r,g,b = love.math.linearToGamma(col)
		love.graphics.clear(r,g,b,1.0)
	end
	love.graphics.setCanvas()
	return canv
end

local material_defs = {

	["normal"] = {
		shaderUniform = "MatNormal",
		extension     = "normal",
		filter        = "nearest",
		default       = def_pixel_canvas({0.5,0.5,1.0,1.0},"rgba8","nearest","clamp",2,2),
		parameters    = {
		}
	},

	["emission"] = {
		shaderUniform = "MatEmission",
		extension     = "emit",
		filter        = "nearest",
		default       = def_pixel_canvas({0.0,0.0,0.0,0.0},"rgba8","nearest","clamp",2,2),
		parameters    = {
			["MatEmissionStrength"] = 1.0,
		}
	},

}
local material_def_names = {}
for i,v in pairs(material_defs) do
	table.insert(material_def_names, i)
end

local material_undef = {__texfnames={}}
setmetatable(material_undef, Material)
function Material:empty()
	return material_undef
end

function Material:new(fname)
	local this = {
		__texfnames = {}
	}

	local function clone_uniform(t)
		local t_type = type(t)
		if t_type ~= "table" then
			return t
		end
		local ct = {}
		for i,v in ipairs(t) do
			ct[i]=v
		end
	end
	local function chop_off_ext(path)
		local str = string.match(path, "(.*)%.[^/]+$")
		local ext = string.match(path, ".*(%.[^/]+)$")
		if str then return str,ext
		       else return path,"" end
	end
	local base_fname,base_ext = chop_off_ext(fname)

	for i,mat_name in ipairs(material_def_names) do
		local def = material_defs[mat_name]
		local mat_ext = def.extension
		assert(mat_ext)
		local mat_fname = base_fname .. "@" .. mat_ext .. base_ext
		Loader:openTexture(mat_fname)
		local tex = Loader:queryTexture(mat_fname)
		if tex then
			tex:setFilter(def.filter or "nearest")

			this.mat_name = {tex,{}}
			local params = this.mat_name[2]
			local attrs = tex_attributes[mat_fname]
			for i,v in pairs(def.parameters) do
				if attrs and attrs[i] then
					params[i] = clone_uniform(attrs[i])
				else
					params[i] = clone_uniform(v)
				end
			end
			table.insert(this.__texfnames,mat_fname)
		end
	end

	setmetatable(this, Material)
	return this
end

function Material:release()
	for i,v in ipairs(self.__texfnames) do
		Loader:deref("texture",v)
	end
end

function Material:send(shader, limit_to)
	local shadersend = require 'shadersend'

	for i,mat_name in ipairs(material_def_names) do
		local mat_def = material_defs[mat_name]
		local mat = self.mat_name

		local u_shader_tex_name = mat_def.shaderUniform

		if mat then
			local texture = mat[1]
			local params  = mat[2]

			shadersend(shader, u_shader_tex_name, texture)
			for uniform,value in pairs(params) do
				shadersend(shader, uniform, value)
			end
		else
			local default_texture = mat_def.default
			shadersend(shader, u_shader_tex_name, default_texture)
			for uniform,value in pairs(mat_def.parameters) do
				shadersend(shader, uniform, value)
			end
		end
	end
end

return Material
