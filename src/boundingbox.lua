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

-- tests if 2d point (u,v) is inside a rectangle with minimum point (x1,y1)
-- and maximum (x2,y2)
function testPointInRect(u,v, x1,y1,x2,y2)
	local function between(a,b,c) return a<b and b<c end
	return between(x1, u, x2) and
	       between(y1, v, y2)
end

-- tests if two 2D rectangles intersect
-- rectangles are given in min,max format
function testRectInRectMinMax(ax1,ay1,ax2,ay2 , bx1,by1,bx2,by2)
	return not (
		ax2 < bx1 or
		bx2 < ax1 or
		ay2 < by1 or
		ay2 < by1)
end

-- tests if two 2D rectangles intersect
-- rectangles are given in pos,size format
function testRectInRectPosSize(x1, y1, w1, h1, x2, y2, w2, h2)
	return testRectInRectMinMax(
	  x1, y1, x1+w1, y1+h1,
	  x2, y2, x2+w2, y2+h2
	)
end
