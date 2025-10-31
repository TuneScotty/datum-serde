--!strict

--[[
Purpose: Server-side script demonstrating ProfileStore + datum-serde integration.
Arguments: None
Time complexity: Varies by operation
]]

local Players = game:GetService("Players")
local PlayerDataManager = require(script.Parent)

-- Track loaded profiles
local loadedProfiles: { [Player]: any } = {}

--[[
Purpose: Handles player joining and loads their profile.
Arguments: player - Player instance
Time complexity: O(n) where n = profile size + migration cost
]]
local function onPlayerAdded(player: Player)
	print(`Player {player.DisplayName} joining...`)

	local ok, profile = PlayerDataManager.loadPlayer(player)

	if not ok then
		warn(`Failed to load profile for {player.DisplayName}: {profile}`)
		player:Kick("Failed to load your data. Please rejoin.")
		return
	end

	loadedProfiles[player] = profile

	-- Example: Grant join bonus
	profile.Data.currency.coins += 10
	print(`  Granted 10 coins, new balance: {profile.Data.currency.coins}`)

	-- Example: Add starter item if inventory empty
	if #profile.Data.inventory == 0 then
		table.insert(profile.Data.inventory, {
			id = "starter_sword",
			quantity = 1,
			equipped = true,
		})
		print("  Granted starter sword")
	end

	print(`✓ {player.DisplayName} ready to play`)
end

--[[
Purpose: Handles player leaving and saves their profile.
Arguments: player - Player instance
Time complexity: O(1)
]]
local function onPlayerRemoving(player: Player)
	local profile = loadedProfiles[player]
	if profile then
		print(`Saving {player.DisplayName}'s profile...`)
		-- ProfileStore auto-saves, but we end the session
		PlayerDataManager.unloadPlayer(player)
		loadedProfiles[player] = nil
		print(`✓ {player.DisplayName}'s profile saved`)
	end
end

-- Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle players who joined before script loaded
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Graceful shutdown
game:BindToClose(function()
	print("\n=== Server Shutting Down ===")
	PlayerDataManager.shutdown()
	print("=== Shutdown Complete ===\n")
end)

print("\n=== ProfileStore Player Data System Active ===")
print("  - Automatic validation and migration")
print("  - Session-locked profiles")
print("  - Auto-save enabled")
print("===========================================\n")
