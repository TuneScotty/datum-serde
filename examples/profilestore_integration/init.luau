--!strict

--[[
Purpose: Production-ready example using ProfileStore + datum-serde for player data.
Arguments: None (example module)
Time complexity: O(n) where n = data size + migration cost
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DatumSerde = require(ReplicatedStorage.Packages.DatumSerde)
local ProfileStoreAdapter = require(ReplicatedStorage.Packages.DatumSerde.adapter.profilestore)

local Schema = DatumSerde.schema
local Serde = DatumSerde.serde
local JSON = DatumSerde.codec.json
local Migrate = DatumSerde.migrate

-- Schema definitions across versions
local PlayerV1 = Schema.object({
	version = Schema.literal("1"),
	coins = Schema.number(),
	inventory = Schema.array(Schema.string()),
	joinedAt = Schema.number(),
})

local PlayerV2 = Schema.object({
	version = Schema.literal("2"),
	coins = Schema.number(),
	gems = Schema.number(),
	inventory = Schema.array(
		Schema.object({
			id = Schema.string(),
			quantity = Schema.number(),
		})
	),
	joinedAt = Schema.number(),
	stats = Schema.object({
		kills = Schema.number(),
		deaths = Schema.number(),
		playtime = Schema.number(),
	}),
})

local PlayerV3 = Schema.object({
	version = Schema.literal("3"),
	currency = Schema.object({
		coins = Schema.number(),
		gems = Schema.number(),
		premium = Schema.number(),
	}),
	inventory = Schema.array(
		Schema.object({
			id = Schema.string(),
			quantity = Schema.number(),
			equipped = Schema.optional(Schema.boolean()),
		})
	),
	joinedAt = Schema.number(),
	stats = Schema.object({
		kills = Schema.number(),
		deaths = Schema.number(),
		playtime = Schema.number(),
		wins = Schema.number(),
	}),
	settings = Schema.object({
		music = Schema.boolean(),
		sfx = Schema.boolean(),
		notifications = Schema.boolean(),
	}),
})

-- Migration plan
local migrationPlan = Migrate.plan()

migrationPlan:add("1", "2", function(v1)
	if type(v1) ~= "table" or v1.version ~= "1" then
		return false, "invalid v1 data"
	end

	local newInventory = {}
	for _, itemId in ipairs(v1.inventory) do
		table.insert(newInventory, {
			id = itemId,
			quantity = 1,
		})
	end

	return true, {
		version = "2",
		coins = v1.coins,
		gems = 0,
		inventory = newInventory,
		joinedAt = v1.joinedAt,
		stats = {
			kills = 0,
			deaths = 0,
			playtime = 0,
		},
	}
end)

migrationPlan:add("2", "3", function(v2)
	if type(v2) ~= "table" or v2.version ~= "2" then
		return false, "invalid v2 data"
	end

	local newInventory = {}
	for _, item in ipairs(v2.inventory) do
		table.insert(newInventory, {
			id = item.id,
			quantity = item.quantity,
			equipped = false,
		})
	end

	return true, {
		version = "3",
		currency = {
			coins = v2.coins,
			gems = v2.gems,
			premium = 0,
		},
		inventory = newInventory,
		joinedAt = v2.joinedAt,
		stats = {
			kills = v2.stats.kills,
			deaths = v2.stats.deaths,
			playtime = v2.stats.playtime,
			wins = 0,
		},
		settings = {
			music = true,
			sfx = true,
			notifications = true,
		},
	}
end)

migrationPlan:lock()

-- Type export
export type PlayerData = {
	version: string,
	currency: {
		coins: number,
		gems: number,
		premium: number,
	},
	inventory: {
		{
			id: string,
			quantity: number,
			equipped: boolean?,
		}
	},
	joinedAt: number,
	stats: {
		kills: number,
		deaths: number,
		playtime: number,
		wins: number,
	},
	settings: {
		music: boolean,
		sfx: boolean,
		notifications: boolean,
	},
}

-- Default template for new players
local PROFILE_TEMPLATE: PlayerData = {
	version = "3",
	currency = {
		coins = 100,
		gems = 0,
		premium = 0,
	},
	inventory = {},
	joinedAt = os.time(),
	stats = {
		kills = 0,
		deaths = 0,
		playtime = 0,
		wins = 0,
	},
	settings = {
		music = true,
		sfx = true,
		notifications = true,
	},
}

-- Create ProfileStore manager
local profileManager = ProfileStoreAdapter.create({
	storeName = "PlayerData_v3",
	template = PROFILE_TEMPLATE,
})

local PlayerDataManager = {}

--[[
Purpose: Validates and migrates profile data to latest version.
Arguments: data - raw profile data
Time complexity: O(n) where n = data size + migration cost
]]
local function validateAndMigrate(data: any): (boolean, PlayerData | string)
	-- Try to decode as current version first (fast path)
	local ok, result = Serde.decode(PlayerV3, data, JSON)
	if ok then
		return true, result
	end

	-- Try older versions
	local schemas = { PlayerV2, PlayerV1 }
	local versions = { "2", "1" }

	for i, schema in ipairs(schemas) do
		ok, result = Serde.decode(schema, data, JSON)
		if ok then
			-- Migrate to latest
			local okM, migrated = Migrate.apply(migrationPlan, result, versions[i], "3")
			if not okM then
				return false, "Migration failed: " .. tostring(migrated)
			end
			return true, migrated
		end
	end

	return false, "Failed to decode as any known version"
end

--[[
Purpose: Starts a profile session for a player with validation and migration.
Arguments: player - Player instance
Time complexity: O(n) where n = profile data size + migration cost
]]
function PlayerDataManager.loadPlayer(player: Player): (boolean, any | string)
	local profile = profileManager.startSession(player)

	if profile == nil then
		return false, "Failed to start profile session"
	end

	-- Validate and migrate profile data
	local ok, result = validateAndMigrate(profile.Data)
	if not ok then
		profile:EndSession()
		return false, result
	end

	-- Update profile with validated/migrated data
	for k in pairs(profile.Data) do
		profile.Data[k] = nil
	end
	for k, v in pairs(result :: any) do
		profile.Data[k] = v
	end

	print(`✓ Loaded profile for {player.DisplayName} (version {profile.Data.version})`)
	return true, profile
end

--[[
Purpose: Gets active profile for a player.
Arguments: player - Player instance
Time complexity: O(1)
]]
function PlayerDataManager.getProfile(player: Player): any?
	return profileManager.getProfile(player)
end

--[[
Purpose: Unloads a player's profile.
Arguments: player - Player instance
Time complexity: O(1)
]]
function PlayerDataManager.unloadPlayer(player: Player)
	profileManager.endSession(player)
end

--[[
Purpose: Shuts down all profiles gracefully.
Arguments: None
Time complexity: O(n) where n = active profiles
]]
function PlayerDataManager.shutdown()
	print("Shutting down player data manager...")
	profileManager.endAllSessions()
	print("✓ All profiles saved and closed")
end

return PlayerDataManager
