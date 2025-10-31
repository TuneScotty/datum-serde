# Setup Guide

## Prerequisites

- [Wally](https://github.com/UpliftGames/wally) - Package manager
- [Rojo](https://rojo.space/) - Sync tool
- Roblox Studio with Rojo plugin

## Installation Steps

### 1. Install Dependencies

Run from project root:

```bash
wally install
```

This installs:
- `ProfileStore` (dev dependency for examples)

### 2. Start Rojo Server

```bash
rojo serve
```

### 3. Connect in Studio

- Open Roblox Studio
- Click Rojo plugin → Connect
- Wait for sync to complete

### 4. Test the Examples

#### A. Run Unit Tests

Press F5 in Studio. The test suite runs automatically:

```
============================================================
DATUM-SERDE TEST SUITE
============================================================
✓ Schema Tests
✓ Codec Tests  
✓ Migration Tests
✓ Integration Tests
============================================================
```

#### B. Test ProfileStore Integration

The `ProfileStoreExample.server` script auto-runs when game starts.

**Expected output:**

```
=== ProfileStore Player Data System Active ===
  - Automatic validation and migration
  - Session-locked profiles
  - Auto-save enabled
===========================================

Player YourUsername joining...
✓ Loaded profile for YourUsername (version 3)
  Granted 10 coins, new balance: 110
  Granted starter sword
✓ YourUsername ready to play
```

**Test migration:**

Edit `init.luau` to use V1 template, join game, observe auto-migration to V3.

## Project Structure

```
datum-serde/
├── src/datum/              # Core library
│   ├── schema.luau         # Schema builders
│   ├── serde.luau          # Encode/decode
│   ├── migrate.luau        # Migration system
│   ├── codec/              # Serialization formats
│   │   └── json.luau
│   └── adapter/            # Storage adapters
│       ├── datastore.luau
│       └── profilestore.luau
├── examples/
│   ├── player_store/       # Basic DataStore example
│   └── profilestore_integration/  # Production example
├── tests/                  # Unit tests
└── wally.toml             # Dependencies
```

## Development Workflow

1. Make code changes
2. Rojo auto-syncs to Studio
3. Reload/restart game in Studio
4. Check Output window for results

## Troubleshooting

### "Module not found" errors

- Ensure `wally install` completed successfully
- Check `Packages/` directory exists
- Reconnect Rojo plugin

### ProfileStore errors in Studio

ProfileStore requires DataStoreService, which:
- Works in published games
- Works in Studio with API access enabled
- May show warnings in local testing

Use `MockDataStoreService` for local testing if needed.

### Type warnings in old example

The `player_store/example_usage.luau` may show `PlayerData` type warnings. These are cosmetic - the new `profilestore_integration` example is the recommended reference.

## Next Steps

- Read `examples/profilestore_integration/README.md`
- Adapt schemas to your game's data model
- Add custom validation logic
- Deploy to production
