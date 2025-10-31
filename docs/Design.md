# datum-serde Design Document

## Architecture Overview

datum-serde is a layered system for type-safe data serialization, validation, and migration in Roblox.

```
┌─────────────────────────────────────────────────┐
│              User Application                    │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│           Serde (High-Level API)                 │
│  encode(schema, value, codec) -> payload        │
│  decode(schema, payload, codec) -> value        │
└─────────┬───────────────────────┬───────────────┘
          │                       │
┌─────────▼────────┐    ┌────────▼──────────────┐
│     Schema       │    │       Codec           │
│  - Validation    │    │  - JSON (v0.1)        │
│  - Structure     │    │  - Binary (v0.2)      │
│  - Encode/Decode │    │                       │
└──────────────────┘    └───────────────────────┘
          │
┌─────────▼─────────────────────────────────────┐
│              Migration                         │
│  - DAG-based version transitions               │
│  - Deterministic transformations               │
│  - Cycle detection                             │
└────────────────────────────────────────────────┘
          │
┌─────────▼─────────────────────────────────────┐
│          Adapter (Storage)                     │
│  - DataStore (with retry logic)                │
│  - Budget-aware operations                     │
└────────────────────────────────────────────────┘
```

## Core Flow

### Encode
```
UserValue (typed)
  → [Schema.validate] → Validation
  → [Schema.encode] → AST (plain Lua table)
  → [Codec.encode] → Payload (string or bytes)
```

### Decode
```
Payload (string or bytes)
  → [Codec.decode] → AST (plain Lua table)
  → [Schema.decode] → Validation + Transform
  → UserValue (typed)
```

### Migration
```
OldPayload
  → [Decode with old schema] → OldValue
  → [Migrate.apply] → BFS path finding → Apply transforms
  → NewValue
  → [Encode with new schema] → NewPayload
```

## Schema System

### Design Principles

1. **Declarative** - Schemas are data structures, not imperative code
2. **Composable** - Build complex schemas from simple primitives
3. **Type-safe** - Full Luau type inference where possible
4. **Error-rich** - JSON-pointer-like paths in all errors

### Schema Interface

Every schema implements:
```lua
type Schema<T> = {
    kind: string,                      -- "number", "object", etc.
    _inner: any?,                      -- nested schema metadata
    validate: (value, path) -> (ok, err?),
    encode: (value: T) -> any,         -- to AST
    decode: (ast, path) -> (ok, T|err)
}
```

### Available Builders

- **Primitives**: `nil()`, `boolean()`, `number()`, `string()`
- **Literal**: `literal(value)` - exact value match
- **Collections**: `array(elem)`, `map(key, val)`, `object(shape)`
- **Combinators**: `union(...schemas)`, `optional(schema)`
- **Refinement**: `refine(schema, predicate, msg)` - custom validation

### Validation Strategy

- Early fail on type mismatch
- Path tracking with `/field/index` notation
- No exceptions - returns `(boolean, error_string?)`
- NaN/Infinity rejected by number schema
- Array validation is index-based (0-indexed in error paths)

## Codec System

### JSON Codec (v0.1)

Uses `HttpService:JSONEncode/Decode` with safety layers:

**Safety Checks**
1. Cycle detection via visited table tracking
2. Metatable rejection (plain tables only)
3. NaN/Infinity rejection
4. Configurable limits:
   - Max depth (default 100)
   - Max array length (default 100k)
   - Max output bytes (default 10MB)

**Determinism**
- Relies on HttpService deterministic encoding
- No custom table iteration (order undefined in Lua)
- Maps encoded as-is (key order not guaranteed, but stable per run)

### Binary Codec (v0.2 - Stub)

Planned CBOR-like format:
- Type tags: 1 byte per value
- Compact integers: varint encoding
- String length prefixes
- Zero-copy decode where possible

## Migration System

### Graph Structure

Migrations form a directed acyclic graph (DAG):
```
    1 ──────> 2
    │         │
    │         │
    └────> 3 ─┴─> 4
```

Each edge is a pure function: `(OldValue) -> (boolean, NewValue|err)`

### Path Finding

- BFS (breadth-first search) finds shortest path
- Time complexity: O(V + E)
- Returns early on first path found

### Cycle Detection

- DFS with visiting/visited sets
- Runs before applying migrations
- O(V + E) worst case

### Guarantees

1. **Determinism** - Same input → same output, always
2. **Purity** - No side effects in migration functions
3. **Idempotence** - Applying same migration twice is safe (if data already migrated, no-op via version check)
4. **Error propagation** - Any step failure aborts entire migration

### Locking

Call `plan:lock()` in production to prevent accidental mutation of migration graph after initialization.

## Error Model

All public functions return `(boolean, value_or_error_string)`.

### Error Format

```
E:<Category>: <Details>
```

**Categories**
- `E:Validation` - Schema validation failed
- `E:Codec` - JSON encode/decode failed
- `E:Migration` - Migration step failed
- `E:DataStore` - Storage operation failed
- `E:Safety` - Cycle/metatable/limit violation

**Path Notation**
- Root: `` (empty)
- Object field: `/fieldName`
- Array element: `/arrayField/0` (0-indexed)
- Nested: `/player/inventory/3/name`

### Example Errors

```
E:Validation: /player/age: expected number, got string
E:Codec: NaN not allowed
E:Migration: step 1 -> 2 failed: invalid v1 data
E:DataStore: read failed after 3 attempts: Budget exceeded
```

## DataStore Adapter

### Features

1. **Retry logic** - Exponential backoff with jitter
2. **Budget-aware** - Detects throttle errors and retries
3. **Configurable** - `setMaxRetries()`, `setBaseDelay()`
4. **Type-safe** - Only accepts string payloads

### Backoff Formula

```
delay = baseDelay * (2^(attempt-1)) + jitter
jitter = random(0%, 30%) * delay
```

Default: 1s, 2s, 4s with jitter

### Error Handling

- Retries on budget/throttle errors
- Fails fast on key not found or invalid input
- Returns descriptive error with attempt count

## Performance Considerations

### Targets (v0.1)

- Encode: <2ms avg per 10k simple records
- Decode: <3ms avg per 10k records
- Allocations: O(n fields), no quadratic behavior
- Migration: Linear in transformed nodes

### Optimization Points

1. **Schema validation** - Single-pass, early exit
2. **JSON codec** - Direct HttpService call, minimal wrapping
3. **Migration** - BFS caches visited nodes
4. **No string concatenation** - Use table.concat for errors

### Known Bottlenecks

- `HttpService:JSONEncode` - Roblox engine call, can't optimize
- Deep nesting - O(depth) stack frames
- Large arrays - O(n) validation per element

## Testing Strategy

### Unit Tests

- Per-module: schema, codec, migrate
- Cover all builders and combinators
- Test error paths explicitly

### Integration Tests

- Full encode → decode round-trips
- Multi-step migrations
- Complex nested structures
- Validation failure messages

### Property-Based Tests (Future)

- Random value generation from schema
- Round-trip invariant: `decode(encode(x)) == x`
- N=10k cases in CI, N=100k locally

### Benchmarks

- `benches/encode_decode.luau` - Performance regression detection
- Export CSV for historical tracking
- CI fails if targets exceeded

## Security & Robustness

### Threat Model

1. **Malicious payloads** - Crafted to DoS or exploit
2. **Corrupted data** - Bit flips, partial writes
3. **Version confusion** - Wrong schema applied

### Mitigations

1. **Size limits** - Max depth, length, bytes
2. **Type checking** - Strict validation before use
3. **No eval** - No loadstring or dynamic code execution
4. **Metatables forbidden** - Plain tables only
5. **Version markers** - Explicit version field in all schemas

## Compatibility: ProfileStore

datum-serde works alongside ProfileStore by storing only the serialized payload:

```lua
Profile.Data = {
    blob = "<datum-serde JSON payload>"
}
```

Workflow:
1. Load Profile → extract `blob`
2. Decode → Migrate → Update
3. Encode → save back to `blob`
4. Release Profile

Use the example `PlayerStore` module for a complete integration pattern.

## Future Work (v0.2+)

- Binary codec (CBOR-like) for 50%+ size reduction
- Schema introspection API for auto-documentation
- CLI tool for schema validation and diff
- Property-based test generator from schemas
- Metrics hooks (encode time, payload size, migration steps)
- Zero-alloc decode for primitive arrays

## API Stability

v0.1 is the initial release. Breaking changes possible before v1.0.

Semver guarantees:
- Major version: breaking API changes
- Minor version: additive features
- Patch version: bug fixes only

## References

- [JSON RFC 8259](https://datatracker.ietf.org/doc/html/rfc8259)
- [CBOR RFC 8949](https://datatracker.ietf.org/doc/html/rfc8949)
- [JSON Pointer RFC 6901](https://datatracker.ietf.org/doc/html/rfc6901)
