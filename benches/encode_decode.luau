--!strict

--[[
Purpose: Benchmark for encode/decode operations to meet performance targets.
Arguments: None
Time complexity: O(n*m) where n = iterations, m = data size
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DatumSerde = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("DatumSerde")

local Schema = require(DatumSerde.schema)
local Serde = require(DatumSerde.serde)
local JSON = require(DatumSerde.codec.json)

local ITERATIONS = 10000
local TARGET_ENCODE_MS = 2.0
local TARGET_DECODE_MS = 3.0

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

local sampleData = {
	version = "1",
	userId = 123456,
	coins = 1000,
	inventory = { "sword", "shield", "potion", "armor", "helmet" },
	settings = {
		music = true,
		sfx = false,
	},
}

print("\n=== Encode/Decode Benchmark ===\n")
print("Iterations:", ITERATIONS)
print("Target encode avg:", TARGET_ENCODE_MS, "ms")
print("Target decode avg:", TARGET_DECODE_MS, "ms")
print()

-- Warmup
for _ = 1, 100 do
	Serde.encode(playerSchema, sampleData, JSON)
end

-- Benchmark encode
print("Benchmarking encode...")
local encodeStart = os.clock()
local encodedPayload
for i = 1, ITERATIONS do
	local ok, result = Serde.encode(playerSchema, sampleData, JSON)
	if not ok then
		error("Encode failed: " .. tostring(result))
	end
	encodedPayload = result
end
local encodeEnd = os.clock()
local encodeTotalMs = (encodeEnd - encodeStart) * 1000
local encodeAvgMs = encodeTotalMs / ITERATIONS

print(string.format("  Total: %.2f ms", encodeTotalMs))
print(string.format("  Average: %.4f ms", encodeAvgMs))
print(
	string.format(
		"  Target: %.2f ms - %s",
		TARGET_ENCODE_MS,
		encodeAvgMs < TARGET_ENCODE_MS and "✓ PASS" or "✗ FAIL"
	)
)

-- Benchmark decode
print("\nBenchmarking decode...")
local decodeStart = os.clock()
for i = 1, ITERATIONS do
	local ok, result = Serde.decode(playerSchema, encodedPayload, JSON)
	if not ok then
		error("Decode failed: " .. tostring(result))
	end
end
local decodeEnd = os.clock()
local decodeTotalMs = (decodeEnd - decodeStart) * 1000
local decodeAvgMs = decodeTotalMs / ITERATIONS

print(string.format("  Total: %.2f ms", decodeTotalMs))
print(string.format("  Average: %.4f ms", decodeAvgMs))
print(
	string.format(
		"  Target: %.2f ms - %s",
		TARGET_DECODE_MS,
		decodeAvgMs < TARGET_DECODE_MS and "✓ PASS" or "✗ FAIL"
	)
)

print("\n=== Benchmark Complete ===\n")

-- Export results for CI
local results = {
	iterations = ITERATIONS,
	encode_avg_ms = encodeAvgMs,
	decode_avg_ms = decodeAvgMs,
	encode_target_ms = TARGET_ENCODE_MS,
	decode_target_ms = TARGET_DECODE_MS,
	encode_pass = encodeAvgMs < TARGET_ENCODE_MS,
	decode_pass = decodeAvgMs < TARGET_DECODE_MS,
}

return results
