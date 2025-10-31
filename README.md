<p align="center">
  <img src="public/misc/DatumSerde.png" alt="DatumSerde Logo" style="width:300px; height:auto;">
</p>



# datum-serde

Type-safe data serialization, migration, and versioning for Roblox.

## Features

- **Type-safe schemas** for structured data with full Luau typing
- **JSON serialization** with deterministic encoding (binary in v0.2)
- **Versioned migrations** with DAG-based planning and deterministic transforms
- **Validation** with precise error paths (e.g., `/inventory/3/name: expected string, got number`)
- **Robust error handling** with detailed failure reasons
- **Example adapters** for DataStore and ProfileStore integration

## Installation

### Wally

Add to your `wally.toml`:

```toml
[dependencies]
DatumSerde = "tunescotty/datum-serde@0.1.2"
```

Then run:

```bash
wally install
```

### pesde

Run:

```bash
pesde add tunescotty/datum_serde
```

Then run:

```bash
pesde install
```

## Quick Start

```lua
local S = require(ReplicatedStorage.Packages.DatumSerde.schema)
local Serde = require(ReplicatedStorage.Packages.DatumSerde.serde)
local JSON = require(ReplicatedStorage.Packages.DatumSerde.codec.json)
local M = require(ReplicatedStorage.Packages.DatumSerde.migrate)

-- Define schemas
local V1 = S.object({
    version = S.literal("1"),
    coins = S.number(),
    inventory = S.array(S.string())
})

local V2 = S.object({
    version = S.literal("2"),
    coins = S.number(),
    inventory = S.array(S.string()),
    flags = S.map(S.string(), S.boolean())
})

-- Create migration plan
local plan = M.plan()
plan:add("1", "2", function(v)
    if type(v) ~= "table" or v.version ~= "1" then
        return false, "bad v1"
    end
    v.version = "2"
    v.flags = {}
    return true, v
end)

-- Load, migrate, save
local ok, v1 = Serde.decode(V1, oldPayload, JSON)
if not ok then error(v1) end

local okM, v2 = M.apply(plan, v1, "1", "2")
if not okM then error(v2) end

local okE, newPayload = Serde.encode(V2, v2, JSON)
if not okE then error(newPayload) end
```

## Documentation

See [docs/Design.md](docs/Design.md) for architecture details.

## License

MIT
