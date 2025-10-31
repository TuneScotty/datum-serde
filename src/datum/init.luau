--!strict

--[[
Purpose: Main entry point for datum-serde library.
Arguments: None (module aggregates all sub-modules)
Time complexity: O(1)
]]

local DatumSerde = {
	schema = require("./schema"),
	serde = require("./serde"),
	migrate = require("./migrate"),
	codec = {
		json = require("./codec/json"),
		binary = require("./codec/binary"),
	},
}

return DatumSerde
