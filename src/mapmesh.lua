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

	decal_atts_atypes = {
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
		overlay_mesh = nil,
		overlay_atts = nil,
		tex  = nil,

		uvs = nil,
		uvs_buffer = {},
		textures = nil,
		texture_names = nil,

		animated_tex_info = nil or {},

		simple_mesh = nil,

		tile_vert_map = nil,
		wall_vert_map = nil,

		wall_exists = nil,

		decal_mesh = nil,
		decal_atlas = nil,
		decal_uvs = nil,

		verts = nil,
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

function MapMesh:setNewAtlasUvs(atlas, uvs)
	self.mesh:setTexture(atlas)
	self.tex = atlas
	self.uvs = uvs
	self.uvs_buffer = {}
	for i,v in ipairs(self.uvs) do
		self.uvs_buffer[i] = v
	end
end

function MapMesh:release(release_tex)
	if self.mesh then self.mesh:release() end
	if self.mesh_atts then self.mesh_atts:release() end
	if self.tex then self.tex:release() end
	if self.textures and release_tex then
		for i,v in ipairs(self.textures.names) do
			Loader:deref("texture", v)
		end
	end
end

-- returns texture atlas canvas and uvs
function MapMesh:generateTextureAtlas( imgs )
	local createTextureAtlas = require "texatlas"
	local size = CONSTS.ATLAS_SIZE
	local canv, uvs = createTextureAtlas( imgs , size,size )
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

function MapMesh:reloadAnimDefinitions(defs, texture_list)
	local anim_textures_info = self.animated_tex_info
	for i,v in pairs(defs) do
		anim_textures_info[i] = v

		local texs = v.textures

		local seq_length = #v.sequence
		local tex_count  = #v.textures
		anim_textures_info[i].seq_length = seq_length
		anim_textures_info[i].tex_count  = tex_count

		anim_textures_info[i].delay = v.delay or 8

		local seq = anim_textures_info[i].sequence
		for j,u in ipairs(seq) do
			if u > tex_count then
				print(string.format("Map.generateMapMesh(): animated texture for tile type %s has a malformed sequence, correcting.", tostring(i)))
				seq[j] = tex_count
			elseif u < 1 then
				print(string.format("Map.generateMapMesh(): animated texture for tile type %s has a malformed sequence, correcting.", tostring(i)))
				seq[j] = 1
			end
		end

		anim_textures_info[i].indices = {}
		for j,tex_name in ipairs(texs) do
			local index = texture_list[tex_name] or 1
			anim_textures_info[i].indices[j] = index
		end
	end
end

function MapMesh:pushAtlas(shader, push_img)
	shadersend(shader,"u_uses_tileatlas", true)
	if push_img then
		shadersend(shader,"u_tileatlas_uv", unpack(self.uvs_buffer))
	end
end

function MapMesh:pushDecalAtlas(shader, push_img)
	shadersend(shader, "u_uses_tileatlas", true)
	if push_img then
		shadersend(shader,"u_tileatlas_uv", unpack(self.decal_uvs))
	end
end

function MapMesh:attachAttributes()
	self.mesh:detachAttribute("TextureScale")
	self.mesh:detachAttribute("TextureOffset")
	self.mesh:detachAttribute("TextureUvIndex")
	self.mesh:attachAttribute("TextureScale",self.mesh_atts)
	self.mesh:attachAttribute("TextureOffset",self.mesh_atts)
	self.mesh:attachAttribute("TextureUvIndex",self.mesh_atts)
end
function MapMesh:attachOverlayAttributes()
	self.mesh:detachAttribute("TextureScale")
	self.mesh:detachAttribute("TextureOffset")
	self.mesh:detachAttribute("TextureUvIndex")
	self.mesh:attachAttribute("TextureScale",self.overlay_atts)
	self.mesh:attachAttribute("TextureOffset",self.overlay_atts)
	self.mesh:attachAttribute("TextureUvIndex",self.overlay_atts)
end
