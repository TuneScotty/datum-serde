--!strict

--[[
Purpose: Main entry point for datum-serde library.
Arguments: None (module aggregates all sub-modules)
Time complexity: O(1)
]]

local DatumSerde = {
	schema = require(script.schema),
	serde = require(script.serde),
	migrate = require(script.migrate),
	codec = {
		json = require(script.codec.json),
		binary = require(script.codec.binary),
	},
}

return DatumSerde
