--[[
-- type checked table of properties with input validation and default values
-- ]]
--

require "provtype"
require "id"
require "propvalids"

Props = {}
Props.__index = Prop
Props.__type  = "proptableprototype"

-- creates a prototype property table that can
-- be reused several times
-- takes in a table of arguments, with each
-- argument being a table for a row in the property table
-- {key, type, default, valid, options}
-- key       - key for the property
-- type      - lua type for the property, if nil then there is no type checking
-- default   - default value for the property
-- valid     - function called when setting the value of a property to check validity
--             if nil then there is no input validity checking
-- info      - a string of information of what the property is for (optional)
--
-- possible options (all optional), multiple options can be used by combining options into one string eg "readonly+callonly"
-- readonly  - if set to true then the property is unchangable after initial construction
-- callonly  - if set to true and the property is a function, it is called with no arguments when indexed
--
-- validity checking functions work as follows
-- they take 1 argument, which is what the property is being asked to be set to
-- they should return true/false and the value that the property will be set to
-- if it returns false as first argument then an error is raised
--
--
function Props:prototype(arg)
	local p = {}

	for _,row in pairs(arg) do
		-- the property will be stored in p as
		-- p[key] = {type, default, valid}
		local property = {row[2], row[3], row[4], row[5] or row[1].." "..row[2],
			row[6]~=nil and string.find(row[6], "readonly"),
			row[6]~=nil and string.find(row[6], "callonly"),
			}
		setmetatable(property, PropsPrototypeRowMeta)
		p[row[1]] = property
	end

	setmetatable(p, Props)

	return p
end

-- this metatable allows for accessing the info for a row
-- in a property prototype as follows
-- prototype.key.type
-- prototype.key.default
-- prototype.key.valid
PropsPrototypeRowMeta = {
	type = 1, default = 2, valid = 3, info = 4, readonly = 5, callonly = 6}
PropsPrototypeRowMeta.__index = function (row, k)
	return rawget(row, rawget(PropsPrototypeRowMeta, k))
end

-- once a prototype is created, it can be called like a function
-- to give an instance of a prototype table
-- initial values of properties can be given through the optional init argument
-- i.e init = {"prop1" = 0, "prop2" = 1} will assign 0 and 1 to properties prop0 and prop1
--
-- all instances of a property table have ["__proto"] that points to their prototype
-- if that information is required
--
-- an instance of a property table can be read and written to like a regular table but
-- it has the type checking and validity checking of the prototype table in place
Props.__call = function (proto, init)
	local props = { __proptabledata = {} }
	local enforce_read_only = false -- we ignore readonly when creating a property table, ugly doin this way but works

	props.__proto = proto
	props.__type = "proptable"
	props.__newindex = -- this is huge, perhaps clean up
	                   -- also each property table potentially creates an instance of these metamethods.
					   -- sharing them would use less memory unless LuaJIT does magic i'm not aware of
	function (p, key, val)
		local row = proto[key]
		if row == nil then
			error("property [" .. tostring(key) .. "] does not exist")
		end

		if row.readonly and enforce_read_only then
			error("property [" .. tostring(key) .. "] is read only")
		end

		local validvalue = val
		if row.valid then
			local good
			good, validvalue = row.valid(val)
			if not good then
				error("value " .. tostring(val) .. " is invalid for property [" .. tostring(key) .. "]")
			end
		end

		if row.type ~= nil and row.type ~= provtype(validvalue) then
			error("property [" .. tostring(key) .. "] is a " .. row.type .. ", tried to assign a " .. provtype(val)
			       .. " (" .. tostring(val) .. ")")
		end

		if row.type == "link" and provtype(validvalue) ~= "link" then
			(rawget(p.__proptabledata, key)[2]) (validvalue)
		end

		rawset(p.__proptabledata, key, validvalue)
	end

	props.__index = function (p, key)
		local v = rawget(p.__proptabledata, key)
		if v ~= nil then
			if provtype(v) == "function" and p.__proto[key].callonly then
				return v()
			elseif provtype(v) == "link" then
				return v[1]()
			else
				return v
			end
		else
			if p.__proto[key] then
				return p.__proto[key].default
			else
				error("key " .. tostring(key) .. "doesn't exist")
				return nil
			end
		end
	end

	props.__call = function (props, t)
		for k,v in pairs(t) do
			props[k]=v
		end
	end

	props.__pairs = function (p)
		return pairs(p.__proptabledata)
	end

	props.__tostring = function (p)
		local result = ""
		for k,v in pairs(p.__proptabledata) do
			result = result .. tostring(k) .. " = " .. tostring(v) .. "\n"
		end
		return result
	end

	function props.rawget(key)
		return rawget(p.__proptabledata, key)
	end

	function props.rawset(key, value)
		return rawset(p.__proptabledata, key, value)
	end

	setmetatable(props, props)

	for key,row in pairs(proto) do
		props[key] = (init and init[key]) or proto[key].default
	end

	enforce_read_only = true
	return props
end
