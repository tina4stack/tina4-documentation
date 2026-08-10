# Feature 063: JWT and request authentication

## Identity and status

- Matrix identity: 63 — JWT and request authentication
- Audit state: auditing
- Audit note: Structure migrated; closure checklist records remaining work
- Dependencies: not yet extracted from the retained audit evidence
- Dependants: not yet extracted from the retained audit evidence
- Existing ADRs: ADR-0021
- Shared fixtures: copied `test_auth_session_contract` cases, not one
  central data oracle

- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-08-01, previously bundled with Feature 64

## Why this feature exists

An engineer needs one authentication surface that creates and validates tokens,
enforces time claims and protects real routes the same way in every language.

## Boundary

Feature 63 owns token creation and validation, configured algorithm enforcement,
claims and time boundaries, request authentication, API-key interaction and the
byte-compatible password-hash contract. Session IDs, cookies, persistence and
session backends belong to Feature 64.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

### Historical evidence retained

All four implemented HS256/384/512 and rejected `alg: none`. PHP and Node had
native RS256; Python did not. Ruby's partial RS256 path depended on an undeclared
`jwt` gem and could be activated by key files appearing on disk. Password hashes
were verified byte-compatible as
`pbkdf2_sha256$260000$salt$hex` with a 32-byte derived key.

The bundled audit fixed these measured defects:

- Python treated a decoded Basic header as an authenticated truthy result
  without verifying credentials.
- malformed `exp`/`nbf` claims and the exact expiry boundary differed;
- request-auth API-key result shapes differed;
- Python/Ruby route gates bypassed the timing-safe API-key validator.

Still unresolved in the historical packet: route-gate API-key bypass was a
two-two split, Ruby could auto-switch to an undeclared RS256 dependency, and
`expires_in=0` meant non-expiring in three ports but immediately expired in
Ruby. The standalone audit must settle these decisions, centralize executable
vectors and test real application gates rather than copied helpers.

## Public surface contract

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

The audit has not yet fixed all native types, defaults, nullability, ordering, and serialized shapes.

## Lifecycle and operation graph

The audit has not yet traced every producer, discovery, execution, inspection, retry, rollback, and deletion path.

## Configuration and precedence

The audit has not yet fixed argument, environment, project-file, default, and cache timing precedence.

## Failures, side effects and security

The audit has not yet closed every failure boundary, side effect, cleanup rule, and security concern.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

The audit has not yet proved provider substitution or recorded deliberate capability exceptions.

## Contradictions and defects

No contradiction-free conclusion has been extracted from the retained audit evidence.

## Owner decisions

No new owner decision is recorded in this migrated section. Retained decisions appear below when present.

## Proposed conformance fixture

The audit has not yet produced the complete shared cases and mutation witnesses required for a parity gate.

## Integration map

The audit has not yet mapped every export, startup path, request hook, CLI, scaffolder, status command, document, and generated consumer.

## Breaking changes and migration

The audit has not yet turned every parity break into an actionable pre-3.14 migration instruction.

## Implementation backlog

The audit has not yet produced a dependency-ordered backlog for all current languages and future ports.

## Porting capsule

This packet is not yet sufficient for a clean-room implementation without reading an existing runtime.

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
