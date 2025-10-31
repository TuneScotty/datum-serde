--!strict

--[[
Purpose: Integration tests for complete encode/decode/migrate workflows.
Arguments: None
Time complexity: O(n) per test where n = data size
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DatumSerde = ReplicatedStorage.Packages.DatumSerde

local Schema = require(DatumSerde.schema)
local Serde = require(DatumSerde.serde)
local JSON = require(DatumSerde.codec.json)
local Migrate = require(DatumSerde.migrate)

local function assert(condition: boolean, message: string?)
	if not condition then
		error(message or "Assertion failed", 2)
	end
end

local function testFullRoundTrip()
	print("Testing full encode/decode round-trip...")

	local playerSchema = Schema.object({
		version = Schema.literal("1"),
		userId = Schema.number(),
		coins = Schema.number(),
		inventory = Schema.array(Schema.string()),
		settings = Schema.object({
			music = Schema.boolean(),
			sfx = Schema.boolean(),
		}),
	})

	local playerData = {
		version = "1",
		userId = 123456,
		coins = 1000,
		inventory = { "sword", "shield", "potion" },
		settings = {
			music = true,
			sfx = false,
		},
	}

	-- Encode
	local ok, payload = Serde.encode(playerSchema, playerData, JSON)
	assert(ok, "encode should succeed")
	assert(type(payload) == "string", "payload should be string")

	-- Decode
	local ok2, decoded = Serde.decode(playerSchema, payload, JSON)
	assert(ok2, "decode should succeed")
	assert(decoded.userId == 123456, "userId should match")
	assert(decoded.coins == 1000, "coins should match")
	assert(#decoded.inventory == 3, "inventory length should match")
	assert(decoded.settings.music == true, "settings should match")

	print("✓ Full round-trip passes")
end

local function testVersionMigration()
	print("Testing version migration workflow...")

	-- Define V1 schema
	local V1 = Schema.object({
		version = Schema.literal("1"),
		coins = Schema.number(),
		inventory = Schema.array(Schema.string()),
	})

	-- Define V2 schema (adds flags field)
	local V2 = Schema.object({
		version = Schema.literal("2"),
		coins = Schema.number(),
		inventory = Schema.array(Schema.string()),
		flags = Schema.map(Schema.string(), Schema.boolean()),
	})

	-- Create migration plan
	local plan = Migrate.plan()
	plan:add("1", "2", function(v)
		if type(v) ~= "table" or v.version ~= "1" then
			return false, "bad v1"
		end
		local result = table.clone(v)
		result.version = "2"
		result.flags = {}
		return true, result
	end)

	-- Create V1 data and encode
	local v1Data = {
		version = "1",
		coins = 500,
		inventory = { "axe", "pickaxe" },
	}

	local ok, v1Payload = Serde.encode(V1, v1Data, JSON)
	assert(ok, "V1 encode should succeed")

	-- Decode as V1
	local ok2, v1Decoded = Serde.decode(V1, v1Payload, JSON)
	assert(ok2, "V1 decode should succeed")

	-- Migrate V1 -> V2
	local ok3, v2Data = Migrate.apply(plan, v1Decoded, "1", "2")
	assert(ok3, "migration should succeed")
	assert(v2Data.version == "2", "version should be 2")
	assert(v2Data.flags ~= nil, "flags should exist")
	assert(v2Data.coins == 500, "coins should be preserved")

	-- Encode as V2
	local ok4, v2Payload = Serde.encode(V2, v2Data, JSON)
	assert(ok4, "V2 encode should succeed")

	-- Decode as V2
	local ok5, v2Final = Serde.decode(V2, v2Payload, JSON)
	assert(ok5, "V2 decode should succeed")
	assert(v2Final.version == "2", "final version should be 2")

	print("✓ Version migration workflow passes")
end

local function testValidationFailures()
	print("Testing validation failure messages...")

	local schema = Schema.object({
		name = Schema.string(),
		age = Schema.number(),
		tags = Schema.array(Schema.string()),
	})

	-- Test missing field
	local badData1 = {
		name = "Alice",
		tags = { "a", "b" },
	}
	local ok, err = Serde.encode(schema, badData1 :: any, JSON)
	assert(not ok and err, "should fail on missing field")
	assert(string.find(err :: string, "age"), "error should mention field name")

	-- Test wrong type
	local badData2 = {
		name = "Bob",
		age = "thirty",
		tags = { "x" },
	}
	ok, err = Serde.encode(schema, badData2 :: any, JSON)
	assert(not ok and err, "should fail on wrong type")
	assert(string.find(err :: string, "age") or string.find(err :: string, "number"), "error should be descriptive")

	-- Test invalid array element
	local badData3 = {
		name = "Charlie",
		age = 25,
		tags = { "valid", 123, "also_valid" },
	}
	ok, err = Serde.encode(schema, badData3 :: any, JSON)
	assert(not ok and err, "should fail on invalid array element")

	print("✓ Validation failure messages pass")
end

local function testComplexNesting()
	print("Testing complex nested structures...")

	local questSchema = Schema.object({
		id = Schema.string(),
		title = Schema.string(),
		completed = Schema.boolean(),
	})

	local playerSchema = Schema.object({
		name = Schema.string(),
		level = Schema.number(),
		quests = Schema.array(questSchema),
		stats = Schema.map(Schema.string(), Schema.number()),
		guild = Schema.optional(Schema.object({
			name = Schema.string(),
			role = Schema.string(),
		})),
	})

	local complexData = {
		name = "Hero",
		level = 50,
		quests = {
			{ id = "q1", title = "First Quest", completed = true },
			{ id = "q2", title = "Second Quest", completed = false },
		},
		stats = {
			strength = 100,
			agility = 85,
			intelligence = 92,
		},
		guild = {
			name = "Warriors",
			role = "Leader",
		},
	}

	local ok, payload = Serde.encode(playerSchema, complexData, JSON)
	assert(ok, "complex encode should succeed")

	local ok2, decoded = Serde.decode(playerSchema, payload, JSON)
	assert(ok2, "complex decode should succeed")
	assert(decoded.level == 50, "level should match")
	assert(#decoded.quests == 2, "quest count should match")
	assert(decoded.quests[1].completed == true, "nested boolean should match")
	assert(decoded.stats.strength == 100, "map values should match")
	assert(decoded.guild.name == "Warriors", "optional nested should match")

	print("✓ Complex nesting passes")
end

local function testMultiStepMigration()
	print("Testing multi-step migration...")

	local V1 = Schema.object({
		version = Schema.literal("1"),
		gold = Schema.number(),
	})

	local V2 = Schema.object({
		version = Schema.literal("2"),
		gold = Schema.number(),
		silver = Schema.number(),
	})

	local V3 = Schema.object({
		version = Schema.literal("3"),
		currency = Schema.object({
			gold = Schema.number(),
			silver = Schema.number(),
			copper = Schema.number(),
		}),
	})

	local plan = Migrate.plan()

	plan:add("1", "2", function(v)
		local result = table.clone(v)
		result.version = "2"
		result.silver = 0
		return true, result
	end)

	plan:add("2", "3", function(v)
		return true,
			{
				version = "3",
				currency = {
					gold = v.gold,
					silver = v.silver,
					copper = 0,
				},
			}
	end)

	-- Start with V1
	local v1 = { version = "1", gold = 1000 }
	local ok, v1Payload = Serde.encode(V1, v1, JSON)
	assert(ok, "V1 encode should succeed")

	local ok2, v1Dec = Serde.decode(V1, v1Payload, JSON)
	assert(ok2, "V1 decode should succeed")

	-- Migrate to V3
	local ok3, v3 = Migrate.apply(plan, v1Dec, "1", "3")
	assert(ok3, "multi-step migration should succeed")
	assert(v3.version == "3", "should reach V3")
	assert(v3.currency.gold == 1000, "gold should be preserved through migration")
	assert(v3.currency.silver == 0, "silver should be added in V2")
	assert(v3.currency.copper == 0, "copper should be added in V3")

	print("✓ Multi-step migration passes")
end

-- Run all tests
local function runTests()
	print("\n=== Integration Tests ===\n")
	testFullRoundTrip()
	testVersionMigration()
	testValidationFailures()
	testComplexNesting()
	testMultiStepMigration()
	print("\n=== All Integration Tests Passed ===\n")
end

return runTests
