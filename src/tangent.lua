-- calculates the tangent vertex data for a mesh
--

local function attachTangentMesh(mesh)
	local index_map = mesh:getVertexMap()
	local vert_count = mesh:getVertexCount()

	local i = 1
	local iter
	local function next_triangle()
		if i >= vert_count then return nil end
		local I=i
		i=i+3 -- next triangle
		if index_map then return index_map[I],index_map[I+1],index_map[I+2]
		             else return I,I+1,I+2 end
	end

	local vertex, uv;
	local mesh_format = mesh:getVertexFormat()
	if mesh_format then 
		local pos_attr_i = 1
		local uv_attr_i  = 2
		for i,v in ipairs(mesh_format) do
			if v[1]=="VertexPosition" then
				pos_attr_i = i
				break
			end
		end
		for i,v in ipairs(mesh_format) do
			if v[1]=="VertexTexCoord" then
				uv_attr_i = i
				break
			end
		end
		vertex = function(i)
			return mesh:getVertexAttribute(i,pos_attr_i)
		end
		uv = function(i)
			return mesh:getVertexAttribute(i,uv_attr_i)
		end
	else
		error("tangent.lua(): mesh has undefined format.")
	end

	local tangent_v = {}
	local tangent_v_count = 0
	local function add_tangent_v(i,x,y,z)
		-- loosely interpolate already existing tangents
		local v = tangent_v[i]
		if v then
			--local tx,ty,tz = v[1],v[2],v[3]
			--v[1] = (x+tx)*0.5
			--v[2] = (y+ty)*0.5
			--v[3] = (z+tz)*0.5
		else
			tangent_v[i] = {x,y,z}
			tangent_v_count = tangent_v_count+1
		end
	end

	while true do
		local vi1,vi3,vi2 = next_triangle()
		if not vi1 then break end

		local vx1,vy1,vz1 = vertex(vi1)
		local vx2,vy2,vz2 = vertex(vi2)
		local vx3,vy3,vz3 = vertex(vi3)

		local ux1,uy1 = uv(vi1)
		local ux2,uy2 = uv(vi2)
		local ux3,uy3 = uv(vi3)

		local Ex1,Ey1,Ez1 = vx2-vx1, vy2-vy1, vz2-vz1
		local Ex2,Ey2,Ez2 = vx3-vx1, vy3-vy1, vz3-vz1

		local Dux1,Duy1 = ux2-ux1, uy2-uy1
		local Dux2,Duy2 = ux3-ux1, uy3-uy1

		local f = 1.0 / (Dux1*Duy2 - Dux2-Duy1)

		local Tx = f * (Duy2 * Ex1 - Duy1 * Ex2)
		local Ty = f * (Duy2 * Ey1 - Duy1 * Ey2)
		local Tz = f * (Duy2 * Ez1 - Duy1 * Ez2)

		add_tangent_v(vi1,Tx,Ty,Tz)
		add_tangent_v(vi2,Tx,Ty,Tz)
		add_tangent_v(vi3,Tx,Ty,Tz)
	end

	-- ensure table is fully filled out even if the input mesh has a malformed index map
	-- which doesn't use every single triangle
	if tangent_v_count < vert_count then
		for i=1,vert_count do
			if not tangent_v[i] then
				tangent_v[i]={0,0,1}
			end
		end
	end

	for i,v in ipairs(tangent_v) do
		print(i, unpack(v))
	end

	local tangent_mesh = love.graphics.newMesh({{"VertexTangent","float",3}}, tangent_v, "triangles", "static")
	mesh:attachAttribute("VertexTangent",tangent_mesh)
	return tangent_mesh
end

return attachTangentMesh
