
config.register_transformer_type("function",
	function (setting_transformer, setting_value, setting_name, setting_opts)
		return setting_transformer(setting_value, setting_name, setting_opts)
	end)

config.register_transformer_type("table",
	function (setting_transformer, setting_value, setting_name, setting_opts)
		return setting_transformer[setting_value]
	end)


local function one_of(value, values)
	for _,allowed in ipairs(values) do
		if value == allowed then
			return value
		end
	end
end

local function limit_value(value, min, max)
	if min then
		value = math.max(value, min)
	end
	if max then
		value = math.min(value, max)
	end
	return value
end

local function limit_values(values, min, max)
	local return_values = {}
	for key,value in pairs(values) do
		return_values[key] = limit_value(value, min, max)
	end
	return return_values
end


local function merge_table(def, new)
	for k,v in pairs(new) do
		-- If key-value table, recurse
		if type(v) == 'table' and #v == 0 and type(def[k]) == 'table' and #def[k] == 0 then
			def[k] = merge_table(def[k], v)
		else -- else just overwrite
			def[k] = v
		end
	end
	return def
end

local function parse_table(str)
	if not str then return end
	str = string.gsub(str, '%(', '{')
	str = string.gsub(str, '%)', '}')
	return minetest.deserialize('return '..str)
end

local function trim_string(input)
   return (input:gsub("^%s*(.-)%s*$", "%1"))
end

local function split_string(inputstr, sep)
	sep = sep or '%s'
	local t = {}
	for field, s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
		table.insert(t, field)
		if s=="" then
			return t
		end
	end
end

local function color_string_to_number(color)
	if string.sub(color,1,1) == '#' then
		color = string.sub(color, 2)
	end
	if #color < 6 then
		local r = string.sub(color,1,1)
		local g = string.sub(color,2,2)
		local b = string.sub(color,3,3)
		color = r..r .. g..g .. b..b
	elseif #color > 6 then
		color = string.sub(color, 1, 6)
	end
	return tonumber(color, 16)
end


config.register_type({ "string", "str" })

config.register_type({ "enumerable", "enum" }, function (val, setting_default, setting_opts)
	if setting_opts.options then
		val = one_of(val, setting_opts.options)
	end
	return val or setting_default
end)

config.register_type({ "integer", "int" }, function (val, setting_default, setting_opts)
	val = tonumber(val)
	if val then
		return limit_value(math.floor(val), setting_opts.min, setting_opts.max)
	end
	return setting_default
end)

config.register_type({ "number", "num", "float", "decimal" }, function (val, setting_default, setting_opts)
	val = tonumber(val)
	if val then
		return limit_value(val, setting_opts.min, setting_opts.max)
	end
	return setting_default
end)

config.register_type({ "vector", "vec3", "vec", "position", "pos", "v3f" },
	function (val, setting_default, setting_opts)
		if val then
			return vector.new(limit_values(val, setting_opts.min, setting_opts.max))
		end
		return setting_default
	end,
	function (setting_name)
		if minetest.settings then
			return minetest.string_to_pos(minetest.settings:get(setting_name))
		else
			return minetest.setting_get_pos(setting_name)
		end
	end)

config.register_type({ "boolean", "bool" },
	function (val, setting_default, setting_opts) return val end,
	function (setting_name, setting_default, setting_opts)
		if minetest.settings then
			return minetest.settings:get_bool(setting_name, setting_default)
		end
		return minetest.setting_getbool(setting_name, setting_default)
	end)

config.register_type({ "colour", "color" }, function (val, setting_default, setting_opts)
	return val or setting_default
end)

config.register_type({ "list", "array", "multiple" }, function (val, setting_default, setting_opts)
	if not val then return setting_default end

	local split_val = split_string(val, setting_opts.separator or ',')
	if not setting_opts.type then return split_val end

	local sub_val_parser = setting_opts.type().parser
	local sub_val_transformer = setting_opts.type().parser
	local out_val = {}
	for i,v in ipairs(split_val) do
		table.insert(out_val, sub_val_transformer(i, sub_val_parser(v)))
	end
	return out_val
end)

config.register_type({ "table", "luatable" }, function (val, setting_default, setting_opts)
	if not val then return setting_default end
	return parse_table(val)
end)