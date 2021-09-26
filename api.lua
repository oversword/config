
-- Records of registered items
config.types = {}
local transformer_types = {}

-- Neater error logging
local function err(message, ...)
	error( "[Config] " .. string.format( message, ... ) )
end

--[[ Create a type check generator

	This is a bit of a mess of functions
	The first level (DataType) is called with the getter & setter passed in to config.register_type
		The function it returns is the function the user will call when they use config.types.[string|bool|int...] to specify a type
			The function that returns is therefore the unique instance that identifies a specific type definition (like a number with a specific default value and min & max)
			This could be a table, but it would be hard to differentiate between a child-structure table and these, so it is a function that returns a table
				The table it returns always provides a table, which has the property getter, data parser, and transformation mapper separately in case they need to be called in a weird order (see lists in default_types)
]]
local function DataType(parser, getter) -- System called
	return function (setting_default, setting_opts, setting_transformer) -- User called

		-- Check that a passed settings transformer is valid, if not error with a list of valid values
		if setting_transformer then
			local transformer_type = type(setting_transformer)
			if not transformer_types[transformer_type] then
				local valid_transformer_types = {}
				for trans_type,_ in pairs(transformer_types) do
					table.insert(valid_transformer_types, trans_type)
				end
				err( "Data type transformer cannot be of type %s, must be one of: %s",
					 transformer_type, table.concat(valid_transformer_types, ", "))
			end
		end

		-- This function uniquely identifies a specific type definition
		return function () -- System called
			return {
				getter = function (name, existing_names)
					-- Call the getter if one has been provided, or use default get method (string)
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
					-- Use the parser if one has been provided, or just return the given value or the default if the value is empty

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
					-- Transform the value (default or configured) using a registered transformer, or just pass the value through
					if setting_transformer then
						return transformer_types[type(setting_transformer)](setting_transformer, val, name, setting_opts or {})
					end
					return val
				end
			}
		end
	end
end

--[[ Parse all the settings in the structure of the settings_config given
	ARGS:
		string: root_name | The base name for the settings, usually the mod name. Like: root_name.sub_group.my_setting_name
		table : settings_config | The structure of the settings for this root_name. Like: { sub_group = { my_setting_name = config.types.number(9) } }
		table : all_names | DO NOT PASS IN. This is a system passed var, used from one recursion of this function to another. It is a list of all the possible settings names that could be parsed at this level
	RETURN:
		table : Returns a table with the same structure as settings_config, but with the resolved settings values instead of the type definitions
]]
function config.settings_model(root_name, settings_config, all_names)
	
	-- root_name must be string
	if type(root_name) ~= 'string' then
		err("The root name for a settings model must be a string, %s given.", type(root_name))
	end

	-- settings_config must be table
	if type(settings_config) ~= 'table' then
		err("A settings model config must be a table, %s given.", type(settings_config))
	end

	-- If there is not a list of names (on the entry call), then get all the names MT knows about
	if not all_names then
		all_names = minetest.settings:get_names()
	end

	-- Filter the list of names to only those relevat to this namespace & level
	local setting_names = {}
	for _,name in ipairs(all_names) do
		if string.find(name, root_name) then
			table.insert(setting_names, name)
		end
	end

	-- Read in all the settings, and resolve their values, returning a table of setting values
	local result = {}
	for setting_name, sub_config in pairs(settings_config) do
		local conf_type = type(sub_config)

		if conf_type == "table" then
			-- If it's a table, recurse
			result[setting_name] = config.settings_model(root_name .. "." .. setting_name, sub_config, setting_names)
		elseif conf_type == "function" then
			-- If it's a function, then it's a leaf. Resolve the value.
			local conf = sub_config()
			local name = root_name .. "." .. setting_name
			result[setting_name] = conf.transformer(name, conf.parser(conf.getter(name, setting_names)))
		else
			-- If it's neither, freak out
			err(
				"Setting definiton must be a table or a function, %s given. If you want to hard-code a value, use a function that returns that value.",
				conf_type
			)
		end
	end
	return result
end

--[[ Register a custom transformer type

	string  : type_string | The name of the type this transformer will accept as its first argument (user_given_mapping), there can only be one for each type
	function: type_transformer | The type_transformer should be a function that takes the arguments (user_given_mapping, setting_value, setting_name, setting_opts) and returns the transformed value

	Transformer types are for mappings from human input values to computer values - so you input human values in the settings and have them mapped into the correspoding computer values in the final settings table

	A use for this would be mapping "south", "west", "north", "east" into numbers representing the param2 for facedir, 0, 1, 2, 3.
	This would be accomplished by adding a transformer for the table (this should already be available in the default types):

	config.register_transformer_type("table",
		function (user_given_mapping, setting_value, setting_name, setting_opts)
			return user_given_mapping[setting_value]
		end)

	Then creating a type with the table mapping as the third argument

	initial_orientation = config.types.string("north", nil, { south=0, west=1, north=2, east=3 })

	If the setting this reads from is set to "east", then the final result will be 3
	If the setting this reads from is not set, then the final result will be 2 (because "north" is the default, and maps to 2)

	Note that type here is "string", the type of the data read in from the settings, NOT the type of the data it will be transformed into. This type can be anything and is of no concern ot this system.
]]
function config.register_transformer_type(type_string, type_transformer)

	-- Type name must be a string
	if type(type_string) ~= "string" then
		err("Type transformer name must be a string, %s given", type(type_string))
	end

	-- Transformer must be a function
	if type(type_transformer) ~= "function" then
		err("Type transformer must be a function, %s given", type(type_string))
	end

	-- Register
	transformer_types[type_string] = type_transformer
end

--[[ Register a new data type
	string|string[]: names | The name, or list of names for this type. Each type can have multiple aliases that all map to the same thing, e.g. bool, boolean
	function       : parser | The function that will parse the data retrieved from the settings, can be used to parse lists and other data types from strings
	function       : getter | The function used to retrieve data from the settings, should have a fallback for older versions
]]
function config.register_type(names, parser, getter)

	-- Normalise names as a list of strings	
	if type(names) == "string" then
		names = { names }
	end

	-- List of names must be a table of strings
	if type(names) ~= "table" then
		err("Data type name(s) must be a string or table of strings, %s given", type(names))
	end
	for _,name in ipairs(names) do
		if type(name) ~= "string" then
			error(string.format("All data type names must be strings, %s given", type(name)))
		end
	end

	-- Parser must be a function
	if parser ~= nil and type(parser) ~= "function" then
		error(string.format("Data type parser must be a function, %s given", type(parser)))
	end

	-- Getter must be a function
	if getter ~= nil and type(getter) ~= "function" then
		error(string.format("Data type getter must be a function, %s given", type(getter)))
	end

	-- Create a new type generator
	local data_type = DataType(parser, getter)

	-- Register for all aliases
	for _,name in ipairs(names) do
		config.types[name] = data_type
	end
end