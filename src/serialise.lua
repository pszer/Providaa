local function serializeTable(val, name, skipnewlines, depth)
	skipnewlines = skipnewlines or false
	depth = depth or 0
	local tmp = ""
	if name then 
		if type(name)~="string" then
			tmp = tmp .. "["..name .. "]="
		else
			tmp = tmp .. "[\""..name.."\"]="
		end
	end
	if type(val) == "table" then
			tmp = tmp .. "{" .. (not skipnewlines and "\n" or "")
			for k, v in pairs(val) do
					tmp =  tmp .. serializeTable(v, k, skipnewlines, depth + 1) .. "," .. (not skipnewlines and "\n" or "")
			end
			tmp = tmp.."}"
	elseif type(val) == "number" then
			tmp = tmp .. tostring(val)
	elseif type(val) == "string" then
			tmp = tmp .. string.format("%q", val)
	elseif type(val) == "boolean" then
			tmp = tmp .. (val and "true" or "false")
	else
			tmp = tmp .. "\"[inserializeable datatype:" .. type(val) .. "]\""
	end
	return tmp
end

return serializeTable
