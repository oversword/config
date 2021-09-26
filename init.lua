
config = {}
config.modname = minetest.get_current_modname()
config.modpath = minetest.get_modpath(config.modname)

dofile(config.modpath .. "/api.lua")
dofile(config.modpath .. "/default_types.lua")
-- dofile(config.modpath .. "/test.lua")