-- utility functions for testing points/line/bound box against a bounding box
--

-- corrects a bounding box to have only positive values in it's size
function correctBoundingBox(rect_pos, rect_size)
	if rect_size[1] < 0 then
		rect_pos[1] = rect_pos[1] + rect_size[1]
		rect_size[1] = -rect_size[1]
	end

	if rect_size[2] < 0 then
		rect_pos[2] = rect_pos[2] + rect_size[2]
		rect_size[2] = -rect_size[2]
	end

	if rect_size[3] < 0 then
		rect_pos[3] = rect_pos[3] + rect_size[3]
		rect_size[3] = -rect_size[3]
	end
end

-- assumes a correct bounding box with min.xyz < max.xyz
function minMaxBoundingBoxToPosSize(min, max)
	local size = {
		max[1] - min[1],
		max[2] - min[2],
		max[3] - min[3] }
	return min, size
end

-- assumes a correct bounding box with rect_size.xyz > 0
function testPointInBoundingBox(point, rect_pos, rect_size)
	local rx1,rx2 = rect_pos[1], rect_pos[1] + rect_size[1]
	local ry1,ry2 = rect_pos[2], rect_pos[2] + rect_size[2]
	local rz1,rz2 = rect_pos[3], rect_pos[3] + rect_size[3]

	-- a<b<c
	local function between(a,b,c) return a<b and b<c end

	return between(rx1, point[1], rx2) and
	       between(ry1, point[2], ry2) and
	       between(rz1, point[3], rz2)
end
