local MapDecal = {
	__type = "mapdecal"
}
MapDecal.__index = MapDecal

local cpml = require "cpml"
require "rotation"

function MapDecal:new( texture,texture_name, pos,size,rot,normal)
	local this = {
		texture=texture,
		texture_name=texture_name,
		root = base,

		pos = pos,
		size = size,
		quat = nil,
		normal = {0,0,-1},
		rotation = rot,

		verts = {}, -- tableof {x,y,z, u,v, Nx,Ny,Nz,}
		mesh  = nil,
	}
	setmetatable(this, MapDecal)
	this:setNormal(normal)
	return this
end

function MapDecal:flipX()
	self.flip_x = not self.flip_x end
function MapDecal:flipY()
	self.flip_y = not self.flip_y end

function MapDecal:generateVerts(mesh, grid_w, grid_h, vert_index_map, wall_index_map) 
	self:generateMeshVerts(mesh, grid_w, grid_h, vert_index_map, wall_index_map, nil)
	--
	return self.verts
end

function MapDecal:setNormal(normal)
	local x,y,z = normal[1],normal[2],normal[3]
	local length = math.sqrt(x*x + y*y + z*z)
	if length==0 then x,y,z=0,0,-1 end
	x = x / length
	y = y / length
	z = z / length
	self.normal[1]=x
	self.normal[2]=y
	self.normal[3]=z
end
function MapDecal:genQuat()
	local norm = self.normal
	local rot = self.rotation
	local rot_quat = cpml.quat.from_angle_axis(rot,norm[1],norm[2],norm[3])
	local quat = createQuat(norm, {0,0,1})
	rot_quat = rot_quat:normalize()
	quat     = quat:normalize()
	self.quat = rot_quat * quat 

	return self.quat
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
		local verts = self.verts
		local vert_count = #verts
		local mesh_vert_count = self.mesh:getVertexCount()

		if vert_count > mesh_vert_count then
			self.mesh:release()
			self.mesh = love.graphics.newMesh(MapMesh.atypes, verts, "triangles", mode)
			self.mesh:setTexture(self.texture)
			return self.mesh
		end

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
function MapDecal:generateMeshVerts(mesh, grid_w, grid_h, vert_index_map, wall_index_map, verts)
	local pos = self.pos
	local size = self.size
	local rot = self:genQuat()

	local vec = __tempvec3
	for i=1,16 do
		decal_mat[i] = __mat4ID[i]
	end

	local flip_x = false
	local flip_y = false

	vec.x,vec.y,vec.z = size[1],size[2],size[3]
	if vec.x<0 then
		vec.x=-vec.x
		flip_x = true
	end
	if vec.y<0 then
		vec.y=-vec.y
		flip_y = true
	end
	if vec.z<0 then
		vec.z=-vec.z
	end

	decal_mat:scale(decal_mat, vec)
	local rot_m = cpml.mat4.from_quaternion(rot)
	decal_mat:mul(rot_m, decal_mat)
	vec.x,vec.y,vec.z = pos[1],pos[2],pos[3]
	decal_mat:translate(decal_mat,vec)

	local lol = {0,0,-1,0}
	cpml.mat4.mul_vec4(lol, rot_m, lol)
	--print(unpack(lol))

	local decal_mat_inv = decal_mat_inv
	decal_mat_inv:invert(decal_mat)

	local minX,maxX=nil,nil
	local minZ,maxZ=nil,nil

	local maxS = math.max(size[1],size[2],size[3])
	local floor,ceil=math.floor,math.ceil
	local min,max=math.min,math.max
	minX = max(1     , floor((pos[1] - maxS*SQRT2)/TILE_SIZE)-2)
	maxX = min(grid_w, ceil ((pos[1] + maxS*SQRT2)/TILE_SIZE)+2)
	minZ = max(1     , floor((pos[3] - maxS*SQRT2)/TILE_SIZE)-2)
	maxZ = min(grid_h, ceil ((pos[3] + maxS*SQRT2)/TILE_SIZE)+2)

	-- x,y,z, _,_, nx,ny,nz
	__CLIP_TRIANGLE_VERT_ATTS=8
	local mulv4 = cpml.mat4.mul_vec4

	local verts=verts or {}
	local vert_count=#verts
	local function add_vert(v)
		vert_count=vert_count+1
		verts[vert_count]=v
	end

	local decal_normal = self.normal
	local function map_uv(v, normal,base_a,base_b)
		local flat_u,flat_v = 0,0
		local dot = normal[1]*decal_normal[1] + normal[2]*decal_normal[2]
		--if dot==0 then -- surface lies flat on the z-plane in decal space
		--	return (v[1]+1.0)*0.5,(v[3]+1.0)*0.5
		--end
		return (v[1]+1.0)*0.5,(v[2]+1.0)*0.5 + (v[3])*0.5
	end

	local abs = math.abs
	local function add_tri(t, normal)
		for i,v in ipairs(t) do
			local uc,vc = map_uv(v, normal)
			--print(i,uc,vc)

			if flip_x then
				uc = 1.0 - uc end
			if flip_y then
				vc = 1.0 - vc end

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

	local __templ1,__templ2={},{}
	local function line(A,B, v)
		v[1]=B[1]-A[1]
		v[2]=B[2]-A[2]
		v[3]=B[3]-A[3]
		local L = math.sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3])
		if L~=0.0 then
			v[1] = v[1]/L
			v[2] = v[2]/L
			v[3] = v[3]/L
		end
		return v
	end
	local __tempn={}
	local function crossN(A, B, v)
    local x = A[2] * B[3] - A[3] * B[2]
    local y = A[3] * B[1] - A[1] * B[3]
    local z = A[1] * B[2] - A[2] * B[1]
		v[1],v[2],v[3]=x,y,z
		return v
	end

	local function doTri(tri)
		local base_a = line(tri[1],tri[2],__templ1)
		local base_b = line(tri[1],tri[3],__templ2)
		local normal = crossN(base_a,base_b,__tempn)
		if not normal then return end

		for i=1,3 do
			local v = {}, {}
			local V = {tri[i][1],tri[i][2],tri[i][3],1.0}
			mulv4(v, decal_mat_inv, V)

			for j=4,__CLIP_TRIANGLE_VERT_ATTS do
				v[j]=tri[i][j]
			end
			tri[i] = v 
		end

		local c_tris = clipTri(tri)

		for i,v in ipairs(c_tris) do
			add_tri(v, normal) end
	end

	-- look up table for already clipped geometry
	local done = {}

	local function do_index(index_start,indices)
		--print(index_start, unpack(indices))

		local iz=index_start-1
		local tri1 = {mesh[iz+indices[1]],mesh[iz+indices[2]],mesh[iz+indices[3]]}
		local tri2 = {mesh[iz+indices[4]],mesh[iz+indices[5]],mesh[iz+indices[6]]}
		if tri1[1] and tri1[2] and tri1[3] then
			doTri(tri1)
		end
		if tri2[1] and tri2[2] and tri2[3] then
			doTri(tri2)
		end
	end

	for z=minZ,maxZ do
		for x=minX,maxX do
			-- tiles
			if vert_index_map then
				local index_start   = vert_index_map[z][x].first
				local index_indices = vert_index_map[z][x].indices
				if not done[index_start] then
					do_index(index_start, index_indices)
					done[index_start] = true
				end
			end
			-- walls
			if wall_index_map then

				for side=1,5 do
					local w_index = wall_index_map[z][x][side]
					if w_index then
						local w_index_start   = w_index.first
						local w_index_indices = w_index.indices
						if w_index_start then
							if not done[w_index_start] then
								do_index(w_index_start, w_index_indices)
								done[w_index_start] = true
							end
						end
					end
				end

			end
		end
	end

	self.verts = verts
	return self.verts
end

return MapDecal
