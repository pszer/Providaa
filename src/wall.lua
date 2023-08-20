Wall = {__type = "wall",

		vmap = {1,2,3, 3,4,1},

		u = {0,1,1,0},
		v = {0,0,1,1},

		atypes = {
		  {"VertexPosition", "float", 3},
		  {"VertexTexCoord", "float", 2},
		},

		westi = 1,
		southi = 2,
		easti = 3,
		northi = 4

}
Wall.__index = Wall

require "tile"

function Wall:new()
	local this = {
		north = nil,
		south = nil,
		west = nil,
		east = nil,

		northmesh = nil,
		southmesh = nil,
		westmesh = nil,
		eastmesh = nil,
	}

	setmetatable(this,Wall)

	return this
end

--1,2,3,4 = west,south,east,north wall
function Wall:generateWall(textures, tile_heights, west_heights, south_heights, east_heights, north_heights, offset)
	local heights_order = {
		west_heights, south_heights, east_heights, north_heights}

	-- 1,2,3,4 = west,south,east,north wall
	-- give a unit vector running alongside that wall
	local vectors = {
	 {x=0,z=-1},
	 {x=1,z=0},
	 {x=0,z=1},
	 {x=-1,z=0}
	}

	-- 1,2,3,4 = west,south,east,north wall
	-- each "_heights" argument is a table of 4 y positions
	-- height_i[i][1] & [2] give the indices for the relevant y positions in tile_heights
	-- height_i[i][3] & [4] give the indices for the relevant y positions in the opposing tile 
	local height_i = {
		{1,4, 2,3},
		{4,3, 1,2},
		{3,2, 4,1},
		{2,1, 3,4}
	}

	local wall = Wall:new()
	local dest = { "west", "south", "east", "north"}
	local destmesh = { "westmesh", "southmesh", "eastmesh", "northmesh"}

	local at_least_one_wall = false

	local vmap = {1,2,3, 3,4,1}

	-- iterative function, i goes through 1,2,3,4=west,south,east,north
	local check_side = function(i,     check_side)
		if i > 4 then return end

		--if i == 4 then print("we checkin that 4") end
		if textures[i] == nil or heights_order[i] == nil then
			check_side(i+1, check_side)
			return
		end

		local opptile = heights_order[i]

		local height_a,height_b = tile_heights[height_i[i][1]], tile_heights[height_i[i][2]]
		local oppheight_a,oppheight_b = opptile[height_i[i][3]], opptile[height_i[i][4]]

		if height_a <= oppheight_a and height_b <= oppheight_b then
			check_side(i+1, check_side)
			return
		end

		-- for now, generate both triangles of the rectangle, even if one below ground
		--local atypes = {
		--  {"VertexPosition", "float", 3},
		--  {"VertexTexCoord", "float", 2},
		--}

		local mesh = Mesh:new(textures[i], 6, "triangles", "dynamic")
		--mesh.mesh:setVertexMap(vmap)
		--mesh.mesh:setDrawRange(1,3000)

		local vector = vectors[i]

		local x,y,z = {},{},{}

		if i == 1 or i == 3 then
			x[1],y[1],z[1] = 0+vector.x, height_a,     0+vector.z
			x[2],y[2],z[2] = 0         , height_b,     0
			x[3],y[3],z[3] = 0         , oppheight_b,  0
			x[4],y[4],z[4] = 0+vector.x, oppheight_a,  0+vector.z
		else
			x[1],y[1],z[1] = 0         , height_a,     0
			x[2],y[2],z[2] = 0+vector.x, height_b,     0+vector.z
			x[3],y[3],z[3] = 0+vector.x, oppheight_b,  0+vector.z
			x[4],y[4],z[4] = 0         , oppheight_a,  0
		end

		--x[1],y[1],z[1] = 0+vector.x, height_a,     0+vector.z
		--x[2],y[2],z[2] = 0         , height_b,     0
		--x[3],y[3],z[3] = 0         , oppheight_b,  0
		--x[4],y[4],z[4] = 0+vector.x, oppheight_a,  0+vector.z

		at_least_one_wall = true

		wall[dest[i]] = {}
		wall[destmesh[i]] = mesh

		for vertex=1,4 do
			wall[dest[i]][vertex] = {x[vertex], y[vertex], z[vertex]}
		end

		check_side(i+1, check_side)
	end

	check_side(1,  check_side)

	if at_least_one_wall then
		return wall
	else
		return nil
	end
end
