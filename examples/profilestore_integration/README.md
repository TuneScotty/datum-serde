# ProfileStore + datum-serde Integration

Production-ready example combining **ProfileStore** (session-locked data) with **datum-serde** (validation + migration).

## Quick Start

```bash
wally install
rojo serve
```

## Features

- Session locking (prevents data duplication)
- Auto-save with graceful shutdown
- Schema validation on load
- Automatic migration (V1 → V2 → V3)
- Type-safe data access
- GDPR compliance helpers

## Architecture

**Schema Versions**:
- **V1**: coins + inventory (strings)
- **V2**: gems + structured inventory + stats
- **V3**: currency system + settings + equipped items

**Flow**: Old Data → Validate → Migrate Chain → Save

**Files**:
- `init.luau` - PlayerDataManager (validation + migration)
- `server.server.luau` - Server script (player join/leave)

## Usage

```lua
local PlayerDataManager = require(ServerScriptService.ProfileStoreExample)

-- Load player (auto on join)
local ok, profile = PlayerDataManager.loadPlayer(player)
if not ok then player:Kick("Failed to load profile") end

-- Access data
profile.Data.currency.coins += 100
profile.Data.stats.kills += 1
-- Auto-saves periodically
```

## Adding New Versions

1. Create schema V4
2. Add migration V3 → V4
3. Update `PROFILE_TEMPLATE`
4. Lock migration plan

## Production

**ProfileStore handles**: Session locks, auto-save, crashes, throttle limits

**datum-serde handles**: Validation, migrations, type safety, errors

**Shutdown**:
```lua
game:BindToClose(function()
    PlayerDataManager.shutdown() -- Saves all profiles
end)
```

ProfileStore ensures data persists even on server crash.
