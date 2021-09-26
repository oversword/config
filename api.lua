
config.types = {}

local transformer_types = {}

local function DataType(parser, getter) -- System called
	return function (setting_default, setting_opts, setting_transformer) -- User called
		if setting_transformer then
			local transformer_type = type(setting_transformer)
			if not transformer_types[transformer_type] then
				local valid_transformer_types = {}
				for trans_type,_ in pairs(transformer_types) do
					table.insert(valid_transformer_types, trans_type)
				end
				error(string.format(
					"Data type transformer cannot be of type %s, must be one of: %s",
					transformer_type, table.concat(valid_transformer_types, ", ")
				))
			end
		end
		return function () -- System called
			return {
				getter = function (name, existing_names)
					if getter then
						return getter(name, setting_default, setting_opts or {})
					end
					if minetest.settings then
						return minetest.settings:get(name)
					else
						return minetest.setting_get(name)
					end
				end,
				parser = function (val)

					-- TODO: special if array?
					-- minetest.log("error", minetest.serialize({
					-- 	existing_names
					-- }))
					if parser then
						return parser(val, setting_default, setting_opts or {})
					end
					return val or setting_default
				end,
				transformer = function (name, val)
					if setting_transformer then
						return transformer_types[type(setting_transformer)](setting_transformer, val, name, setting_opts or {})
					end
					return val
				end
			}
		end
	end
end

function config.settings_model(root_name, settings_config, all_names)
	if not all_names then
		all_names = minetest.settings:get_names()
	end

	local setting_names = {}
	for _,name in ipairs(all_names) do
		if string.find(name, root_name) then
			table.insert(setting_names, name)
		end
	end

	local result = {}
	for setting_name, sub_config in pairs(settings_config) do
		local conf_type = type(sub_config)
		if conf_type == "table" then
			result[setting_name] = config.settings_model(root_name .. "." .. setting_name, sub_config, setting_names)
		elseif conf_type == "function" then
			local conf = sub_config()
			local name = root_name .. "." .. setting_name
			result[setting_name] = conf.transformer(name, conf.parser(conf.getter(name, setting_names)))
		else
			error(string.format(
				"Setting definiton must be a table or a function, %s given. If you want to hard-code a value, use a function that returns that value.",
				conf_type
			))
		end
	end
	return result
end

function config.register_transformer_type(type_string, type_transformer)
	if type(type_string) ~= "string" then
		error(string.format("Type transformer name must be a string, %s given", type(type_string)))
	end
	if type(type_transformer) ~= "function" then
		error(string.format("Type transformer must be a function, %s given", type(type_string)))
	end
	transformer_types[type_string] = type_transformer
end

function config.register_type(names, parser, getter)
	if type(names) == "string" then
		names = { names }
	end
	if type(names) ~= "table" then
		error(string.format("Data type name(s) must be a string or table of strings, %s given", type(names)))
	end
	for _,name in ipairs(names) do
		if type(name) ~= "string" then
			error(string.format("All data type names must be strings, %s given", type(name)))
		end
	end
	if parser ~= nil and type(parser) ~= "function" then
		error(string.format("Data type parser must be a function, %s given", type(parser)))
	end
	if getter ~= nil and type(getter) ~= "function" then
		error(string.format("Data type getter must be a function, %s given", type(getter)))
	end
	local data_type = DataType(parser, getter)
	for _,name in ipairs(names) do
		config.types[name] = data_type
	end
end