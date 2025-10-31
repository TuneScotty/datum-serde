--!strict

--[[
Purpose: Unit tests for migration system with DAG validation and determinism.
Arguments: None
Time complexity: O(V + E) per test where V = versions, E = edges
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Migrate = require(ReplicatedStorage.Packages.DatumSerde.migrate)

local function assert(condition: boolean, message: string?)
	if not condition then
		error(message or "Assertion failed", 2)
	end
end

local function testSimpleMigration()
	print("Testing simple migration...")

	local plan = Migrate.plan()
	plan:add("1", "2", function(v)
		if type(v) ~= "table" or v.version ~= "1" then
			return false, "bad v1"
		end
		local result = table.clone(v)
		result.version = "2"
		result.newField = "added"
		return true, result
	end)

	local v1 = { version = "1", data = "test" }
	local ok, v2 = Migrate.apply(plan, v1, "1", "2")
	assert(ok, "migration should succeed")
	assert(v2.version == "2", "version should update")
	assert(v2.newField == "added", "new field should be added")
	assert(v2.data == "test", "existing data should be preserved")

	print("✓ Simple migration passes")
end

local function testChainedMigration()
	print("Testing chained migration...")

	local plan = Migrate.plan()

	plan:add("1", "2", function(v)
		local result = table.clone(v)
		result.version = "2"
		result.step1 = true
		return true, result
	end)

	plan:add("2", "3", function(v)
		local result = table.clone(v)
		result.version = "3"
		result.step2 = true
		return true, result
	end)

	plan:add("3", "4", function(v)
		local result = table.clone(v)
		result.version = "4"
		result.step3 = true
		return true, result
	end)

	local v1 = { version = "1" }
	local ok, v4 = Migrate.apply(plan, v1, "1", "4")
	assert(ok, "chained migration should succeed")
	assert(v4.version == "4", "should reach version 4")
	assert(v4.step1 == true, "should have step1 marker")
	assert(v4.step2 == true, "should have step2 marker")
	assert(v4.step3 == true, "should have step3 marker")

	print("✓ Chained migration passes")
end

local function testBranchedMigration()
	print("Testing branched migration paths...")

	local plan = Migrate.plan()

	-- Create branched path: 1 -> 2, 1 -> 3, 2 -> 4, 3 -> 4
	plan:add("1", "2", function(v)
		local result = table.clone(v)
		result.version = "2"
		result.path = "1->2"
		return true, result
	end)

	plan:add("1", "3", function(v)
		local result = table.clone(v)
		result.version = "3"
		result.path = "1->3"
		return true, result
	end)

	plan:add("2", "4", function(v)
		local result = table.clone(v)
		result.version = "4"
		result.path = v.path .. "->4"
		return true, result
	end)

	plan:add("3", "4", function(v)
		local result = table.clone(v)
		result.version = "4"
		result.path = v.path .. "->4"
		return true, result
	end)

	-- BFS should find shortest path (1 -> 2 -> 4 or 1 -> 3 -> 4, both length 2)
	local v1 = { version = "1" }
	local ok, v4 = Migrate.apply(plan, v1, "1", "4")
	assert(ok, "branched migration should succeed")
	assert(v4.version == "4", "should reach version 4")
	-- Path could be either 1->2->4 or 1->3->4
	local isValidPath = v4.path == "1->2->4" or v4.path == "1->3->4"
	assert(isValidPath, "should take valid path")

	print("✓ Branched migration passes")
end

local function testNoPathError()
	print("Testing no path error...")

	local plan = Migrate.plan()
	plan:add("1", "2", function(v)
		return true, v
	end)

	local v1 = { version = "1" }
	local ok, err = Migrate.apply(plan, v1, "1", "999")
	assert(not ok and err, "should fail when no path exists")
	assert(string.find(err :: string, "no path"), "error should mention no path")

	print("✓ No path error passes")
end

local function testCycleDetection()
	print("Testing cycle detection...")

	local plan = Migrate.plan()

	-- Create cycle: 1 -> 2 -> 3 -> 1
	plan:add("1", "2", function(v)
		return true, v
	end)
	plan:add("2", "3", function(v)
		return true, v
	end)
	plan:add("3", "1", function(v)
		return true, v
	end)

	local v1 = { version = "1" }
	local ok, err = Migrate.apply(plan, v1, "1", "2")
	assert(not ok and err, "should detect cycle")
	assert(string.find(err :: string, "cycle"), "error should mention cycle")

	print("✓ Cycle detection passes")
end

local function testSameVersionNoOp()
	print("Testing same version no-op...")

	local plan = Migrate.plan()
	plan:add("1", "2", function(v)
		return true, v
	end)

	local v1 = { version = "1", data = "test" }
	local ok, result = Migrate.apply(plan, v1, "1", "1")
	assert(ok, "same version should succeed")
	assert(result.version == "1", "version should not change")
	assert(result.data == "test", "data should not change")

	print("✓ Same version no-op passes")
end

local function testMigrationFailure()
	print("Testing migration failure propagation...")

	local plan = Migrate.plan()
	plan:add("1", "2", function(v)
		return false, "intentional failure"
	end)

	local v1 = { version = "1" }
	local ok, err = Migrate.apply(plan, v1, "1", "2")
	assert(not ok and err, "should propagate failure")
	assert(string.find(err :: string, "intentional failure"), "error should contain failure message")

	print("✓ Migration failure passes")
end

local function testPlanLocking()
	print("Testing plan locking...")

	local plan = Migrate.plan()
	plan:add("1", "2", function(v)
		return true, v
	end)

	plan:lock()
	assert(plan.locked == true, "plan should be locked")

	local success = pcall(function()
		plan:add("2", "3", function(v)
			return true, v
		end)
	end)

	assert(not success, "should not allow adding to locked plan")

	print("✓ Plan locking passes")
end

-- Run all tests
local function runTests()
	print("\n=== Migration Tests ===\n")
	testSimpleMigration()
	testChainedMigration()
	testBranchedMigration()
	testNoPathError()
	testCycleDetection()
	testSameVersionNoOp()
	testMigrationFailure()
	testPlanLocking()
	print("\n=== All Migration Tests Passed ===\n")
end

return runTests
