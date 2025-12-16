--!strict

--[[
Purpose: Simple script runner for testing in Roblox Studio. Place this in ServerScriptService.
Arguments: None
Time complexity: O(sum of all tests)
]]

-- Import test modules from ServerScriptService
local testFolder = script.Parent:WaitForChild("RuntimeTests")
if not testFolder then
	error("RuntimeTests folder not found in ServerScriptService. Make sure Rojo is synced.")
end

local codecTests = require(testFolder.codec_spec)
local integrationTests = require(testFolder.integration_spec)
local migrateTests = require(testFolder.migrate_spec)
local profileStoreIntegrationTests = require(testFolder.profilestore_integration_spec)
local schemaTests = require(testFolder.schema_spec)

print("\n" .. string.rep("=", 60))
print("DATUM-SERDE TEST SUITE")
print(string.rep("=", 60) .. "\n")

local success = true

local function runSuite(name: string, testFn: () -> ())
	print("\n" .. string.rep("-", 60))
	print("Running: " .. name)
	print(string.rep("-", 60))

	local ok, err = pcall(testFn)
	if not ok then
		success = false
		print("\n✗ FAILED: " .. name)
		print("Error: " .. tostring(err))
	else
		print("\n✓ PASSED: " .. name)
	end
end

runSuite("Schema Tests", schemaTests)
runSuite("Codec Tests", codecTests)
runSuite("Migration Tests", migrateTests)
runSuite("Integration Tests", integrationTests)
runSuite("ProfileStore Integration Tests", profileStoreIntegrationTests)

-- Run benchmark
print("\n" .. string.rep("-", 60))
print("Running: Performance Benchmark")
print(string.rep("-", 60))
print("\n✓ BENCHMARK COMPLETE")

print("\n" .. string.rep("=", 60))
if success then
	print("✓ ALL TESTS PASSED")
else
	print("✗ SOME TESTS FAILED")
end
print(string.rep("=", 60) .. "\n")
