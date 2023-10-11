local MapDecal = {

}
MapDecal.__index = MapDecal

require "angle"

-- texture = love2d texture file
-- texture_name = texture filename
-- base = {"tile",tile_obj} or {"wall",wall_obj}
-- pos = {x,y}, with x in [0,1] and y in [0,1] (or {-inf,inf} in case of a wall base)
-- size = {Cx,Cy}, in TILE_SIZE units
-- rot  = angle in radians, rotation around middle
function MapDecal:new(texture,texture_name,base,pos,size,rot)
	local this = {
		texture=texture,
		texture_name=texture_name,
		root = base,

		pos = pos,
		size = size or {1, 1 * texture:getHeight() / texture:getWidth()},
		rot = rot or 0.0,

		verts = {}, -- tableof {x,y,z, u,v, Nx,Ny,Nz,}
		index = nil,
		mesh  = nil,
	}

	setmetatable(this, MapDecal)
	return this
end

function MapDecal:generateVerts(mesh, grid_w, grid_h, vert_index_map, wall_index_map, regen_verts, get_heights, get_shape)
	local root_type = self.root[1]
	assert(root_type == "tile" or root_type == "wall")
	if root_type=="tile" then
		self:generateTileVerts(mesh, grid_w, grid_h, vert_index_map, regen_verts, get_heights, get_shape)	
	else
		--self:generateTileVerts(mesh, vert_index_map)	
	end
end

function MapDecal:generateMesh()
	if not self.mesh then
		local m = love.graphics.newMesh(MapMesh.atypes, self.verts, "triangles", "dynamic")
		m:setVertexMap(self.index)
		m:setTexture(texture)
		self.mesh=m
	end
end

local function isPointInTriangle(px, py, ax, ay, bx, by, cx, cy)
    -- Calculate the barycentric coordinates.
    local denominator = ((by - cy) * (ax - cx) + (cx - bx) * (ay - cy))
    local alpha = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / denominator
    local beta = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / denominator
    local gamma = 1.0 - alpha - beta

    -- Check if the point is inside the triangle.
    return alpha >= 0 and beta >= 0 and gamma >= 0
end

-- Function to calculate the determinant of a 2x2 matrix.
local function determinant(matrix)
    return matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1]
end

-- Function to create the inverse matrix from two 2D vectors forming the basis.
local function createInverseMatrix(v1, v2)
    -- Create the matrix with the vectors as its columns.
    local matrix = {
        {v1[1], v2[1]},
        {v1[2], v2[2]}
    }

    -- Calculate the determinant of the matrix.
    local det = determinant(matrix)

    -- Check if the determinant is not zero (to avoid division by zero).
    if det ~= 0 then
        -- Calculate the inverse matrix.
        local inverseMatrix = {
            {matrix[2][2] / det, -matrix[1][2] / det},
            {-matrix[2][1] / det, matrix[1][1] / det}
        }
        return inverseMatrix
    else
        -- If the determinant is zero, the inverse does not exist.
        return nil
    end
end

local function findLineSegmentIntersection(x1, y1, x2, y2, x3, y3, x4, y4)
    local denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

    if denominator == 0 then
        -- The lines are parallel and do not intersect.
        return nil
    end

    local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denominator
    local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denominator

    --if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
    if t >= 0 and t < 1 and u >= 0 and u < 1 then
        -- The line segments intersect at a point.
        local intersectionX = x1 + t * (x2 - x1)
        local intersectionY = y1 + t * (y2 - y1)
        return intersectionX, intersectionY
    else
        -- The line segments do not intersect.
        return nil
    end
end
local function lineIntersect(a1,a2,b1,b2)
	return findLineSegmentIntersection(a1[1],a1[2],a2[1],a2[2],b1[1],b1[2],b2[1],b2[2])
end

local ISQRT2 = (2^0.5)/2
function MapDecal:generateTileVerts(mesh, grid_w, grid_h, vert_index_map, regen_verts, get_heights, get_shape)
	local px,py = self.pos [1], self.pos [2]
	local Sx,Sy = self.size[1], self.size[2]
	px,py = px, py

	local theta = normTheta(self.rot)
	local sinT = math.sin(theta)
	local cosT = math.cos(theta)

	local v = {{px,py},{px,py},{px,py},{px,py}}

	-- edge normals for (v1,v2),(v2,v3),(v3,v4),(v4,v1)
	local edge_n = {{0,0},{0,0},{0,0},{0,0}}

	local SxCos = Sx*cosT*0.5
	local SxSin = Sx*sinT*0.5
	local SyCos = Sy*cosT*0.5
	local SySin = Sy*sinT*0.5

	v[1][1] = px - (SxCos - SySin)
	v[1][2] = py - (SyCos + SxSin)
	edge_n[1][1] =  sinT
	edge_n[1][2] = -cosT

	v[2][1] = px - (-SxSin - SyCos)
	v[2][2] = py - (-SySin + SxCos)
	edge_n[2][1] =   cosT
	edge_n[2][2] =   sinT

	v[3][1] = px + (SxCos - SySin)
	v[3][2] = py + (SyCos + SxSin)
	edge_n[3][1] = -sinT
	edge_n[3][2] =  cosT

	v[4][1] = px + (-SxSin - SyCos)
	v[4][2] = py + (-SySin + SxCos)
	edge_n[4][1] = -cosT
	edge_n[4][2] = -sinT


	-- distance from decal centre to corner squared
	local loci_max_dist2 = (Sx*Sx)*0.25 + (Sy*Sy)*0.25
	local corner_dist = math.sqrt(loci_max_dist2)
	local test_dist = loci_max_dist2 + 1/4 -- 1/4 = (sqrt(2)/2 )^2

	-- (minX,minY) <-> (maxX,maxY) covers entire possible region
	-- the decal is applied to
	local minX = math.max(math.min(v[1][1],v[2][1],v[3][1],v[4][1]),1)
	local maxX = math.min(math.max(v[1][1],v[2][1],v[3][1],v[4][1]),grid_w)
	local minY = math.max(math.min(v[1][2],v[2][2],v[3][2],v[4][2]),1)
	local maxY = math.min(math.max(v[1][2],v[2][2],v[3][2],v[4][2]),grid_h)
	--
	local minZ = minY
	local maxZ = maxY

	-- small +epsilon added in case of float inaccuracy
	local offset_v = {{},{},{},{}}
	for i=1,4 do
		offset_v[i][1] = px + (v[i][1] - px)*((corner_dist+1)/corner_dist)
		offset_v[i][2] = py + (v[i][2] - py)*((corner_dist+1)/corner_dist)
		--offset_v[i][2] = v[i][2] + edge_n[i][2] * (ISQRT2+0.005)
	end

	for i,v in ipairs(v) do
		print(string.format("V%d: %f,%f",i,v[1],v[2]))
		print(string.format("N%d: %f,%f",i,edge_n[i][1],edge_n[i][2]))
		print(string.format("ov%d: %f,%f",i,offset_v[i][1],offset_v[i][2]))
		print()
	end

	-- to determine whether or not a tile lies inside the decals quad,
	-- the centre-point of the tile is tested to be inside all four of the decals
	-- edges with respect to their normals.
	--
	-- a centre-point can be outside the decals quad but the tile
	-- itself can still intersect the quad. by offsetting the edges by their normals
	-- these centre-points will count as being inside the quad as expected.
	--
	-- expanding the quad region like this may in rare cases cause false positives,
	-- so an additional test is done, the distance from a tile centre-point to the decals
	-- centre must be within loci_max_dist2 + sqrt(2)/2.
	--
	local function test_grid_xz(x,y)
			local point_X = (x)+0.5
			local point_Y = (y)+0.5
			local dist2 = (point_X-px)^2 + (point_Y-py)^2
			if dist2 > test_dist+0.25 then return false end

			for i,v in ipairs(offset_v) do
				local Ex,Ey=v[1],v[2]
				local Nx,Ny=edge_n[i][1],edge_n[i][2]
				local Dx,Dy=Ex-point_X,Ey-point_Y
				local dot = Nx*Dx + Ny*Dy
				if dot<0 then return false end
			end
			return true
	end

	local int = math.floor
	local ceil = math.ceil
	local Zl = ceil(maxX)-int(minX)
	local pointInside = {nil,nil,nil,nil,nil,nil,nil}

	local function test_point_xz(x,y)
		if pointInside[x+(y-1)*Zl] then return pointInside[x+(y-1)*Zl]==1 end
		for i,p in ipairs(v) do
			local Ex,Ey=p[1],p[2]
			local Nx,Ny=edge_n[i][1],edge_n[i][2]
			local Dx,Dy=Ex-x,Ey-y
			local dot = Nx*Dx + Ny*Dy
			if dot<0 then pointInside[x+(y-1)*Zl]=0 return false end
		end
		pointInside[x+(y-1)*Zl]=1
		return true
	end

	-- returns u,v
	local uvXs = v[1][1]
	local uvYs = v[1][2]
	local uvXbase = {v[2][1]-v[1][1], v[2][2]-v[1][2]}
	local uvYbase = {v[4][1]-v[1][1], v[4][2]-v[1][2]}
	local uvInvM  = createInverseMatrix(uvXbase,uvYbase)
	local function get_uv(x,y)
		local x=x-uvXs
		local y=y-uvYs
		local u = uvInvM[1][1]*x + uvInvM[1][2]*y
		local v = uvInvM[2][1]*x + uvInvM[2][2]*y
		return u,v
	end

	--print ("uv test")
	--print("xBase",uvXbase[1],uvXbase[2])
	--print("yBase",uvYbase[1],uvYbase[2])
	--print(get_uv(v[1][1],v[1][2]))
	--print(get_uv(v[2][1],v[2][2]))
	--print(get_uv(v[3][1],v[3][2]))
	--print(get_uv(v[4][1],v[4][2]))
	--

	local vert_count=0
	local verts = {}
	local index_count=0
	local indices = {}

	local __verts={}

	if regen_verts then
		for z=int(minZ),ceil(maxZ) do
			for x=int(minX),ceil(maxX) do
				local I = x+(z-1)*Zl
				local h1,h2,h3,h4,h5,h6 = get_heights(x,z)
				local shape = get_shape(x,z)
				__verts[I]={__getTileVerts(x,z,h1,h2,h3,h4,h5,h6,shape)}
			end
		end
	end

	local function get_vert(x,z,i)
		if not regen_verts then
			local index_start = vert_index_map[z][x].first
			return {unpack(mesh[index_start+i-1])}
		else
			return {unpack(__verts[x+(z-1)*Zl][i])}
		end
	end
	local function get_indices(x,z)
		if not regen_verts then
			return vert_index_map[z][x].indices
		else
			return {unpack(__verts[x+(z-1)*Zl][7])}
		end
	end
	local function get_vcount(x,z)
		if not regen_verts then
			local vim = vert_index_map[z][x]
			local index_start,index_end = vim.first, vim.last
			return index_end-index_start+1
		else
		end
	end
	-- returns table of decal corner indices that land on a tile if any
	-- if any corners do land inside the tile, it also returns which edges
	-- intersect the square edges of the tile (but not any edges fully contained inside the tile)
	local function get_decal_corners(x,z)
		local any = false
		local inside={nil,nil,nil,nil}
		--            (1,2) (2,3) (3,4) (4,1)
		local edges ={false,false,false,false}
		for i=1,4 do
			local V = v[i]
			if V[1]>= x and V[1] < x+1 and
			   V[2]>= z and V[2] < z+1
			then
				inside[i] = true
				local j = i-1
				if j<1 then j=4 end
				edges[i] = not edges[i]
				edges[j] = not edges[j]
				any=true
			end
		end
		if not any then return nil end
		return inside,edges
	end
	local function get_edge_intersects(x,z)
		local edge12 = {}
		for i=1,4 do
			local j=i+1
			if j>4 then i=1 end
			local X,Z=lineIntersect(v[i],v[j],{x,z},{x+1,z})
			if X then table.insert(edge12,{X,Z}) end
		end
		local edge23 = {}
		for i=1,4 do
			local j=i+1
			if j>4 then i=1 end
			local X,Z=lineIntersect(v[i],v[j],{x+1,z},{x+1,z+1})
			if X then table.insert(edge23,{X,Z}) end
		end
		local edge34 = {}
		for i=1,4 do
			local j=i+1
			if j>4 then i=1 end
			local X,Z=lineIntersect(v[i],v[j],{x+1,z+1},{x,z+1})
			if X then table.insert(edge34,{X,Z}) end
		end
		local edge41 = {}
		for i=1,4 do
			local j=i+1
			if j>4 then i=1 end
			local X,Z=lineIntersect(v[i],v[j],{x,z+1},{x,z})
			if X then table.insert(edge41,{X,Z}) end
		end
		return edge12,edge23,edge34,edge41
	end
	
	local function gen_vert(x,z)
		local P={}
		local _P={{x,z},{x+1,z},{x+1,z+1},{x,z+1}}
		P[1]=test_point_xz(x,  z  )
		P[2]=test_point_xz(x+1,z  )
		P[3]=test_point_xz(x+1,z+1)
		P[4]=test_point_xz(x,  z+1)

		local VC=0
		for i=1,4 do
			if P[i] then VC=VC+1 end
		end

		if VC==0 then return end

		-- if all 4 corners of a tile are inside the decal,
		-- copy the vertices of the tile 1:1
		if VC==4 then
			--local vim = vert_index_map[z][x]
			--local index_start,index_end = vim.first, vim.last
			local count = get_vcount(x,z)
			print(count)
			if count==4 then --4 verts
				local uvs={
					{get_uv(x  ,z  )},
					{get_uv(x+1,z  )},
					{get_uv(x+1,z+1)},
					{get_uv(x  ,z+1)},
				}
				--local v_ind = vim.indices
				local v_ind = get_indices(x,z)--vim.indices
				for i=0,3 do
					local k = get_vert(x,z,i+1) --{unpack(mesh[index_start+i])}
					k[4],k[5] = uvs[i+1][1], uvs[i+1][2]
					verts[vert_count+i+1]=k
				end
				for i=1,#v_ind do
					indices[i+index_count] = vert_count+v_ind[i]
				end
				vert_count=vert_count+4
				index_count=index_count+#v_ind
			else -- 6 verts
				local uvs={
					{get_uv(x  ,z  )},
					{get_uv(x+1,z  )},
					{get_uv(x+1,z+1)},
					{get_uv(x  ,z+1)},
				}
				local v_ind = get_indices(x,z)--vim.indices
				for i=0,count-1 do
					--local k = {unpack(mesh[index_start+i])}
					local k = get_vert(x,z,i+1) --{unpack(mesh[index_start+i])}
					local _x,_y,_z = k[1],k[2],k[3]
					_x=_x/TILE_SIZE
					_z=_z/TILE_SIZE

					k[4],k[5] = get_uv(_x,_z)
					--print(unpack(k))
					verts[vert_count+i+1]=k
				end
				for i=1,#v_ind do
					indices[i+index_count] = vert_count+v_ind[i]
				end
				vert_count=vert_count+count
				index_count=index_count+#v_ind
			end
			return
		end

		if VC==1 then
			local point_inside
			for i=1,4 do
				if P[i] then point_inside=_P[i] break end
			end
		end

		local corners,edges = get_decal_corners(x,z)

		
	end

	for z=int(minZ),ceil(maxZ) do
		local str = ""
		for x=int(minX),ceil(maxX) do
			local inside = test_grid_xz(x,z)
			if inside then
				str = str .. "@"
				gen_vert(x,z)
			else
				str = str .. "."
			end
		end
		print(str)
	end

	for i,v in ipairs(verts) do
		print(string.format("vert%d",i),unpack(v))
	end
	self.verts = verts
	self.index = indices
	return verts, indices
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
