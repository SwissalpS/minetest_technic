-- See also technic/doc/api.md

local mesecons_path = minetest.get_modpath("mesecons")

local S = technic.getter

local cable_entry = "^technic_cable_connection_overlay.png"

minetest.register_craft({
	output = "technic:switching_station",
	recipe = {
		{"",                     "technic:lv_transformer", ""},
		{"default:copper_ingot", "technic:machine_casing", "default:copper_ingot"},
		{"technic:lv_cable",     "technic:lv_cable",       "technic:lv_cable"}
	}
})

local function start_network(pos)
	local tier = technic.sw_pos2tier(pos)
	if not tier then return end
	local network_id = technic.sw_pos2network(pos) or technic.create_network(pos)
	technic.activate_network(network_id)
end

local mesecon_def
if mesecons_path then
	mesecon_def = {effector = {
		rules = mesecon.rules.default,
	}}
end

minetest.register_node("technic:switching_station",{
	description = S("Switching Station"),
	tiles  = {
		"technic_water_mill_top_active.png",
		"technic_water_mill_top_active.png"..cable_entry,
		"technic_water_mill_top_active.png",
		"technic_water_mill_top_active.png",
		"technic_water_mill_top_active.png",
		"technic_water_mill_top_active.png"},
	groups = {snappy=2, choppy=2, oddly_breakable_by_hand=2, technic_all_tiers=1},
	connect_sides = {"bottom"},
	sounds = default.node_sound_wood_defaults(),
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", S("Switching Station"))
		meta:set_string("channel", "switching_station"..minetest.pos_to_string(pos))
		meta:set_string("formspec", "field[channel;Channel;${channel}]")
		start_network(pos)
	end,
	after_dig_node = function(pos)
		-- Remove network when switching station is removed, if
		-- there's another switching station network will be rebuilt.
		local network_id = technic.sw_pos2network(pos)
		local network = network_id and technic.networks[network_id]
		if network then
			if #network.SP_nodes <= 1 then
				-- Last switching station, network collapses
				technic.remove_network(network_id)
			else
				-- Remove switching station from network
				network.SP_nodes[minetest.hash_node_position(pos)] = nil
				network.all_nodes[minetest.hash_node_position(pos)] = nil
			end
		end
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		if not fields.channel then
			return
		end
		local plname = sender:get_player_name()
		if minetest.is_protected(pos, plname) then
			minetest.record_protection_violation(pos, plname)
			return
		end
		local meta = minetest.get_meta(pos)
		meta:set_string("channel", fields.channel)
	end,
	mesecons = mesecon_def,
	digiline = {
		receptor = {
			rules = technic.digilines.rules,
			action = function() end
		},
		effector = {
			rules = technic.digilines.rules,
			action = function(pos, node, channel, msg)
				if msg ~= "GET" and msg ~= "get" then
					return
				end
				local meta = minetest.get_meta(pos)
				if channel ~= meta:get_string("channel") then
					return
				end
				local network_id = technic.sw_pos2network(pos)
				local network = network_id and technic.networks[network_id]
				if network then
					digilines.receptor_send(pos, technic.digilines.rules, channel, {
						supply = network.supply,
						demand = network.demand,
						lag = network.lag
					})
				else
					digilines.receptor_send(pos, technic.digilines.rules, channel, {
						error = "No network",
					})
				end
			end
		},
	},
})

-----------------------------------------------
-- The action code for the switching station --
-----------------------------------------------

-- Timeout ABM
-- Timeout for a node in case it was disconnected from the network
-- A node must be touched by the station continuously in order to function
local function switching_station_timeout_count(pos, tier)
	local timeout = technic.get_timeout(tier, pos)
	if timeout <= 0 then
		local meta = minetest.get_meta(pos)
		meta:set_int(tier.."_EU_input", 0) -- Not needed anymore <-- actually, it is for supply converter
		return true
	else
		technic.touch_node(tier, pos, timeout - 1)
		return false
	end
end
minetest.register_abm({
	label = "Machines: timeout check",
	nodenames = {"group:technic_machine"},
	interval   = 1.9,
	chance     = 3,
	action = function(pos, node, active_object_count, active_object_count_wider)
		for tier, machines in pairs(technic.machines) do
			if machines[node.name] and switching_station_timeout_count(pos, tier) then
				local nodedef = minetest.registered_nodes[node.name]
				if nodedef and nodedef.technic_disabled_machine_name then
					node.name = nodedef.technic_disabled_machine_name
					minetest.swap_node(pos, node)
				elseif nodedef and nodedef.technic_on_disable then
					nodedef.technic_on_disable(pos, node)
				end
				if nodedef then
					local meta = minetest.get_meta(pos)
					meta:set_string("infotext", S("%s Has No Network"):format(nodedef.description))
				end
			end
		end
	end,
})

--Re-enable network of switching station if necessary, similar to the timeout above
minetest.register_abm({
	label = "Machines: re-enable check",
	nodenames = {"technic:switching_station"},
	interval   = 1,
	chance     = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local network_id = technic.sw_pos2network(pos)
		-- Check if network is overloaded / conflicts with another network
		if network_id then
			local infotext
			local meta = minetest.get_meta(pos)
			if technic.is_overloaded(network_id) then
				local remaining = technic.reset_overloaded(network_id)
				if remaining > 0 then
					infotext = S("%s Network Overloaded, Restart in %dms"):format(S("Switching Station"), remaining / 1000)
				else
					infotext = S("%s Restarting Network"):format(S("Switching Station"))
				end
				technic.network_infotext(network_id, infotext)
			else
				-- Network exists and is not overloaded, reactivate for 4 seconds
				technic.activate_network(network_id)
				infotext = technic.network_infotext(network_id)
			end
			meta:set_string("infotext", infotext)
		else
			-- Network does not exist yet, attempt to create new network here
			start_network(pos)
		end
	end,
})

for tier, machines in pairs(technic.machines) do
	-- SPECIAL will not be traversed
	technic.register_machine(tier, "technic:switching_station", "SPECIAL")
end
