--!strict

--[[
Purpose: CLI test runner for datum-serde using Lune runtime.
Arguments: None
Time complexity: O(sum of all tests)
]]

local function loadTest(path: string): (() -> ()) | nil
	local success, result = pcall(function()
		return require(path)
	end)

	if not success then
		warn("Failed to load test " .. path .. ": " .. tostring(result))
		return nil
	end

	return result
end

local function runTest(name: string, testFn: () -> ()): boolean
	print("\n" .. string.rep("-", 60))
	print("Running: " .. name)
	print(string.rep("-", 60))

	local ok, err = pcall(testFn)

	if not ok then
		print("\n❌ FAILED: " .. name)
		print("Error: " .. tostring(err))
		return false
	end

	print("\n✅ PASSED: " .. name)
	return true
end

local function main()
	print("\n" .. string.rep("=", 60))
	print("DATUM-SERDE TEST SUITE (Lune v0.10.4)")
	print(string.rep("=", 60) .. "\n")

	local allPassed = true

	-- Load tests from tests directory
	local schemaTests = loadTest("../tests/schema.spec.luau")
	local codecTests = loadTest("../tests/codec.spec.luau")
	local migrateTests = loadTest("../tests/migrate.spec.luau")
	local integrationTests = loadTest("../tests/integration.spec.luau")
	local profileStoreTests = loadTest("../tests/profilestore_integration.spec.luau")

	-- Run tests
	if schemaTests then
		allPassed = runTest("Schema Tests", schemaTests) and allPassed
	end
	if codecTests then
		allPassed = runTest("Codec Tests", codecTests) and allPassed
	end
	if migrateTests then
		allPassed = runTest("Migration Tests", migrateTests) and allPassed
	end
	if integrationTests then
		allPassed = runTest("Integration Tests", integrationTests) and allPassed
	end
	if profileStoreTests then
		allPassed = runTest("ProfileStore Integration Tests", profileStoreTests) and allPassed
	end

	-- Summary
	print("\n" .. string.rep("=", 60))
	if allPassed then
		print("✅ ALL TESTS PASSED")
		print(string.rep("=", 60) .. "\n")
		os.exit(0)
	else
		print("❌ SOME TESTS FAILED")
		print(string.rep("=", 60) .. "\n")
		os.exit(1)
	end
end

main()
