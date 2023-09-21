require "assetloader"
require "tick"
require "math"

MapMesh = {__type="mapmesh",

	atypes = {
	  {"VertexPosition", "float", 3},
	  {"VertexTexCoord", "float", 2},
	  {"VertexNormal"  , "float", 3},
	},

	atts_atypes = {
		--{"AnimationOffset", "float", 1},
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
setmetatable(MapMesh, MapMesh)

function MapMesh:new(mesh, mesh_atts, tex, uvs, simple_mesh, anim_tex_info)

	assert(mesh and mesh_atts and tex and uvs)

	local this = {

		mesh = mesh,
		mesh_atts = mesh_atts,
		tex  = tex,

		update_uvs_flag = true,
		uvs = uvs,

		uvs_buffer = {},

		animated_tex_info = anim_tex_info or {},

		simple_mesh = simple_mesh

	}

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
end

-- returns texture atlas canvas and uvs
function MapMesh:generateTextureAtlas( imgs )
	local createTextureAtlas = require "texatlas"
	local canv, uvs = createTextureAtlas( imgs , 512,512 )
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
