--!strict

--[[
Purpose: Unit tests for schema builders and validation.
Arguments: None
Time complexity: O(n) per test where n = test data size
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schema = require(ReplicatedStorage.Packages.DatumSerde.schema)

local function assert(condition: boolean, message: string?)
	if not condition then
		error(message or "Assertion failed", 2)
	end
end

local function testPrimitives()
	print("Testing primitive schemas...")

	-- nil
	local nilSchema = Schema.Nil()
	local ok, err = nilSchema.validate(nil, "/test")
	assert(ok, "nil should validate nil")
	ok, err = nilSchema.validate(5, "/test")
	assert(not ok and err, "nil should reject number")

	-- boolean
	local boolSchema = Schema.boolean()
	ok, err = boolSchema.validate(true, "/test")
	assert(ok, "boolean should validate true")
	ok, err = boolSchema.validate(false, "/test")
	assert(ok, "boolean should validate false")
	ok, err = boolSchema.validate(1, "/test")
	assert(not ok and err, "boolean should reject number")

	-- number
	local numSchema = Schema.number()
	ok, err = numSchema.validate(42, "/test")
	assert(ok, "number should validate integer")
	ok, err = numSchema.validate(3.14, "/test")
	assert(ok, "number should validate float")
	ok, err = numSchema.validate(0 / 0, "/test") -- NaN
	assert(not ok and err, "number should reject NaN")
	ok, err = numSchema.validate(math.huge, "/test")
	assert(not ok and err, "number should reject Infinity")
	ok, err = numSchema.validate("42", "/test")
	assert(not ok and err, "number should reject string")

	-- string
	local strSchema = Schema.string()
	ok, err = strSchema.validate("hello", "/test")
	assert(ok, "string should validate string")
	ok, err = strSchema.validate("", "/test")
	assert(ok, "string should validate empty string")
	ok, err = strSchema.validate(123, "/test")
	assert(not ok and err, "string should reject number")

	print("✓ Primitive schemas pass")
end

local function testLiteral()
	print("Testing literal schema...")

	local lit = Schema.literal("v1")
	local ok, err = lit.validate("v1", "/test")
	assert(ok, "literal should validate exact match")
	ok, err = lit.validate("v2", "/test")
	assert(not ok and err, "literal should reject different value")

	local numLit = Schema.literal(42)
	ok, err = numLit.validate(42, "/test")
	assert(ok, "literal should validate number")
	ok, err = numLit.validate(43, "/test")
	assert(not ok and err, "literal should reject different number")

	print("✓ Literal schema passes")
end

local function testArray()
	print("Testing array schema...")

	local arrSchema = Schema.array(Schema.number())
	local ok, err = arrSchema.validate({ 1, 2, 3 }, "/test")
	assert(ok, "array should validate number array")

	ok, err = arrSchema.validate({ 1, "2", 3 }, "/test")
	assert(not ok and err, "array should reject mixed types")
	assert(string.find(err :: string, "/test/1"), "error should contain path")

	ok, err = arrSchema.validate({}, "/test")
	assert(ok, "array should validate empty array")

	ok, err = arrSchema.validate("not array", "/test")
	assert(not ok and err, "array should reject non-table")

	print("✓ Array schema passes")
end

local function testMap()
	print("Testing map schema...")

	local mapSchema = Schema.map(Schema.string(), Schema.number())
	local ok, err = mapSchema.validate({ a = 1, b = 2 }, "/test")
	assert(ok, "map should validate string->number map")

	ok, err = mapSchema.validate({ a = 1, b = "invalid" }, "/test")
	assert(not ok and err, "map should reject invalid value type")

	ok, err = mapSchema.validate({}, "/test")
	assert(ok, "map should validate empty map")

	print("✓ Map schema passes")
end

local function testObject()
	print("Testing object schema...")

	local objSchema = Schema.object({
		name = Schema.string(),
		age = Schema.number(),
		active = Schema.boolean(),
	})

	local ok, err = objSchema.validate({
		name = "Alice",
		age = 30,
		active = true,
	}, "/test")
	assert(ok, "object should validate valid object")

	ok, err = objSchema.validate({
		name = "Bob",
		age = "invalid",
		active = true,
	}, "/test")
	assert(not ok and err, "object should reject invalid field")
	assert(string.find(err :: string, "/test/age"), "error should contain field path")

	ok, err = objSchema.validate({
		name = "Charlie",
		active = true,
	}, "/test")
	assert(not ok and err, "object should reject missing field")

	print("✓ Object schema passes")
end

local function testUnion()
	print("Testing union schema...")

	local unionSchema = Schema.union(Schema.string(), Schema.number())
	local ok, err = unionSchema.validate("hello", "/test")
	assert(ok, "union should validate first schema")

	ok, err = unionSchema.validate(42, "/test")
	assert(ok, "union should validate second schema")

	ok, err = unionSchema.validate(true, "/test")
	assert(not ok and err, "union should reject non-matching type")

	print("✓ Union schema passes")
end

local function testOptional()
	print("Testing optional schema...")

	local optSchema = Schema.optional(Schema.number())
	local ok, err = optSchema.validate(nil, "/test")
	assert(ok, "optional should validate nil")

	ok, err = optSchema.validate(42, "/test")
	assert(ok, "optional should validate value")

	ok, err = optSchema.validate("invalid", "/test")
	assert(not ok and err, "optional should reject invalid type")

	print("✓ Optional schema passes")
end

local function testRefine()
	print("Testing refine schema...")

	local positiveNum = Schema.refine(Schema.number(), function(n)
		return n > 0
	end, "must be positive")

	local ok, err = positiveNum.validate(5, "/test")
	assert(ok, "refine should validate passing predicate")

	ok, err = positiveNum.validate(-5, "/test")
	assert(not ok and err, "refine should reject failing predicate")
	assert(string.find(err :: string, "positive"), "error should contain custom message")

	ok, err = positiveNum.validate("invalid", "/test")
	assert(not ok and err, "refine should reject base schema failure")

	print("✓ Refine schema passes")
end

local function testRoundTrip()
	print("Testing encode/decode round-trip...")

	local schema = Schema.object({
		id = Schema.number(),
		name = Schema.string(),
		tags = Schema.array(Schema.string()),
	})

	local original = {
		id = 123,
		name = "Test",
		tags = { "a", "b", "c" },
	}

	local encoded = schema.encode(original)
	local ok, decoded = schema.decode(encoded, "/test")
	assert(ok, "decode should succeed")
	assert(decoded.id == original.id, "round-trip should preserve id")
	assert(decoded.name == original.name, "round-trip should preserve name")
	assert(#decoded.tags == 3, "round-trip should preserve array length")

	print("✓ Round-trip passes")
end

-- Run all tests
local function runTests()
	print("\n=== Schema Tests ===\n")
	testPrimitives()
	testLiteral()
	testArray()
	testMap()
	testObject()
	testUnion()
	testOptional()
	testRefine()
	testRoundTrip()
	print("\n=== All Schema Tests Passed ===\n")
end

return runTests
