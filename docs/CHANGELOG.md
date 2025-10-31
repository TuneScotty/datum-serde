# Changelog

All notable changes to datum-serde will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2025-10-31

### Fixed

- Removed dev-dependencies from published package manifest
- Fixed package contents to include only source code

## [0.1.1] - 2025-10-31

### Fixed

- Corrected package structure by moving wally.toml to src/ directory
- Ensured only datum module is included in published package

## [0.1.0] - 2025-10-31

### Added

- Core schema system with primitive, collection, and combinator builders
- JSON codec with safety checks (cycle detection, NaN/Inf rejection, size limits)
- Serde module for high-level encode/decode operations
- Migration system with DAG-based version transitions and cycle detection
- Comprehensive test suite (schema, codec, migration, integration)
- Benchmark harness for performance regression detection
- Example adapters for DataStore and ProfileStore integration
- Complete CI/CD pipeline (lint, test, build, publish)
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

### Performance

- Encode target: <2ms avg per 10k records
- Decode target: <3ms avg per 10k records
- Linear time complexity for all operations
- Bounded allocations (no quadratic behavior)

[Unreleased]: https://github.com/TuneScotty/datum-serde/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/TuneScotty/datum-serde/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/TuneScotty/datum-serde/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/TuneScotty/datum-serde/releases/tag/v0.1.0
