local function noop(...) end
local function dummy_coords(...) return { x = 123, y = 123, z = 123 } end

_G.core = {}
_G.minetest = _G.core

local configuration_file = fixture_path("minetest.cfg")
_G.Settings = function(fname)
	local settings = {
		_data = {},
		get = function(self, key)
			return self._data[key]
		end,
		get_bool = function(self, key, default)
			return
		end,
		set = function(...)end,
		set_bool = function(...)end,
		write = function(...)end,
		remove = function(self, key)
			self._data[key] = nil
			return true
		end,
		get_names = function(self)
			local result = {}
			for k,_ in pairs(t) do
				table.insert(result, k)
			end
			return result
		end,
		to_table = function(self)
			local result = {}
			for k,v in pairs(self._data) do
				result[k] = v
			end
			return result
		end,
	}
	-- Not even nearly perfect config parser but should be good enough for now
	file = assert(io.open(fname, "r"))
	for line in file:lines() do
		for key, value in string.gmatch(line, "([^= ]+) *= *(.-)$") do
			settings._data[key] = value
		end
	end
	return settings
end
_G.core.settings = _G.Settings(configuration_file)

_G.core.register_on_joinplayer = noop
_G.core.register_on_leaveplayer = noop

fixture("minetest/game/misc")
fixture("minetest/misc_helpers")

_G.minetest.registered_nodes = {
	testnode1 = {},
	testnode2 = {},
}

_G.minetest.registered_chatcommands = {}

_G.minetest.register_lbm = noop
_G.minetest.register_abm = noop
_G.minetest.register_chatcommand = noop
_G.minetest.chat_send_player = noop
_G.minetest.register_craftitem = noop
_G.minetest.register_craft = noop
_G.minetest.register_on_placenode = noop
_G.minetest.register_on_dignode = noop
_G.minetest.item_drop = noop

_G.minetest.get_pointed_thing_position = dummy_coords
