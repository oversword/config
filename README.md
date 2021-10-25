# Config

Make reading config values for minetest easy!

## Usage

If you have a config file with settings names like this:
```lua
my_mod_name.my_setting_name = some value
my_mod_name.setting_category.another_setting_name = 345
...

```
You can parse them by declaring a settings model like this:
```lua
local settings = config.settings_model('my_mod_name', {
	my_setting_name = config.types.string("default_value"),
	setting_category = {
		another_setting_name = config.types.integer(123, { min=100, max=1000 })
	}
	...
})

print(dump(settings))
-- Output:
--{
--	my_setting_name = "some value",
--	setting_category = {
--		another_setting_name = 345
--	}
--}

```

## API

### Create a type instance
```lua
config.types.some_type(default_value[, setting_options, setting_transformer])
```
Create a type instance, `some_type` should be the name of a real type, like `string` or `number`, see "Default Types" for a full list

1. `any`   : `default_value` | the fallback value if none is configured
1. `table` : `setting_options` | the customisation options, specific for each type, see "Default Types" for a full list
1. `any`   : `setting_transformer` | a transformation map that the value will be passed through before returning

---

### Parse settings
```lua
config.settings_model(root_name, settings_config)
```
Parse all the settings in the structure of the settings_config given

1. `string`: `root_name` | The base name for the settings, usually the mod name. Like: `root_name.sub_group.my_setting_name`
1. `table` : `settings_config` | The structure of the settings for this root_name. Like: `{ sub_group = { my_setting_name = config.types.number(9) } }`

---

### Register a data type
```lua
config.register_type(names[, parser, getter])
```
Register a new data type

1. `string|string[]`: `names` | The name, or list of names for this type. Each type can have multiple aliases that all map to the same thing, e.g. bool, boolean
1. `function`       : `parser` | The function that will parse the data retrieved from the settings, can be used to parse lists and other data types from strings
1. `function`       : `getter` | The function used to retrieve data from the settings, should have a fallback for older versions

---

### Register a transformer type
```lua
config.register_transformer_type(type_string, type_transformer)
```
Register a custom transformer type

1. `string`  : `type_string` | The name of the type this transformer will accept as its first argument (user_given_mapping), there can only be one for each type
1. `function`: `type_transformer` | The type_transformer should be a function that takes the arguments `(user_given_mapping, setting_value, setting_name, setting_opts)`` and returns the transformed value

Transformer types are for mappings from human input values to computer values - so you input human values in the settings and have them mapped into the correspoding computer values in the final settings table

A use for this would be mapping `"south", "west", "north", "east"` into numbers representing the param2 for facedir, `0, 1, 2, 3`.
This would be accomplished by adding a transformer for the table (this should already be available in the default types):
```lua
config.register_transformer_type("table",
function (user_given_mapping, setting_value, setting_name, setting_opts)
	return user_given_mapping[setting_value]
end)
```

Then creating a type with the table mapping as the third argument
```lua
initial_orientation = config.types.string("north", nil, { south=0, west=1, north=2, east=3 })
```

If the setting this reads from is set to "east", then the final result will be 3
If the setting this reads from is not set, then the final result will be 2 (because "north" is the default, and maps to 2)

Note that type here is "string", the type of the data read in from the settings, NOT the type of the data it will be transformed into. This type can be anything and is of no concern ot this system.



## Default Types

You can create your own data types using `config.register_type` (see above), but there are many that come built-in:

---

### String
The simplest type, performs no parsing and just reads in the setting
#### Aliases
* `string`
* `str`
#### Settings
None

---

### Boolean
A true or false value
#### Aliases
* `boolean`
* `bool`
#### Settings
None

---

### Number
Any number
#### Aliases
* `number`
* `num`
* `float`
* `decimal`
#### Settings
* `number` : `min` | The minimum value the number can take
* `number` : `max` | The maximum value the number can take

---

### Integer
A number with no decimal places / fractional part
#### Aliases
* `integer`
* `int`
#### Settings
* `number` : `min` | The minimum value the integer can take
* `number` : `max` | The maximum value the integer can take

---

### Enumerable
Choose one string out of a list of possible values
#### Aliases
* `enumerable`
* `enum`
#### Settings
* `table` : `options` | the list of possible values it can take

---

### Vector
A spatial vector, with x, y and z coordinates
#### Aliases
* `vector`
* `vec3`
* `vec`
* `position`
* `pos`
* `v3f`
#### Settings
* `number` : `min` | The minimum value each number in the vector can take
* `number` : `max` | The maximum value each number in the vector can take

---

### Color
A color value, just a string for now
#### Aliases
* `color`
* `colour`
#### Settings
None

---

### List
A list of values, all with the same type. Separated by a comma by default, but can be configured
#### Aliases
* `list`
* `array`
* `multiple`
#### Settings
* `string` : `separator` |
* `number` : `length` |
* `type`   : `type` |

---

### Table
A literal lua table, will be parsed from the serialised string
#### Aliases
* `table`
* `luatable`
#### Settings
None
