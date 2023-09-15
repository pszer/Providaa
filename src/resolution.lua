RESOLUTION_RATIO = 1
RESOLUTION_ASPECT = "16:9"
RESOLUTION_ASPECT_RATIO = 16/9
RESOLUTION_169W = 1366
RESOLUTION_169H = 768
--RESOLUTION_169W = 2560
--RESOLUTION_169H = 1440
RESOLUTION_43W = 1024
RESOLUTION_43H = 768
RESOLUTION_CHANGED = false
RESOLUTION_PADW = true

function update_resolution_ratio( w,h )
	local predefined_w, predefined_h = get_resolution(w,h)

	local wr = w / predefined_w
	local hr = h / predefined_h
	if wr<hr then
		RESOLUTION_RATIO = wr
		RESOLUTION_PADW=false
	else
		RESOLUTION_RATIO = hr 
		RESOLUTION_PADW=true
	end

	RESOLUTION_ASPECT, RESOLUTION_ASPECT_RATIO  = get_aspect_ratio( w,h )
	RESOLUTION_CHANGED = true
end

-- gets best fit
-- either "16:9" or "4:3"
function get_aspect_ratio( w,h )
	local r169, r43 = 16/9, 4/3
	local r = w/h
	local r169d = math.abs(r-r169)
	local r43d = math.abs(r-r43)
	if r169d < r43d then
		return "16:9", 16/9
	else
		return "4:3", 4/3
	end
end

function get_resolution( w,h )
	local winw, winh = w or love.graphics.getWidth(), h or love.graphics.getHeight()
	local ratio = get_aspect_ratio(winw,winh)
	if ratio == "16:9" then
		return RESOLUTION_169W, RESOLUTION_169H
	else
		return RESOLUTION_43W, RESOLUTION_43H
	end
end
