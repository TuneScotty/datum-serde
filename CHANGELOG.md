# Changelog

All notable changes to datum-serde will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-XX

### Added

- Core schema system with primitive, collection, and combinator builders
- JSON codec with safety checks (cycle detection, NaN/Inf rejection, size limits)
- Serde module for high-level encode/decode operations
- Migration system with DAG-based version transitions and cycle detection
- DataStore adapter with exponential backoff retry logic
- Comprehensive test suite (schema, codec, migration, integration)
- Benchmark harness for performance regression detection
- PlayerStore example demonstrating ProfileStore integration
- Complete CI/CD pipeline (lint, typecheck, build, test, publish)
- Design documentation covering architecture and implementation details

### Schema Features

- `nil()`, `boolean()`, `number()`, `string()` primitives
- `literal(value)` for exact value matching
- `array(schema)` and `map(key, value)` collections
- `object(shape)` for structured data
- `union(...schemas)` and `optional(schema)` combinators
- `refine(schema, predicate, msg)` for custom validation
- Full Luau type safety with generic support
- JSON-pointer-like error paths (e.g., `/inventory/3/name`)

### Codec Features

- JSON encode/decode via HttpService
- Configurable limits (maxDepth, maxArrayLength, maxBytes)
- Safety checks: cycles, metatables, NaN, Infinity
- Deterministic encoding for reproducible outputs

### Migration Features

- DAG-based migration graph with BFS path finding
- Deterministic, pure migration functions
- Cycle detection with DFS
- Plan locking for production safety
- Multi-step migration support (e.g., V1 → V2 → V3)

### DataStore Features

- Retry logic with exponential backoff and jitter
- Budget-aware throttle detection
- Configurable max retries and base delay
- Type-safe string payload handling

### Performance

- Encode target: <2ms avg per 10k records
- Decode target: <3ms avg per 10k records
- Linear time complexity for all operations
- Bounded allocations (no quadratic behavior)

[Unreleased]: https://github.com/x6ski/datum-serde/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/x6ski/datum-serde/releases/tag/v0.1.0
