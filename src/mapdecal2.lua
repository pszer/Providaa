local MapDecal = {

}
MapDecal.__index = MapDecal

require "angle"
local cpml = require "cpml"

-- texture = love2d texture file
-- texture_name = texture filename
-- base = {"tile",tile_obj} or {"wall",wall_obj}
-- pos = {x,y}, with x in [0,1] and y in [0,1] (or {-inf,inf} in case of a wall base)
-- size = {Cx,Cy}, in TILE_SIZE units
-- rot  = angle in radians, rotation around middle
function MapDecal:new( texture,texture_name, pos,size,quat )
	local this = {
		texture=texture,
		texture_name=texture_name,
		root = base,

		pos = pos,
		size = size,
		quat = quat,

		verts = {}, -- tableof {x,y,z, u,v, Nx,Ny,Nz,}
		mesh  = nil,
	}

	setmetatable(this, MapDecal)
	return this
end

function MapDecal:generateVerts(mesh, grid_w, grid_h, vert_index_map, wall_index_map, regen_verts, get_heights, get_shape)
	self:generateTileVerts(mesh, grid_w, grid_h, vert_index_map)	
end

function MapDecal:generateMesh()
	if not self.mesh then
		local verts = self.verts
		if #verts == 0 then
			verts = {
				{0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0},
			}
		end
		local m = love.graphics.newMesh(MapMesh.atypes, verts, "triangles", "dynamic")
		--m:setVertexMap(self.index)
		m:setTexture(texture)
		self.mesh=m
	end
end

local clipTri = require "cliptriangle"

local ISQRT2 = (2^0.5)/2
local SQRT2 = (2^0.5)
local decal_mat = cpml.mat4.new()
local decal_mat_inv = cpml.mat4.new()
local __mat4ID = cpml.mat4.new()
local __NDCproj = cpml.mat4.from_ortho(-1.0,1.0,-1.0,1.0,-1.0,1.0)
local __tempvec3 = cpml.vec3.new()
function MapDecal:generateTileVerts(mesh, grid_w, grid_h, vert_index_map, regen_verts, get_heights, get_shape)
	local pos = self.pos
	local size = self.size
	local rot = self.quat

	local vec = __tempvec3
	for i=1,16 do
		decal_mat[i] = __mat4ID[i]
	end

	vec.x,vec.y,vec.z = pos[1],pos[2],pos[3]
	decal_mat:translate(decal_mat,vec)
	local rot_m = cpml.mat4.from_quaternion(rot)
	decal_mat:mul(rot_m, decal_mat)
	vec.x,vec.y,vec.z = size[1],size[2],size[3]
	decal_mat:scale(decal_mat, vec)

	local decal_mat_inv = decal_mat_inv
	decal_mat_inv:invert(decal_mat)

	local minX,maxX=nil,nil
	local minZ,maxZ=nil,nil

	local floor,ceil=math.floor,math.ceil
	local min,max=math.min,math.max
	minX = max(1     , floor((pos[1] - size[1]*SQRT2/2)/TILE_SIZE))
	maxX = min(grid_w, ceil ((pos[1] + size[1]*SQRT2/2)/TILE_SIZE))
	minZ = max(1     , floor((pos[3] - size[3]*SQRT2/2)/TILE_SIZE))
	maxZ = min(grid_h, ceil ((pos[3] + size[3]*SQRT2/2)/TILE_SIZE))

	-- x,y,z, _,_, nx,ny,nz
	__CLIP_TRIANGLE_VERT_ATTS=8
	local mulv4 = cpml.mat4.mul_vec4

	local verts={}
	local vert_count=0
	local function add_vert(v)
		vert_count=vert_count+1
		verts[vert_count]=v
	end
	local function add_tri(t)
		for i,v in ipairs(t) do
			local u,v = v[1],v[2]
			u = (u+1.0)*0.5
			v = (v+1.0)*0.5

			local V = {v[1],v[2],v[3],1.0}
			mulv4(V, decal_mat, V)
			for j=6,__CLIP_TRIANGLE_VERT_ATTS do
				V[j] = v[j]
			end
			V[4]=u
			V[5]=v
			add_vert(V)
		end
	end

	print(minZ,maxZ)
	print(minX,maxX)
	for z=minZ,maxZ do
		for x=minX,maxX do
		--	print(x,z)
			local index_start   = vert_index_map[z][x].first
			local indices = vert_index_map[z][x].indices

			local iz=index_start-1
			local tri1 = {mesh[iz+indices[1]],mesh[iz+indices[2]],mesh[iz+indices[3]]}
			local tri2 = {mesh[iz+indices[4]],mesh[iz+indices[5]],mesh[iz+indices[6]]}

			print(x,z)
			for i=1,3 do
				print(" ",i)
				local v,u = {}, {}
				local V,U = {tri1[i][1],tri1[i][2],tri1[i][3],1.0},{tri2[i][1],tri2[i][2],tri2[i][3],1.0}
				mulv4(v, decal_mat_inv, V)
				mulv4(u, decal_mat_inv, U)

				print("v", v[1],v[2],v[3], "V", unpack(V))
				print("u", u[1],u[2],u[3], "U", unpack(U))

				for j=4,__CLIP_TRIANGLE_VERT_ATTS do
					v[j]=tri1[i][j]
					u[j]=tri2[i][j]
				end
				tri1[i] = v 
				tri2[i] = u 
			end

			local c_tris1 = clipTri(tri1)
			local c_tris2 = clipTri(tri2)

			for i,v in ipairs(c_tris1) do
				add_tri(v) end
			for i,v in ipairs(c_tris2) do
				add_tri(v) end
		end
	end

	self.verts = verts
	print("verts")
	for i,v in ipairs(verts) do
		print(unpack(v))
	end
	return verts
end

--test ={pos={11.0,11.0},size={1.0,1.0},rot=1.0*math.pi/4}
--MapDecal.generateTileVerts(test, nil, 20, 20, nil)

local cpml = require 'cpml'
local __tempavec = cpml.vec3.new()
local __tempbvec = cpml.vec3.new()
local __tempnorm1 = cpml.vec3.new()
local __tempnorm2 = cpml.vec3.new()

local __rect_I = {1,2,3,3,4,1}
local __tri1_I = {1,2,3,4,5,6}
local __tri2_I = {1,2,3,4,5,6}
local function __getTileShapeIndices(tile_shape)
	if tile_shape==0 or tile_shape==nil then return __rect_I
	else return __tri2_I end
end
local function __getTileVerts(x,z, h1,h2,h3,h4,h5,h6, tile_shape)
	require "tile"
	local u = {0,1,1,0}
	local v = {0,0,1,1}

	local x1,y1,z1 = Tile.tileCoordToWorld( x+0 , h1 , -(z+0) )
	local x2,y2,z2 = Tile.tileCoordToWorld( x+1 , h2 , -(z+0) )
	local x3,y3,z3 = Tile.tileCoordToWorld( x+1 , h3 , -(z+1) )
	local x4,y4,z4 = Tile.tileCoordToWorld( x+0 , h4 , -(z+1) )
	local __,y5,__ = Tile.tileCoordToWorld( x+0 , h5 , -(z+1) )
	local __,y6,__ = Tile.tileCoordToWorld( x+0 , h6 , -(z+1) )

	local norm1 = __tempnorm1
	local norm2 = __tempnorm2
	local function calcnorm(norm, x1,y1,z1, x2,y2,z2, x3,y3,z3 )

		x2 = x2 - x1
		y2 = y2 - y1
		z2 = z2 - z1

		x3 = x3 - x1
		y3 = y3 - y1
		z3 = z3 - z1

		--local a,b = cpml.vec3(x2,y2,z2), cpml.vec3(x3,y3,z3)
		local a,b = __tempavec, __tempbvec
		a.x, a.y, a.z = x2,y2,z2
		b.x, b.y, b.z = x3,y3,z3

		norm = cpml.vec3.cross(a,b)
		norm = cpml.vec3.normalize(norm)
		return norm
	end

	local indices
	if tile_shape == 0 or tile_shape == nil then
		norm1 = calcnorm(norm1, x1,y1,z1, x2,y2,z2, x3,y3,z3 )
		norm2 = calcnorm(norm2, x3,y3,z3, x4,y4,z4, x1,y1,z1 )

		local norm3x = (norm1.x + norm2.x) * 0.5
		local norm3y = (norm1.y + norm2.y) * 0.5
		local norm3z = (norm1.z + norm2.z) * 0.5

		v1 = {x1,y1,z1, u[1], v[1], norm1.x, norm1.y, norm1.z }
		v2 = {x2,y2,z2, u[2], v[2], norm3x, norm3y, norm3z }
		v3 = {x3,y3,z3, u[3], v[3], norm3x, norm3y, norm3z }
		v4 = {x4,y4,z4, u[4], v[4], norm2.x, norm2.y, norm2.z }
		v5 = {0,0,0, 0,0, 0,1,0}
		v6 = {0,0,0, 0,0, 0,1,0}
		indices = __rect_I
	elseif tile_shape == 1 then
		norm1 = calcnorm(norm1, x1,y1,z1, x2,y2,z2, x3,y3,z3 )
		norm2 = calcnorm(norm2, x3,y3,z3, x4,y4,z4, x1,y1,z1 )
		v1 = {x1,y1,z1, u[1], v[1], norm1.x, norm1.y, norm1.z }
		v2 = {x2,y2,z2, u[2], v[2], norm1.x, norm1.y, norm1.z }
		v3 = {x3,y3,z3, u[3], v[3], norm1.x, norm1.y, norm1.z }
		v4 = {x3,y5,z3, u[3], v[3], norm2.x, norm2.y, norm2.z }
		v5 = {x4,y4,z4, u[4], v[4], norm2.x, norm2.y, norm2.z } 
		v6 = {x1,y6,z1, u[1], v[1], norm2.x, norm2.y, norm2.z }
		indices = __tri1_I
	elseif tile_shape == 2 then
		norm1 = calcnorm(norm1, x1,y1,z1, x2,y2,z2, x4,y4,z4 )
		norm2 = calcnorm(norm2, x2,y2,z2, x3,y3,z3, x4,y4,z4 )
		v1 = {x1,y1,z1, u[1], v[1], norm1.x, norm1.y, norm1.z }
		v2 = {x2,y2,z2, u[2], v[2], norm1.x, norm1.y, norm1.z }
		v3 = {x4,y4,z4, u[4], v[4], norm1.x, norm1.y, norm1.z }
		v4 = {x2,y5,z2, u[2], v[2], norm2.x, norm2.y, norm2.z }
		v5 = {x3,y3,z3, u[3], v[3], norm2.x, norm2.y, norm2.z } 
		v6 = {x4,y6,z4, u[4], v[4], norm2.x, norm2.y, norm2.z }
		indices = __tri1_I
	elseif tile_shape == 3 then
		norm1 = calcnorm(norm1, x3,y3,z3, x4,y4,z4, x1,y1,z1 )
		norm2 = calcnorm(norm2, x1,y1,z1, x2,y2,z2, x3,y3,z3 )
		v1 = {x1,y6,z1, u[1], v[1], norm2.x, norm2.y, norm2.z }
		v2 = {x2,y2,z2, u[2], v[2], norm2.x, norm2.y, norm2.z }
		v3 = {x3,y5,z3, u[3], v[3], norm2.x, norm2.y, norm2.z }
		v4 = {x3,y3,z3, u[3], v[3], norm1.x, norm1.y, norm1.z }
		v5 = {x4,y4,z4, u[4], v[4], norm1.x, norm1.y, norm1.z } 
		v6 = {x1,y1,z1, u[1], v[1], norm1.x, norm1.y, norm1.z }
		indices = __tri1_I
	else
		norm1 = calcnorm(norm1, x2,y2,z2, x3,y3,z3, x4,y4,z4 )
		norm2 = calcnorm(norm2, x1,y1,z1, x2,y2,z2, x4,y4,z4 )
		v1 = {x1,y1,z1, u[1], v[1], norm2.x, norm2.y, norm2.z  }
		v2 = {x2,y5,z2, u[2], v[2], norm2.x, norm2.y, norm2.z  }
		v3 = {x4,y6,z4, u[4], v[4], norm2.x, norm2.y, norm2.z  }
		v4 = {x2,y2,z2, u[2], v[2], norm1.x, norm1.y, norm1.z }
		v5 = {x3,y3,z3, u[3], v[3], norm1.x, norm1.y, norm1.z } 
		v6 = {x4,y4,z4, u[4], v[4], norm1.x, norm1.y, norm1.z }
		indices = __tri1_I
	end

	return v1,v2,v3,v4,v5,v6,indices
end

return MapDecal
