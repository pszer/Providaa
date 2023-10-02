require "tile"
require "walltile"

local isqrt2 = 1/(2^0.5)

Wall = {__type = "wall",

		vmap = {1,2,3, 3,4,1},

		u = {0,1,1,0},
		v = {0,0,1,1},

		westi = 1,
		southi = 2,
		easti = 3,
		northi = 4,
		diagonali = 5,

		diagonal_norm_1 = {-isqrt2,0, isqrt2},
		diagonal_norm_2 = { isqrt2,0, isqrt2},
		diagonal_norm_3 = { isqrt2,0,-isqrt2},
		diagonal_norm_4 = {-isqrt2,0,-isqrt2},

}
Wall.__index = Wall

function Wall:new()
	local this = {
		north = nil,
		south = nil,
		west = nil,
		east = nil,
		diagonal = nil,
		diagonal_norm = nil
	}

	setmetatable(this,Wall)

	return this
end

--1,2,3,4 = west,south,east,north wall
function Wall:getWallInfo(textures, tile_shape, tile_heights, west_heights, south_heights, east_heights, north_heights)
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

	local at_least_one_wall = false

	--
	-- GENERATE WEST,SOUTH,EAST,WALL SECTION
	--
	-- iterative function, i goes through 1,2,3,4=west,south,east,north
	local check_side = function(i,     check_side)
		if i > 4 then return end

		if heights_order[i] == nil then
			check_side(i+1, check_side)
			return
		end
		if textures and textures[i] == nil then
			check_side(i+1, check_side)
			return
		end

		local opptile = heights_order[i]

		local height_a,height_b
		if tile_shape==0 then
			height_a,height_b = tile_heights[ height_i[i][1] ], tile_heights[ height_i[i][2] ]
		elseif tile_shape==1 then

			if i==2 then -- south or west
				height_a,height_b = tile_heights[4], tile_heights[5]
			elseif i==1 then
				height_a,height_b = tile_heights[6] , tile_heights[4]
			else height_a,height_b = tile_heights[ height_i[i][1] ], tile_heights[ height_i[i][2] ] end

		elseif tile_shape==2 then

			if i==2 then -- south or west
				height_a,height_b = tile_heights[6], tile_heights[3]
			elseif i==3 then
				height_a,height_b = tile_heights[3] , tile_heights[5]
			else height_a,height_b = tile_heights[ height_i[i][1] ], tile_heights[ height_i[i][2] ] end

		elseif tile_shape==3 then

			if i==3 then -- east or south
				height_a,height_b = tile_heights[5], tile_heights[2]
			elseif i==4 then
				height_a,height_b = tile_heights[2], tile_heights[6]
			else height_a,height_b = tile_heights[ height_i[i][1] ], tile_heights[ height_i[i][2] ] end

		elseif tile_shape==4 then

			if i==4 then -- west or north
				height_a,height_b = tile_heights[5], tile_heights[1]
			elseif i==1 then
				height_a,height_b = tile_heights[1], tile_heights[6]
			else height_a,height_b = tile_heights[ height_i[i][1] ], tile_heights[ height_i[i][2] ] end

		end

		local oppheight_a,oppheight_b = opptile[height_i[i][3]], opptile[height_i[i][4]]

		if height_a <= oppheight_a and height_b <= oppheight_b then
			check_side(i+1, check_side)
			return
		end

		-- for now, generate both triangles of the rectangle, even if one below ground
		local vector = vectors[i]

		local x,y,z = {},{},{}

		if height_a < oppheight_a then oppheight_a = height_a end
		if height_b < oppheight_b then oppheight_b = height_b end

		local min,max = math.min,math.max
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

		at_least_one_wall = true

		wall[dest[i]] = {}

		for vertex=1,4 do
			wall[dest[i]][vertex] = {x[vertex], y[vertex], z[vertex]}
		end

		check_side(i+1, check_side)
	end -- check side

	check_side(1,  check_side)

	--
	-- GENERATE INTERNAL DIAGONAL WALL
	if tile_shape	~= 0 then
		local top_height_a, bottom_height_a = nil,nil
		local top_height_b, bottom_height_b = nil,nil
		if     tile_shape == 1 then top_height_a,bottom_height_a = tile_heights[1], tile_heights[5]
		                            top_height_b,bottom_height_b = tile_heights[3], tile_heights[6]

		elseif tile_shape == 2 then top_height_a,bottom_height_a = tile_heights[2], tile_heights[5]
		                            top_height_b,bottom_height_b = tile_heights[4], tile_heights[6]

		elseif tile_shape == 3 then top_height_a,bottom_height_a = tile_heights[3], tile_heights[6]
		                            top_height_b,bottom_height_b = tile_heights[1], tile_heights[5]

		elseif tile_shape == 4 then top_height_a,bottom_height_a = tile_heights[4], tile_heights[6]
		                            top_height_b,bottom_height_b = tile_heights[2], tile_heights[5]
		end

		-- ensure top_height > bottom_height
		if top_height_a < bottom_height_a then
			local temp = top_height_a
			top_height_a    = bottom_height_a
			bottom_height_a = top_height_a
		end
		if top_height_b < bottom_height_b then
			local temp = top_height_b
			top_height_b    = bottom_height_b
			bottom_height_b = top_height_b
		end

		local x,y,z = {},{},{}
		if tile_shape == 1 then
			x[4],y[4],z[4] = 1,top_height_a,1
			x[3],y[3],z[3] = 0,top_height_b,0
			x[2],y[2],z[2] = 0,bottom_height_b,0
			x[1],y[1],z[1] = 1,bottom_height_a,1
			wall.diagonal_norm = Wall.diagonal_norm_1
		elseif tile_shape == 2 then
			x[4],y[4],z[4] = 1,top_height_a,0
			x[3],y[3],z[3] = 0,top_height_b,1
			x[2],y[2],z[2] = 0,bottom_height_b,1
			x[1],y[1],z[1] = 1,bottom_height_a,0
			wall.diagonal_norm = Wall.diagonal_norm_2
		elseif tile_shape == 3 then
			x[4],y[4],z[4] = 0,top_height_a,0
			x[3],y[3],z[3] = 1,top_height_b,1
			x[2],y[2],z[2] = 1,bottom_height_b,1
			x[1],y[1],z[1] = 0,bottom_height_a,0
			wall.diagonal_norm = Wall.diagonal_norm_3
		elseif tile_shape == 4 then
			x[4],y[4],z[4] = 0,top_height_a,1
			x[3],y[3],z[3] = 1,top_height_b,0
			x[2],y[2],z[2] = 1,bottom_height_b,0
			x[1],y[1],z[1] = 0,bottom_height_a,1
			wall.diagonal_norm = Wall.diagonal_norm_4
		end

		wall.diagonal = {}
		for i=1,4 do
			wall.diagonal[i] = {x[i],y[i],z[i]}
		end
	else
		wall.diagonal = nil
	end -- GENERATE INTERNAL DIAGONAL WALL

	if at_least_one_wall or wall.diagonal then
		return wall
	else
		return nil
	end
end
