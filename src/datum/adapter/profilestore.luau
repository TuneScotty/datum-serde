--!strict

--[[
Purpose: ProfileStore adapter for datum-serde with session management and auto-save.
Arguments: None (module exports profile management functions)
Time complexity: O(1) per operation
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- ProfileStore will be loaded from DevPackages after wally install
local ProfileStore = require(ReplicatedStorage.Packages.DevPackages.ProfileStore)

export type ProfileStoreConfig<T> = {
	storeName: string,
	template: T,
	versionKey: string?,
}

export type ManagedProfile<T> = {
	profile: any,
	data: T,
	save: () -> (),
	release: () -> (),
}

local ProfileStoreAdapter = {}

--[[
Purpose: Creates a ProfileStore manager with datum-serde integration.
Arguments: config - configuration for store name and data template
Time complexity: O(1)
]]
function ProfileStoreAdapter.create<T>(config: ProfileStoreConfig<T>)
	local store = ProfileStore.New(config.storeName, config.template)
	local activeProfiles: { [Player]: any } = {}

	local manager = {}

	--[[
	Purpose: Starts a profile session for a player.
	Arguments: player - Player instance, key - optional custom key (defaults to UserId)
	Time complexity: O(1) + ProfileStore session start overhead
	]]
	function manager.startSession(player: Player, key: string?): any?
		local profileKey = key or tostring(player.UserId)

		local profile = store:StartSessionAsync(profileKey, {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})

		if profile == nil then
			return nil
		end

		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing keys from template

		-- Handle session end
		profile.OnSessionEnd:Connect(function()
			activeProfiles[player] = nil
			player:Kick("Profile session ended - Please rejoin")
		end)

		-- Check if player still in game
		if player.Parent ~= Players then
			profile:EndSession()
			return nil
		end

		activeProfiles[player] = profile
		return profile
	end

	--[[
	Purpose: Gets active profile for a player.
	Arguments: player - Player instance
	Time complexity: O(1)
	]]
	function manager.getProfile(player: Player): any?
		return activeProfiles[player]
	end

	--[[
	Purpose: Ends profile session for a player.
	Arguments: player - Player instance
	Time complexity: O(1)
	]]
	function manager.endSession(player: Player)
		local profile = activeProfiles[player]
		if profile then
			profile:EndSession()
			activeProfiles[player] = nil
		end
	end

	--[[
	Purpose: Ends all active profile sessions (for server shutdown).
	Arguments: None
	Time complexity: O(n) where n = number of active profiles
	]]
	function manager.endAllSessions()
		for _, profile in pairs(activeProfiles) do
			profile:EndSession()
		end
		activeProfiles = {}
	end

	--[[
	Purpose: Gets the raw ProfileStore instance for advanced usage.
	Arguments: None
	Time complexity: O(1)
	]]
	function manager.getRawStore()
		return store
	end

	return manager
end

--[[
Purpose: Helper to wrap profile data with validation and migration.
Arguments: profile - ProfileStore profile, schema - validation schema, migrate - optional migration function
Time complexity: O(n) where n = validation + migration cost
]]
function ProfileStoreAdapter.wrapWithValidation<T>(
	profile: any,
	validateAndMigrate: (data: any) -> (boolean, T | string)
): (boolean, ManagedProfile<T> | string)
	-- Validate and migrate profile data
	local ok, result = validateAndMigrate(profile.Data)
	if not ok then
		return false, result
	end

	-- Replace profile.Data with validated/migrated version
	for k in pairs(profile.Data) do
		profile.Data[k] = nil
	end
	for k, v in pairs(result :: any) do
		profile.Data[k] = v
	end

	local wrapped: ManagedProfile<T> = {
		profile = profile,
		data = profile.Data,
		save = function()
			-- ProfileStore auto-saves, but this allows manual saves
			profile:Save()
		end,
		release = function()
			profile:EndSession()
		end,
	}

	return true, wrapped
end

return ProfileStoreAdapter
