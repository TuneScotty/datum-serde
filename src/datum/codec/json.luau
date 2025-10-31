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
local function checkSafety(tbl: any, visited: { [any]: boolean }, depth: number, maxDepth: number): (boolean, string?)
	if depth > maxDepth then
		return false, "E:Safety: max depth exceeded"
	end

	if type(tbl) ~= "table" then
		return true
	end

	if getmetatable(tbl) ~= nil then
		return false, "E:Safety: metatables not allowed"
	end

	if visited[tbl] then
		return false, "E:Safety: cyclic reference detected"
	end

	visited[tbl] = true

	for k, v in pairs(tbl) do
		local okK, errK = checkSafety(k, visited, depth + 1, maxDepth)
		if not okK then
			return false, errK
		end

		local okV, errV = checkSafety(v, visited, depth + 1, maxDepth)
		if not okV then
			return false, errV
		end
	end

	return true
end

--[[
Purpose: Validates that a value is JSON-safe (no NaN, Inf).
Arguments: value - value to validate
Time complexity: O(n) where n = structure size
]]
local function validateValue(value: any): (boolean, string?)
	if type(value) == "number" then
		if value ~= value then
			return false, "E:Codec: NaN not allowed"
		end
		if value == math.huge or value == -math.huge then
			return false, "E:Codec: Infinity not allowed"
		end
	elseif type(value) == "table" then
		for k, v in pairs(value) do
			local okK, errK = validateValue(k)
			if not okK then
				return false, errK
			end
			local okV, errV = validateValue(v)
			if not okV then
				return false, errV
			end
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

	-- Safety checks
	local visited = {}
	local okSafety, errSafety = checkSafety(value, visited, 0, maxDepth)
	if not okSafety then
		return false, errSafety :: string
	end

	-- Validate no NaN/Inf
	local okValid, errValid = validateValue(value)
	if not okValid then
		return false, errValid :: string
	end

	-- Check array length limits
	if type(value) == "table" then
		local function checkArrayLimits(tbl: any): (boolean, string?)
			if type(tbl) ~= "table" then
				return true
			end
			if #tbl > maxArrayLength then
				return false, "E:Codec: array length exceeds max"
			end
			for _, v in pairs(tbl) do
				local ok, err = checkArrayLimits(v)
				if not ok then
					return false, err
				end
			end
			return true
		end

		local okLen, errLen = checkArrayLimits(value)
		if not okLen then
			return false, errLen :: string
		end
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
