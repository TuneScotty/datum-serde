--!strict

--[[
Purpose: Integration tests for ProfileStore + datum-serde using actual ProfileStore library.
Arguments: None
Time complexity: O(n) per test where n = data size + migration cost
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DatumSerde = ReplicatedStorage.Packages.DatumSerde
local ProfileStore = require(ReplicatedStorage.Packages.DevPackages.ProfileStore)

local Schema = require(DatumSerde.schema)
local Serde = require(DatumSerde.serde)
local JSON = require(DatumSerde.codec.json)
local Migrate = require(DatumSerde.migrate)

local function assert(condition: boolean, message: string?)
	if not condition then
		error(message or "Assertion failed", 2)
	end
end

-- Define test schemas (V1 -> V2 -> V3 migration)
local PlayerV1 = Schema.object({
	version = Schema.literal("1"),
	coins = Schema.number(),
	items = Schema.array(Schema.string()),
})

local PlayerV2 = Schema.object({
	version = Schema.literal("2"),
	coins = Schema.number(),
	gems = Schema.number(),
	items = Schema.array(Schema.object({
		id = Schema.string(),
		count = Schema.number(),
	})),
})

local PlayerV3 = Schema.object({
	version = Schema.literal("3"),
	currency = Schema.object({
		coins = Schema.number(),
		gems = Schema.number(),
	}),
	items = Schema.array(Schema.object({
		id = Schema.string(),
		count = Schema.number(),
	})),
	level = Schema.number(),
})

-- Migration plan
local migrationPlan = Migrate.plan()

migrationPlan:add("1", "2", function(v1)
	if type(v1) ~= "table" or v1.version ~= "1" then
		return false, "invalid v1"
	end

	local newItems = {}
	for _, itemId in ipairs(v1.items) do
		table.insert(newItems, { id = itemId, count = 1 })
	end

	return true, {
		version = "2",
		coins = v1.coins,
		gems = 0,
		items = newItems,
	}
end)

migrationPlan:add("2", "3", function(v2)
	if type(v2) ~= "table" or v2.version ~= "2" then
		return false, "invalid v2"
	end

	return true,
		{
			version = "3",
			currency = {
				coins = v2.coins,
				gems = v2.gems,
			},
			items = v2.items,
			level = 1,
		}
end)

migrationPlan:lock()

local function testSchemaValidation()
	print("Testing schema validation with ProfileStore template...")

	local template = {
		version = "3",
		currency = { coins = 100, gems = 0 },
		items = {},
		level = 1,
	}

	-- Validate template against schema
	local ok, err = PlayerV3.validate(template, "/template")
	assert(ok, "Template should be valid: " .. tostring(err))

	print("✓ Schema validation passes")
end

local function testDataMigration()
	print("Testing data migration V1 -> V3...")

	local v1Data = {
		version = "1",
		coins = 500,
		items = { "sword", "shield", "potion" },
	}

	-- Validate V1 data
	local okV1, errV1 = PlayerV1.validate(v1Data, "/v1")
	assert(okV1, "V1 data should be valid: " .. tostring(errV1))

	-- Migrate to V3
	local okM, migrated = Migrate.apply(migrationPlan, v1Data, "1", "3")
	assert(okM, "Migration should succeed: " .. tostring(migrated))

	-- Validate V3 result
	local okV3, errV3 = PlayerV3.validate(migrated, "/v3")
	assert(okV3, "Migrated V3 data should be valid: " .. tostring(errV3))

	-- Verify data integrity
	assert(migrated.version == "3", "Should be V3")
	assert(migrated.currency.coins == 500, "Should preserve coins")
	assert(migrated.currency.gems == 0, "Should add gems")
	assert(#migrated.items == 3, "Should preserve item count")
	assert(migrated.items[1].id == "sword", "Should convert items")
	assert(migrated.items[1].count == 1, "Should add count")
	assert(migrated.level == 1, "Should add level")

	print("✓ Data migration passes")
end

local function testProfileStoreWithValidation()
	print("Testing ProfileStore with datum-serde validation and migration...")

	local template = {
		version = "3",
		currency = { coins = 100, gems = 0 },
		items = {},
		level = 1,
	}

	-- Create ProfileStore
	local store = ProfileStore.New("TestStore_" .. tostring(os.time()), template)

	-- Validate template
	local okTemplate, errTemplate = PlayerV3.validate(template, "/template")
	assert(okTemplate, "ProfileStore template should be valid: " .. tostring(errTemplate))

	-- Simulate profile data that needs migration (V1 format)
	local oldProfileData = {
		version = "1",
		coins = 250,
		items = { "hammer", "nails" },
	}

	-- Validate old data against V1 schema
	local okOld, errOld = PlayerV1.validate(oldProfileData, "/old")
	assert(okOld, "Old profile data should be valid V1: " .. tostring(errOld))

	-- Apply migration chain V1 -> V3
	local okMigrate, migratedData = Migrate.apply(migrationPlan, oldProfileData, "1", "3")
	assert(okMigrate, "Migration should succeed: " .. tostring(migratedData))

	-- Validate migrated data against V3 schema
	local okMigrated, errMigrated = PlayerV3.validate(migratedData, "/migrated")
	assert(okMigrated, "Migrated data should be valid V3: " .. tostring(errMigrated))

	-- Simulate updating profile.Data with migrated data (what would happen in real usage)
	local simulatedProfile = table.clone(template)
	for k, v in pairs(migratedData) do
		simulatedProfile[k] = v
	end

	-- Verify final profile state
	local okFinal, errFinal = PlayerV3.validate(simulatedProfile, "/final")
	assert(okFinal, "Final profile should be valid: " .. tostring(errFinal))
	assert(simulatedProfile.currency.coins == 250, "Coins preserved through migration")
	assert(#simulatedProfile.items == 2, "Items preserved")
	assert(simulatedProfile.level == 1, "Level added by migration")

	print("✓ ProfileStore with validation and migration passes")
end

local function testEncodeDecode()
	print("Testing encode/decode with ProfileStore data...")

	local playerData = {
		version = "3",
		currency = { coins = 250, gems = 10 },
		items = {
			{ id = "axe", count = 1 },
			{ id = "pickaxe", count = 2 },
		},
		level = 5,
	}

	-- Validate
	local okV, errV = PlayerV3.validate(playerData, "/data")
	assert(okV, "Player data should be valid: " .. tostring(errV))

	-- Encode to JSON
	local okE, encoded = Serde.encode(PlayerV3, playerData, JSON)
	assert(okE, "Encode should succeed: " .. tostring(encoded))
	assert(type(encoded) == "string", "Encoded should be string")

	-- Decode back
	local okD, decoded = Serde.decode(PlayerV3, encoded, JSON)
	assert(okD, "Decode should succeed: " .. tostring(decoded))

	-- Verify round-trip
	assert(decoded.version == "3", "Version preserved")
	assert(decoded.currency.coins == 250, "Coins preserved")
	assert(decoded.currency.gems == 10, "Gems preserved")
	assert(#decoded.items == 2, "Items count preserved")
	assert(decoded.level == 5, "Level preserved")

	print("✓ Encode/decode passes")
end

local function testReconcilePattern()
	print("Testing ProfileStore reconcile pattern...")

	local template = {
		version = "3",
		currency = { coins = 100, gems = 0 },
		items = {},
		level = 1,
	}

	-- Simulate old profile data missing new fields
	local oldProfile = {
		version = "3",
		currency = { coins = 500, gems = 50 },
		items = { { id = "sword", count = 1 } },
		-- missing 'level' field
	}

	-- Reconcile: fill missing keys from template
	for key, value in pairs(template) do
		if oldProfile[key] == nil then
			oldProfile[key] = value
		end
	end

	-- Validate after reconcile
	local ok, err = PlayerV3.validate(oldProfile, "/reconciled")
	assert(ok, "Reconciled profile should be valid: " .. tostring(err))
	assert(oldProfile.level == 1, "Should have default level")

	print("✓ Reconcile pattern passes")
end

local function testChainedMigrations()
	print("Testing chained migrations with validation...")

	local v1Data = {
		version = "1",
		coins = 1000,
		items = { "helmet", "boots" },
	}

	-- V1 -> V2
	local okM1, v2Data = Migrate.apply(migrationPlan, v1Data, "1", "2")
	assert(okM1, "V1->V2 migration should succeed: " .. tostring(v2Data))

	local okV2, errV2 = PlayerV2.validate(v2Data, "/v2")
	assert(okV2, "V2 data should be valid: " .. tostring(errV2))

	-- V2 -> V3
	local okM2, v3Data = Migrate.apply(migrationPlan, v2Data, "2", "3")
	assert(okM2, "V2->V3 migration should succeed: " .. tostring(v3Data))

	local okV3, errV3 = PlayerV3.validate(v3Data, "/v3")
	assert(okV3, "V3 data should be valid: " .. tostring(errV3))

	-- Verify final state
	assert(v3Data.currency.coins == 1000, "Coins preserved through chain")
	assert(v3Data.level == 1, "Level added")

	print("✓ Chained migrations pass")
end

local function testFullProfileStoreWorkflow()
	print("Testing full ProfileStore + datum-serde workflow...")

	-- Step 1: Create ProfileStore with V3 template
	local template = {
		version = "3",
		currency = { coins = 100, gems = 0 },
		items = {},
		level = 1,
	}
	local store = ProfileStore.New("FullWorkflow_" .. tostring(os.time()), template)

	-- Step 2: Simulate old player data (V2 format) that was saved
	local savedV2Data = {
		version = "2",
		coins = 500,
		gems = 25,
		items = {
			{ id = "sword", count = 1 },
			{ id = "shield", count = 1 },
		},
	}

	-- Step 3: Validate saved data is valid V2
	local okSaved, errSaved = PlayerV2.validate(savedV2Data, "/saved")
	assert(okSaved, "Saved V2 data should be valid: " .. tostring(errSaved))

	-- Step 4: Migrate to V3 using datum-serde
	local okMigrate, migratedData = Migrate.apply(migrationPlan, savedV2Data, "2", "3")
	assert(okMigrate, "Migration V2->V3 should succeed: " .. tostring(migratedData))

	-- Step 5: Validate migrated data
	local okMigrated, errMigrated = PlayerV3.validate(migratedData, "/migrated")
	assert(okMigrated, "Migrated data should be valid V3: " .. tostring(errMigrated))

	-- Step 6: Simulate updating profile.Data (what happens in real ProfileStore usage)
	local profileData = table.clone(template)
	for k, v in pairs(migratedData) do
		profileData[k] = v
	end

	-- Step 7: Encode profile data to JSON (for storage)
	local okEncode, encoded = Serde.encode(PlayerV3, profileData, JSON)
	assert(okEncode, "Encode should succeed: " .. tostring(encoded))
	assert(type(encoded) == "string", "Encoded should be string")

	-- Step 8: Decode back from JSON
	local okDecode, decoded = Serde.decode(PlayerV3, encoded, JSON)
	assert(okDecode, "Decode should succeed: " .. tostring(decoded))

	-- Step 9: Verify round-trip integrity
	assert(decoded.version == "3", "Version preserved")
	assert(decoded.currency.coins == 500, "Coins preserved")
	assert(decoded.currency.gems == 25, "Gems preserved")
	assert(#decoded.items == 2, "Items preserved")
	assert(decoded.level == 1, "Level preserved")

	print("✓ Full ProfileStore workflow passes")
end

-- Run all tests
local function runTests()
	print("\n=== ProfileStore Integration Tests ===\n")
	testSchemaValidation()
	testDataMigration()
	testProfileStoreWithValidation()
	testEncodeDecode()
	testReconcilePattern()
	testChainedMigrations()
	testFullProfileStoreWorkflow()
	print("\n=== All ProfileStore Integration Tests Passed ===\n")
end

return runTests
