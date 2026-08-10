# Feature NNN: Name

## Identity and status

- Matrix identity:
- Audit state: queued | auditing | decision-ready | implementation-ready | stable
- Dependencies:
- Dependants:
- Existing ADRs:
- Shared fixtures:

## Why this feature exists

One sentence explaining the developer problem this feature solves.

## Boundary

What the feature owns, delegates, and explicitly does not do.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | | | | |
| Startup/CLI integration | | | | |
| Stored/wire format | | | | |
| Existing focused tests | | | | |
| Existing lab baseline | | | | |

## Public surface contract

Language-neutral concepts first, followed by idiomatic spellings per language.

## Inputs and outputs

Canonical types, fields, defaults, nullability, ordering and serialized shapes.

## Lifecycle and operation graph

Every producer -> discover -> execute -> inspect -> retry/rollback/delete path.

## Configuration and precedence

Explicit arguments, environment, project files, defaults, and read/cache timing.

## Failures, side effects and security

Raise/return boundaries, logging, atomicity, idempotency, cleanup, external I/O,
secret handling and destructive behavior.

## Wire and persistence contract

Protocols, status/headers, schemas, filenames, encodings, identifiers,
timestamps, and compatibility rules.

## Providers and substitutability

Every backend/provider must satisfy the same application-level cases. Record
deliberate capability exceptions explicitly.

## Contradictions and defects

Evidence-backed differences found during the audit. No implementation edits in
the audit-first phase.

## Owner decisions

Questions with alternatives and consequences, followed by the recorded rule.
An unresolved decision keeps this packet open.

## Proposed conformance fixture

Language-neutral positive, negative, malformed, stale, duplicate and partial
state cases. Include the mutation witness each future gate must carry.

## Integration map

Package exports, startup, request lifecycle, CLI, scaffolders, status/doctor,
documentation, release notes and generated-artifact consumers.

## Breaking changes and migration

Pre-3.14 changes are permitted for parity, but every break needs an actionable
migration instruction.

## Implementation backlog

Dependency-ordered changes for all existing languages and future ports. Planning
only until the full audit is complete.

## Porting capsule

A clean-room implementer must be able to build the feature from this file, its
ADRs and shared fixture without reading an existing runtime's source.

## Audit closure checklist

- [ ] Boundary and public surface complete.
- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Configuration, failure, side-effect and security rules complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [ ] Proposed shared cases and mutation witnesses complete.
- [ ] Integration map and breaking migrations complete.
- [ ] Implementation backlog dependency-ordered.
- [ ] Porting capsule is clean-room sufficient.

