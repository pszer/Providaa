require "assetloader"

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

}
MapMesh.__index = MapMesh
setmetatable(MapMesh, MapMesh)

function MapMesh:new(mesh, mesh_atts, tex, uvs, simple_mesh)

	assert(mesh and mesh_atts and tex and uvs)

	local this = {

		mesh = mesh,
		mesh_atts = mesh_atts,
		tex  = tex,
		uvs = uvs,

		simple_mesh = simple_mesh

	}

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
