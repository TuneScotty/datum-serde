--!strict

--[[
Purpose: Deterministic JSON encoder/decoder with safety checks for NaN, Inf, cycles, metatables.
Arguments: None (module exports encode/decode functions)
Time complexity: O(n) where n = structure size
]]

local HttpService = game:GetService("HttpService")

export type Codec = {
	encode: (value: any, opts: EncodeOptions?) -> (boolean, string | string),
	decode: (payload: string) -> (boolean, any | string),
}

export type EncodeOptions = {
	maxDepth: number?,
	maxArrayLength: number?,
	maxBytes: number?,
}

local DEFAULT_MAX_DEPTH = 100
local DEFAULT_MAX_ARRAY_LENGTH = 100000
local DEFAULT_MAX_BYTES = 10 * 1024 * 1024 -- 10MB

local JSON: Codec = {}

--[[
Purpose: Checks for cycles and metatables in a table structure.
Arguments: tbl - table to check, visited - set of visited tables, depth - current depth, maxDepth - maximum depth allowed
Time complexity: O(n) where n = number of nodes in tree
]]
local function validateTree(
	value: any,
	visited: { [any]: boolean },
	depth: number,
	maxDepth: number,
	maxArrayLength: number
): (boolean, string?)
	if depth > maxDepth then
		return false, "E:Safety: max depth exceeded"
	end

	local valueType = type(value)
	if valueType == "number" then
		if value ~= value then
			return false, "E:Codec: NaN not allowed"
		end
		if value == math.huge or value == -math.huge then
			return false, "E:Codec: Infinity not allowed"
		end
		return true
	end

	if valueType ~= "table" then
		return true
	end

	if getmetatable(value) ~= nil then
		return false, "E:Safety: metatables not allowed"
	end

	if visited[value] then
		return false, "E:Safety: cyclic reference detected"
	end

	if #value > maxArrayLength then
		return false, "E:Codec: array length exceeds max"
	end

	visited[value] = true

	for k, v in pairs(value) do
		local okK, errK = validateTree(k, visited, depth + 1, maxDepth, maxArrayLength)
		if not okK then
			return false, errK
		end

		local okV, errV = validateTree(v, visited, depth + 1, maxDepth, maxArrayLength)
		if not okV then
			return false, errV
		end
	end

	return true
end

--[[
Purpose: Encodes a Lua value to JSON string with safety checks.
Arguments: value - value to encode, opts - optional encoding options (maxDepth, maxArrayLength, maxBytes)
Time complexity: O(n) where n = structure size
]]
function JSON.encode(value: any, opts: EncodeOptions?): (boolean, string | string)
	local options = opts or {}
	local maxDepth = options.maxDepth or DEFAULT_MAX_DEPTH
	local maxArrayLength = options.maxArrayLength or DEFAULT_MAX_ARRAY_LENGTH
	local maxBytes = options.maxBytes or DEFAULT_MAX_BYTES

	local visited = {}
	local okValidate, errValidate = validateTree(value, visited, 0, maxDepth, maxArrayLength)
	if not okValidate then
		return false, errValidate :: string
	end

	-- Encode
	local success, result = pcall(function()
		return HttpService:JSONEncode(value)
	end)

	if not success then
		return false, "E:Codec: JSON encode failed: " .. tostring(result)
	end

	-- Check byte size
	if #result > maxBytes then
		return false, "E:Codec: output exceeds max bytes"
	end

	return true, result
end

--[[
Purpose: Decodes a JSON string to Lua value.
Arguments: payload - JSON string to decode
Time complexity: O(n) where n = payload length
]]
function JSON.decode(payload: string): (boolean, any | string)
	if type(payload) ~= "string" then
		return false, "E:Codec: expected string payload, got " .. typeof(payload)
	end

	local success, result = pcall(function()
		return HttpService:JSONDecode(payload)
	end)

	if not success then
		return false, "E:Codec: JSON decode failed: " .. tostring(result)
	end

	return true, result
end

return JSON
