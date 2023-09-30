require "assetloader"
require "tick"
require "math"

local shadersend = require "shadersend"

MapMesh = {__type="mapmesh",

	atypes = {
	  {"VertexPosition", "float", 3},
	  {"VertexTexCoord", "float", 2},
	  {"VertexNormal"  , "float", 3},
	},

	atts_atypes = {
		{"TextureScale",    "float", 2},
		{"TextureOffset",   "float", 2},
		{"TextureUvIndex",  "float", 1}
	},

	simple_atypes = {
	  {"VertexPosition", "float", 3}
	},

	update_uv_timer = periodicUpdate(1)

}
MapMesh.__index = MapMesh

--function MapMesh:new(mesh, mesh_atts, tex, uvs, simple_mesh, anim_tex_info, tile_vert_m, wall_vert_m, wall_exists)
function MapMesh:new(args)

	assert(args.mesh and args.mesh_atts and args.tex and args.uvs)

	local this = {

		mesh = nil,
		mesh_atts = nil,
		tex  = nil,

		uvs = nil,
		uvs_buffer = {},
		textures = nil,
		texture_names = nil,

		animated_tex_info = nil or {},

		simple_mesh = nil,

		tile_vert_map = nil,
		wall_vert_map = nil,

		wall_exists = nil

	}

	for i,v in pairs(args) do
		this[i]=v
	end

	for i,v in ipairs(this.uvs) do
		this.uvs_buffer[i] = v
	end

	setmetatable(this, MapMesh)
	return this

end

function MapMesh:release()
	if self.mesh then self.mesh:release() end
	if self.mesh_atts then self.mesh_atts:release() end
	if self.tex then self.tex:release() end
	if self.textures then
		for i,v in ipairs(self.textures.names) do
			Loader:deref("texture", v)
		end
	end
end

-- returns texture atlas canvas and uvs
function MapMesh:generateTextureAtlas( imgs )
	local createTextureAtlas = require "texatlas"
	local canv, uvs = createTextureAtlas( imgs , 1024,1024 )
	assert(canv)
	return canv, uvs
end

-- updates this map meshes UV's (swaps UV's around to animate textures)
-- returns true if UV's are updated this frame
-- returns false if UV's aren't updated this frame
function MapMesh:updateUvs()
	if not MapMesh.update_uv_timer() then return false end

	local time = getTick()
	local int  = math.floor
	for i,info in pairs(self.animated_tex_info) do
		local delay   = info.delay
		local seq     = info.sequence
		local indices = info.indices

		local offset  = int( time / delay ) % (info.seq_length or #seq) + 1

		local index_to_write_to = indices[1]
		local new_index = indices[ seq[offset] ]

		self.uvs_buffer[index_to_write_to] = self.uvs[new_index]
	end

	return true
end

function MapMesh:pushAtlas(shader, push_img)
	shadersend(shader,"u_uses_tileatlas", true)
	if push_img then
		shadersend(shader,"u_tileatlas_uv", unpack(self.uvs_buffer))
	end
end
