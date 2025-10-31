--!strict

--[[
Purpose: DataStore adapter with budget-aware retry logic and exponential backoff.
Arguments: None (module exports read/write functions)
Time complexity: O(1) per operation + retry overhead
]]

local DataStoreService = game:GetService("DataStoreService")

export type DataStoreAdapter = {
	read: (key: string, storeName: string?, scope: string?) -> (boolean, string | string),
	write: (key: string, payload: string, storeName: string?, scope: string?) -> (boolean, string?),
	setMaxRetries: (retries: number) -> (),
	setBaseDelay: (delaySeconds: number) -> (),
}

local DEFAULT_STORE_NAME = "PlayerData"
local DEFAULT_SCOPE = ""
local DEFAULT_MAX_RETRIES = 3
local DEFAULT_BASE_DELAY = 1.0

local maxRetries = DEFAULT_MAX_RETRIES
local baseDelay = DEFAULT_BASE_DELAY

local DataStore: DataStoreAdapter = {} :: any

--[[
Purpose: Sets maximum retry attempts for operations.
Arguments: retries - number of retry attempts
Time complexity: O(1)
]]
function DataStore.setMaxRetries(retries: number)
	maxRetries = retries
end

--[[
Purpose: Sets base delay for exponential backoff.
Arguments: delaySeconds - base delay in seconds
Time complexity: O(1)
]]
function DataStore.setBaseDelay(delaySeconds: number)
	baseDelay = delaySeconds
end

--[[
Purpose: Calculates exponential backoff with jitter.
Arguments: attempt - current retry attempt number
Time complexity: O(1)
]]
local function calculateBackoff(attempt: number): number
	local exponentialDelay = baseDelay * (2 ^ (attempt - 1))
	local jitter = math.random() * 0.3 * exponentialDelay -- 0-30% jitter
	return exponentialDelay + jitter
end

--[[
Purpose: Reads data from DataStore with retry logic.
Arguments: key - DataStore key, storeName - optional store name, scope - optional scope
Time complexity: O(1) + retry overhead
]]
function DataStore.read(key: string, storeName: string?, scope: string?): (boolean, string | string)
	local store = DataStoreService:GetDataStore(storeName or DEFAULT_STORE_NAME, scope or DEFAULT_SCOPE)

	for attempt = 1, maxRetries do
		local success, result = pcall(function()
			return store:GetAsync(key)
		end)

		if success then
			if result == nil then
				return false, "E:DataStore: key not found: " .. key
			end
			if type(result) ~= "string" then
				return false, "E:DataStore: expected string payload, got " .. typeof(result)
			end
			return true, result
		else
			-- Check if we should retry
			local errorMsg = tostring(result)
			if attempt < maxRetries then
				-- Budget/throttle errors are retryable
				if string.find(errorMsg, "Budget") or string.find(errorMsg, "throttle") then
					task.wait(calculateBackoff(attempt))
					continue
				end
			end

			return false, "E:DataStore: read failed after " .. attempt .. " attempts: " .. errorMsg
		end
	end

	return false, "E:DataStore: read failed after " .. maxRetries .. " attempts"
end

--[[
Purpose: Writes data to DataStore with retry logic.
Arguments: key - DataStore key, payload - string payload to write, storeName - optional store name, scope - optional scope
Time complexity: O(1) + retry overhead
]]
function DataStore.write(key: string, payload: string, storeName: string?, scope: string?): (boolean, string?)
	if type(payload) ~= "string" then
		return false, "E:DataStore: expected string payload, got " .. typeof(payload)
	end

	local store = DataStoreService:GetDataStore(storeName or DEFAULT_STORE_NAME, scope or DEFAULT_SCOPE)

	for attempt = 1, maxRetries do
		local success, result = pcall(function()
			return store:SetAsync(key, payload)
		end)

		if success then
			return true, nil
		else
			local errorMsg = tostring(result)
			if attempt < maxRetries then
				if string.find(errorMsg, "Budget") or string.find(errorMsg, "throttle") then
					task.wait(calculateBackoff(attempt))
					continue
				end
			end

			return false, "E:DataStore: write failed after " .. attempt .. " attempts: " .. errorMsg
		end
	end

	return false, "E:DataStore: write failed after " .. maxRetries .. " attempts"
end

return DataStore
