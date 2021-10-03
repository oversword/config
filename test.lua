
if not minetest.global_exists('test') then return end

local describe = test.describe
local it = test.it
local stub = test.stub
local assert_equal = test.assert.equal


describe("Config", function ()
	test.before_each(function ()
		config.types = {}
	end)
	test.after_all(function ()
		config.types = {}
		dofile(config.modpath .. "/default_types.lua")
	end)
	describe("Data types", function ()

		it("throws an error if anything other than a string or table of strings is passed in as the names", function ()
			test.expect.error("[Config] Data type name(s) must be a string or table of strings, number given")
			config.register_type(3456)
		end)

		it("throws an error if anything other than a string or table of strings is passed in as the names", function ()
			test.expect.error("[Config] All data type names must be strings, number given")
			config.register_type({ 456 })
		end)

		it("throws an error if anything other than a function is passed in as the parser", function ()
			test.expect.error("[Config] Data type parser must be a function, string given")
			config.register_type("", "not a function")
		end)

		it("throws an error if anything other than a function is passed in as the getter", function ()
			test.expect.error("[Config] Data type getter must be a function, string given")
			config.register_type("", nil, "not a function")
		end)

		it("registers the type generator as a function", function ()
			config.register_type("test_type")
			assert_equal(type(config.types.test_type), "function", "type generator should be a function.")
		end)

		it("registers the same type generator for each alias provided", function ()
			config.register_type({ "test_type", "second_alias" })
			assert_equal(config.types.test_type, config.types.second_alias, "type generators should be identical.")
		end)

		it("registers a type generator that can be called and returns another function that returns a table containing { getter, parser, transformer }", function ()
			config.register_type("test_type")
			local specific_type = config.types.test_type("default value")
			assert_equal(type(specific_type), "function", "specific type def should be a function.")
			local internal_type_calls = specific_type()
			assert_equal(type(internal_type_calls.getter), "function", "specific type getter should be a function.")
			assert_equal(type(internal_type_calls.parser), "function", "specific type parser should be a function.")
			assert_equal(type(internal_type_calls.transformer), "function", "specific type transformer should be a function.")
		end)

		it("calls the passed parser when the recieved parser is called", function ()
			local setting_name = "test_type"
			local default_value = "default value"
			local setting_opts = {options="these"}
			local test_value = 4673456

			local parser_stub = stub()

			config.register_type(setting_name, parser_stub.call)
			local internal_type_calls = config.types.test_type(default_value, setting_opts)()
			internal_type_calls.parser(test_value)

			parser_stub.called_times(1)
			parser_stub.called_with(test_value, default_value, setting_opts)
		end)

		it("calls the passed getter when the recieved getter is called", function ()
			local setting_name = "test_type"
			local default_value = "default value"
			local setting_opts = {options="these"}
			local test_value = 4673456

			local getter_stub = stub()

			config.register_type(setting_name, nil, getter_stub.call)
			local internal_type_calls = config.types.test_type(default_value, setting_opts)()
			internal_type_calls.getter(setting_name)

			getter_stub.called_times(1)
			getter_stub.called_with(setting_name, default_value, setting_opts)
		end)

	end)
	describe("Settings model", function ()
		
		local original_settings
		local original_settings_get

		local settings_get_stub = stub()
		local legacy_settings_get_stub = stub()

		test.before_all(function ()
			original_settings = minetest.settings
			original_settings_get = minetest.setting_get
		end)
		test.before_each(function ()
			minetest.settings = { get=settings_get_stub.call, get_names = function() return {} end }
			minetest.setting_get = legacy_settings_get_stub.call

			config.types = {}
		end)
		test.after_all(function ()
			minetest.settings = original_settings
			minetest.setting_get = original_settings_get
		end)

		it("reads the settings configured from minetest", function ()

			config.register_type("string")
			config.settings_model("test_root", {
				first_level = {
					second_level = config.types.string("default"),
					second_level_again = config.types.string("default_again"),
					second_level_sub = {
						third_level = config.types.string("third_default"),
					}
				},
				first_level_again = config.types.string("top_default"),
			})

			settings_get_stub.called_times(4)
			settings_get_stub.called_with(minetest.settings, "test_root.first_level.second_level")
			settings_get_stub.called_with(minetest.settings, "test_root.first_level.second_level_again")
			settings_get_stub.called_with(minetest.settings, "test_root.first_level.second_level_sub.third_level")
			settings_get_stub.called_with(minetest.settings, "test_root.first_level_again")
		end)

		it("uses the old settings method if the new one doesn't exist", function ()
			minetest.settings = nil

			config.register_type("string")
			config.settings_model("test_root", {
				first_level = {
					second_level = config.types.string("default"),
					second_level_again = config.types.string("default_again"),
					second_level_sub = {
						third_level = config.types.string("third_default"),
					}
				},
				first_level_again = config.types.string("top_default"),
			})

			legacy_settings_get_stub.called_times(4)
			legacy_settings_get_stub.called_with("test_root.first_level.second_level")
			legacy_settings_get_stub.called_with("test_root.first_level.second_level_again")
			legacy_settings_get_stub.called_with("test_root.first_level.second_level_sub.third_level")
			legacy_settings_get_stub.called_with("test_root.first_level_again")
		end)

		it("correctly parses values retrieved from minetest", function ()
			local parser_stub = stub(function (v) return v+1 end)
			local getter_stub = stub(function () return 6 end)
			config.register_type("int", parser_stub.call, getter_stub.call)
			local result = config.settings_model("test_root", {
				first_level = config.types.int("default")
			})

			getter_stub.called_times(1)
			getter_stub.called_with("test_root.first_level", "default", {})

			parser_stub.called_times(1)
			parser_stub.called_with(6, "default", {})

			assert_equal({ first_level = 7 }, result)
		end)

		it("correctly uses default values when no values can be read in", function ()
			config.register_type("string")
			local result = config.settings_model("test_root", {
				first_level = {
					second_level = config.types.string("default"),
					second_level_again = config.types.string("default_again"),
					second_level_sub = {
						third_level = config.types.string("third_default"),
					}
				},
				first_level_again = config.types.string("top_default"),
			})
			assert_equal({
				first_level = {
					second_level = "default",
					second_level_again = "default_again",
					second_level_sub = {
						third_level = "third_default",
					}
				},
				first_level_again = "top_default",
			}, result)
		end)

	end)
	describe("Transformer types", function ()

		it("calls the passed transformer when the recieved transformer is called", function ()
			local value = 2455675
			local setting_opts = {options="these"}
			local transformer_type_stub = stub()
			local test_transformer = function () end
			config.register_type("test_type")
			config.register_transformer_type("function", transformer_type_stub.call)
			local internal_type_calls = config.types.test_type(nil, setting_opts, test_transformer)().transformer("test_root.test_config", value)
			transformer_type_stub.called_times(1)
			transformer_type_stub.called_with(test_transformer, value, "test_root.test_config", setting_opts)
		end)

		it("calls the registered transformer type when a type is resolved with that transformer", function ()
			local value = 2455675
			local setting_opts = {options="these"}
			local transformer_type_stub = stub()
			local test_transformer = function () end
			config.register_type("test_type", function() return value end)
			config.register_transformer_type("function", transformer_type_stub.call)
			local result = config.settings_model("test_root", {
				test_config = config.types.test_type(nil, setting_opts, test_transformer)
			})
			transformer_type_stub.called_times(1)
			transformer_type_stub.called_with(test_transformer, value, "test_root.test_config", setting_opts)
		end)

	end)
	describe("Default types", function ()

		test.before_each(function ()
			dofile(config.modpath .. "/default_types.lua")
		end)
		local original_settings
		local original_settings_get


		test.before_all(function ()
			original_settings = minetest.settings
			original_settings_get = minetest.setting_get
		end)
		test.after_all(function ()
			minetest.settings = original_settings
			minetest.setting_get = original_settings_get
		end)

		describe("String", function ()

			it("reads a string in", function ()
				local settings_get_stub = stub(function () return "str" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.string()
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config="str" }, result)
			end)

		end)

		describe("Enum", function ()

			it("reads an enum value in", function ()
				local settings_get_stub = stub(function () return "two" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.enum("def", { options={"one", "two", "three"} })
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config="two" }, result)
			end)

			it("limits the enum value", function ()
				local settings_get_stub = stub(function () return "str" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.enum("def", { options={"one", "two", "three"} })
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config="def" }, result)
			end)

		end)

		describe("Integer", function ()

			it("reads an integer in", function ()
				local settings_get_stub = stub(function () return "135" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.int()
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config=135 }, result)
			end)

			it("reads a number in and floors it to an int", function ()
				local settings_get_stub = stub(function () return "1356.7556" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.int()
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config=1356 }, result)
			end)

			it("limits an int to the given max & min", function ()
				local settings_get_stub = stub(function () return "135" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config1 = config.types.int(nil, { min=200 }),
					test_config2 = config.types.int(nil, { max=100 })
				})
				settings_get_stub.called_times(2)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config1")
				settings_get_stub.called_with(minetest.settings, "test_root.test_config2")

				assert_equal({ test_config1=200, test_config2=100 }, result)
			end)

		end)

		describe("Float", function ()

			it("reads a floating point number in", function ()
				local settings_get_stub = stub(function () return "173.345365" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.float()
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config=173.345365 }, result)
			end)

			it("limits a float to the given max & min", function ()
				local settings_get_stub = stub(function () return "173.345365" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config1 = config.types.float(nil, { min=223.456474 }),
					test_config2 = config.types.float(nil, { max=123.345647 })
				})
				settings_get_stub.called_times(2)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config1")
				settings_get_stub.called_with(minetest.settings, "test_root.test_config2")

				assert_equal({ test_config1=223.456474, test_config2=123.345647 }, result)
			end)

		end)

		describe("Position", function ()

			it("reads a vec3 in", function ()
				local settings_get_stub = stub(function () return "(3,4,5)" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.vec()
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config={x=3,y=4,z=5} }, result)
			end)

			it("limits the members of a vec3 to the given max & min", function ()
				local settings_get_stub = stub(function () return "(3,4,5)" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config1 = config.types.vec(nil, { min={x=10,y=11,z=12} }),
					test_config2 = config.types.vec(nil, { max={x=-3,y=-4,z=-5} }),
					test_config3 = config.types.vec(nil, { min=10 }),
					test_config4 = config.types.vec(nil, { max=-3 })
				})
				settings_get_stub.called_times(4)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config1")
				settings_get_stub.called_with(minetest.settings, "test_root.test_config2")
				settings_get_stub.called_with(minetest.settings, "test_root.test_config3")
				settings_get_stub.called_with(minetest.settings, "test_root.test_config4")

				assert_equal({
					test_config1={x=10,y=11,z=12},
					test_config2={x=-3,y=-4,z=-5},
					test_config3={x=10,y=10,z=10},
					test_config4={x=-3,y=-3,z=-3}
				}, result)
			end)

		end)


		describe("Boolean", function ()

			it("reads a boolean in", function ()
				local settings_get_stub = stub(function () return true end)
				minetest.settings = { get_bool=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.bool()
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config=true }, result)
			end)

			it("correctly uses the defaults for booleans", function ()
				local settings_get_stub = stub(function () return true end)
				minetest.settings = { get_bool=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.bool(false)
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config", false)

				assert_equal({ test_config=true }, result)
			end)

		end)
		
		describe("Color", function ()
		end)

		describe("List", function ()

			it("reads in a comma separated list as a table", function ()
				local settings_get_stub = stub(function () return "a,b,c,d,e" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.list()
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config={"a", "b", "c", "d", "e"} }, result)
			end)

			it("reads in a list with an arbitrary separator", function ()
				local settings_get_stub = stub(function () return "aibicidie" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.list(nil, { separator="i" })
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config={"a", "b", "c", "d", "e"} }, result)
			end)

			it("reads in a list and converts the members based on the sub-type", function ()
				local settings_get_stub = stub(function () return "(1,2,3)|(4,5,6)|(7,8,9)" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.list(nil, {
						separator="|",
						type=config.types.vec()
					})
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config={{x=1,y=2,z=3},{x=4,y=5,z=6},{x=7,y=8,z=9}} }, result)
			end)

			it("converts a list of numbers, filling missing values with the default", function ()
				local settings_get_stub = stub(function () return "7,4,5,,78,3," end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.list(nil, { type=config.types.integer(22) })
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config={7,4,5,22,78,3,22} }, result)
			end)

			it("trims spaces off the end of values", function ()
				local settings_get_stub = stub(function () return " jahsf, ad,  ,asfa  ,  sdf " end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.list({}, { type = config.types.string() })
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config = { "jahsf", "ad", nil, "asfa", "sdf" } }, result)
			end)

		end)

		describe("Table", function ()

			it("reads in a serialised lua table", function ()
				local settings_get_stub = stub(function () return "{1,2,'a','b',c=123,d='dfgdg'}" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.table()
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config={1,2,"a","b",c=123,d="dfgdg"} }, result)
			end)

		end)

		describe("Table Transformer", function ()

			it("uses the table transformer type properly when a table is passed", function ()
				local settings_get_stub = stub(function () return "test" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.string(nil,nil,{ test="output" })
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config="output" }, result)
			end)

		end)

		describe("Function Transformer", function ()

			it("uses the function transformer type properly when a function is passed", function ()
				local settings_get_stub = stub(function () return "test" end)
				minetest.settings = { get=settings_get_stub.call }

				local result = config.settings_model("test_root", {
					test_config = config.types.string(nil,nil,function(inp) return inp.."_hello" end)
				})
				settings_get_stub.called_times(1)
				settings_get_stub.called_with(minetest.settings, "test_root.test_config")

				assert_equal({ test_config="test_hello" }, result)
			end)

		end)

	end)
end)


test.execute()
