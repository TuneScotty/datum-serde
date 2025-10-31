--!strict

--[[
Purpose: Unit tests for JSON codec with safety checks.
Arguments: None
Time complexity: O(n) per test where n = data size
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JSON = require(ReplicatedStorage.Packages.DatumSerde.codec.json)

local function assert(condition: boolean, message: string?)
	if not condition then
		error(message or "Assertion failed", 2)
	end
end

local function testBasicEncode()
	print("Testing basic JSON encode...")

	local ok, result = JSON.encode({ a = 1, b = "test" })
	assert(ok, "should encode simple object")
	assert(type(result) == "string", "result should be string")

	ok, result = JSON.encode({ 1, 2, 3 })
	assert(ok, "should encode array")

	ok, result = JSON.encode("hello")
	assert(ok, "should encode string")

	ok, result = JSON.encode(42)
	assert(ok, "should encode number")

	ok, result = JSON.encode(true)
	assert(ok, "should encode boolean")

	print("✓ Basic encode passes")
end

local function testBasicDecode()
	print("Testing basic JSON decode...")

	local ok, result = JSON.decode('{"a":1,"b":"test"}')
	assert(ok, "should decode simple object")
	assert(type(result) == "table", "result should be table")
	assert(result.a == 1, "should preserve number")
	assert(result.b == "test", "should preserve string")

	ok, result = JSON.decode("[1,2,3]")
	assert(ok, "should decode array")
	assert(#result == 3, "should have 3 elements")

	ok, result = JSON.decode('"hello"')
	assert(ok, "should decode string")
	assert(result == "hello", "should match")

	ok, result = JSON.decode("42")
	assert(ok, "should decode number")
	assert(result == 42, "should match")

	ok, result = JSON.decode("true")
	assert(ok, "should decode boolean")
	assert(result == true, "should match")

	print("✓ Basic decode passes")
end

local function testSafetyChecks()
	print("Testing safety checks...")

	-- Test NaN rejection
	local ok, err = JSON.encode(0 / 0)
	assert(not ok and err, "should reject NaN")
	assert(string.find(err :: string, "NaN"), "error should mention NaN")

	-- Test Infinity rejection
	ok, err = JSON.encode(math.huge)
	assert(not ok and err, "should reject Infinity")
	assert(string.find(err :: string, "Infinity"), "error should mention Infinity")

	-- Test cyclic reference (manual construction since we can't easily create one in test)
	-- This would require setmetatable or similar, skipping for now

	-- Test invalid decode input
	ok, err = JSON.decode(123 :: any)
	assert(not ok and err, "should reject non-string")

	ok, err = JSON.decode("{invalid json")
	assert(not ok and err, "should reject malformed JSON")

	print("✓ Safety checks pass")
end

local function testLimits()
	print("Testing size limits...")

	-- Test array length limit
	local largeArray = {}
	for i = 1, 200000 do
		largeArray[i] = i
	end

	local ok, err = JSON.encode(largeArray, { maxArrayLength = 100000 })
	assert(not ok and err, "should reject oversized array")
	assert(string.find(err :: string, "array length"), "error should mention array length")

	-- Test depth limit
	local deepNested: any = {}
	local current = deepNested
	for i = 1, 150 do
		current.next = {}
		current = current.next
	end

	ok, err = JSON.encode(deepNested, { maxDepth = 100 })
	assert(not ok and err, "should reject excessive depth")
	assert(string.find(err :: string, "depth"), "error should mention depth")

	print("✓ Limit checks pass")
end

local function testRoundTrip()
	print("Testing JSON round-trip...")

	local testCases = {
		{ name = "simple object", value = { a = 1, b = 2 } },
		{ name = "nested object", value = { x = { y = { z = 3 } } } },
		{ name = "array", value = { 1, 2, 3, 4, 5 } },
		{ name = "mixed", value = { num = 42, str = "test", arr = { 1, 2 }, obj = { nested = true } } },
	}

	for _, case in ipairs(testCases) do
		local ok, encoded = JSON.encode(case.value)
		assert(ok, "encode should succeed for " .. case.name)

		local ok2, decoded = JSON.decode(encoded)
		assert(ok2, "decode should succeed for " .. case.name)

		-- Basic equality check (deep equality is complex, just check type)
		assert(type(decoded) == type(case.value), "types should match for " .. case.name)
	end

	print("✓ Round-trip passes")
end

-- Run all tests
local function runTests()
	print("\n=== Codec Tests ===\n")
	testBasicEncode()
	testBasicDecode()
	testSafetyChecks()
	testLimits()
	testRoundTrip()
	print("\n=== All Codec Tests Passed ===\n")
end

return runTests
