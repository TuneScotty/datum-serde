# ProfileStore + datum-serde Integration

Production-ready example combining **ProfileStore** (session-locked data) with **datum-serde** (validation + migration).

## Features

- ✅ Session locking (prevents data duplication across servers)
- ✅ Auto-save with graceful shutdown
- ✅ Schema validation on load
- ✅ Automatic migration from old versions (V1 → V2 → V3)
- ✅ Type-safe data access
- ✅ GDPR compliance helpers

## Setup

1. **Install dependencies:**
   ```bash
   wally install
   ```

2. **Sync with Rojo:**
   ```bash
   rojo serve
   ```

3. **In Roblox Studio:**
   - Connect via Rojo plugin
   - Press F5 to start game
   - Watch Output for profile loading messages

## Architecture

### Schema Versions

- **V1**: Basic coins + string array inventory
- **V2**: Added gems + structured inventory + stats
- **V3**: Currency system + settings + equipped items

### Migration Flow

```
Old Data (V1) → Validate → Migrate to V2 → Migrate to V3 → Save
```

All migrations are deterministic and reversible via your own logic.

### File Structure

```
profilestore_integration/
├── init.luau           # PlayerDataManager (validation + migration logic)
└── server.server.luau  # Server script (player join/leave handling)
```

## Usage

### Basic Profile Access

```lua
local PlayerDataManager = require(ServerScriptService.ProfileStoreExample)

-- Load player (happens automatically on join)
local ok, profile = PlayerDataManager.loadPlayer(player)
if not ok then
    player:Kick("Failed to load profile")
    return
end

-- Access data
profile.Data.currency.coins += 100
profile.Data.stats.kills += 1

-- Profile auto-saves periodically
```

### Adding New Fields

1. Create new schema version (e.g., V4)
2. Add migration from V3 → V4
3. Update `PROFILE_TEMPLATE`
4. Lock migration plan

### Custom Validation

The `validateAndMigrate` function in `init.luau` handles:
- Trying latest schema first (fast path)
- Falling back to older versions
- Running migration chain
- Returning typed result

## Testing

Monitor Output window for:

```
Player TestUser joining...
✓ Loaded profile for TestUser (version 3)
  Granted 10 coins, new balance: 110
  Granted starter sword
✓ TestUser ready to play
```

## Production Considerations

- **ProfileStore handles**:
  - Session locks
  - Auto-save intervals
  - Server crashes
  - Throttle limits

- **datum-serde handles**:
  - Data validation
  - Version migrations
  - Type safety
  - Error messages

Together they provide bulletproof player data management.

## Shutdown Behavior

```lua
game:BindToClose(function()
    PlayerDataManager.shutdown() -- Saves all profiles gracefully
end)
```

ProfileStore ensures data is saved even if server crashes unexpectedly.
