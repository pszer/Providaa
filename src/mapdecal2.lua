local MapDecal = {}
MapDecal.__index = MapDecal

local cpml = require "cpml"

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

function MapDecal:setPosition()
end

function MapDecal:generateVerts(mesh, grid_w, grid_h, vert_index_map, wall_index_map, regen_verts, get_heights, get_shape)
	self:generateTileVerts(mesh, grid_w, grid_h, vert_index_map)	
end

function MapDecal:generateMesh(mode)
	local mode = mode or "dynamic"
	if not self.mesh then
		local verts = self.verts
		if #verts == 0 then
			verts = {
				{0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0},
				{0,0,0,0,0,0,0,0},
			}
			local m = love.graphics.newMesh(MapMesh.atypes, verts, "triangles", mode)
			self.mesh=m
			return nil
		end
		local m = love.graphics.newMesh(MapMesh.atypes, verts, "triangles", mode)
		m:setTexture(self.texture)
		self.mesh=m
		return m
	else
		local vert_count = #verts
		if vert_count == 0 then
			self.mesh:setDrawRange(1,1)
			return nil
		end
		self.mesh:setVertices(verts, 1, vert_count)
		self.mesh:setDrawRange(1,vert_count)
		return self.mesh
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

	vec.x,vec.y,vec.z = size[1],size[2],size[3]
	decal_mat:scale(decal_mat, vec)
	local rot_m = cpml.mat4.from_quaternion(rot)
	decal_mat:mul(rot_m, decal_mat)
	vec.x,vec.y,vec.z = pos[1],pos[2],pos[3]
	decal_mat:translate(decal_mat,vec)

	local decal_mat_inv = decal_mat_inv
	decal_mat_inv:invert(decal_mat)

	local minX,maxX=nil,nil
	local minZ,maxZ=nil,nil

	local floor,ceil=math.floor,math.ceil
	local min,max=math.min,math.max
	minX = max(1     , floor((pos[1] - size[1]*SQRT2)/TILE_SIZE))
	maxX = min(grid_w, ceil ((pos[1] + size[1]*SQRT2)/TILE_SIZE))
	minZ = max(1     , floor((pos[3] - size[3]*SQRT2)/TILE_SIZE))
	maxZ = min(grid_h, ceil ((pos[3] + size[3]*SQRT2)/TILE_SIZE))

	-- x,y,z, _,_, nx,ny,nz
	__CLIP_TRIANGLE_VERT_ATTS=8
	local mulv4 = cpml.mat4.mul_vec4

	local verts={}
	local vert_count=0
	local function add_vert(v)
		vert_count=vert_count+1
		verts[vert_count]=v
	end
	local abs = math.abs
	local function add_tri(t)
		for i,v in ipairs(t) do
			local uc,vc = v[1],v[2]
			uc = (uc+1.0)*0.5
			vc = (vc+1.0)*0.5

			local V = {v[1],v[2],v[3],1.0}
			mulv4(V, decal_mat, V)
			for j=6,__CLIP_TRIANGLE_VERT_ATTS do
				V[j] = v[j]
			end
			V[4]=uc
			V[5]=vc
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

			--print(x,z)
			for i=1,3 do
				--print(" ",i)
				local v,u = {}, {}
				local V,U = {tri1[i][1],tri1[i][2],tri1[i][3],1.0},{tri2[i][1],tri2[i][2],tri2[i][3],1.0}
				mulv4(v, decal_mat_inv, V)
				mulv4(u, decal_mat_inv, U)

				--print("v", v[1],v[2],v[3], "V", unpack(V))
				--print("u", u[1],u[2],u[3], "U", unpack(U))

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
		print("u,v",v[4],v[5])
	end
	return verts
end

return MapDecal
