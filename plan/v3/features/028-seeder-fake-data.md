# Feature 28: Seeder and fake data

## Identity and status

- Matrix identity: 28 - Seeder and fake data (`tina4_python/seeder/__init__.py`)
- Audit state: decision-ready
- Audit note: FOUR-language feature, strong parity with a PHP portability bug. Measured 2026-08-11. Python
  `seeder/__init__.py` (`ebbab30`); PHP `Tina4/FakeData.php` (`6faabac5`); Ruby `lib/tina4/seeder.rb`
  (`6d5b1de`); Node `packages/orm/src/seeder.ts` + `fakeData.ts` (`27cf0f4`).
- Dependencies: the ORM (feature 17, `seed_orm` saves through it), the fields (18, type-aware fakes), the DB
  facade.
- Dependants: dev fixtures; the dev-admin seed endpoint; tests.
- Existing ADRs: none dedicated.

- Catalog phase: ORM / dev tooling

## Why this feature exists

Seeding populates realistic fake rows for development and tests: type-aware and column-name-aware fakes,
FK-ordered inserts, and reproducibility. The hard parts are FK ordering (parents before children with real
parent PKs), determinism (a seed that reproduces), and engine portability.

## Existing implementation evidence

Universal: a `FakeData` generator (zero-dep RNG) with ~26 generators + a `for_field` type/column-name
heuristic; `seed_table` (raw-SQL inserts), `seed_orm` (saves through the ORM), and `seed_models`
(topo-sorted parents-before-children by the FK graph, reverse-order clear). All do REAL DB writes and count
per-row failures (with `strict` re-raise). `seed_orm`/`seed_models` are deterministic (a seeded RNG); FK
columns resolve to REAL parent PKs from a pool. A CLI `seed` command + a dev-admin `POST /__dev/api/seed`
route it.

## Public surface contract

`FakeData(seed)` + `seed_table`/`seed_orm`/`seed_models`. Contract: real fake rows, FK-ordered, deterministic
when seeded, failures counted not silent.

## Inputs and outputs

- Input: a model/table, a count, a seed, overrides. Output: inserted rows + a `SeedSummary {seeded, failed,
  errors}`.

## Lifecycle and operation graph

1. Build fakes (type/column-name aware) -> insert (real DB) per row (counting failures).
2. `seed_models` topo-sorts by FK deps and fills child FKs from real parent PKs.

## Configuration and precedence

- The seed (RNG), overrides, `clear`, `strict`. No env for the API; the CLI reads a seeds dir.

## Failures, side effects and security

- Real DB writes. Failures are counted (not silent) with `strict` re-raise. The `credit_card` generator emits
  real-looking test PANs from live BIN prefixes (fine for fixtures, unmasked - note it). The PRNG is
  NON-CRYPTO - never for secrets/tokens (SEED-SECRETS-DOC). See the register for the determinism and
  portability issues.

## Wire and persistence contract

Inserted rows; a `SeedSummary`. `seed_orm` goes through the ORM's parameterized write; `seed_table` builds raw
SQL (see the register - PHP's is non-portable).

## Providers and substitutability

The generators are fixed; the RNG is seedable.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| SEED-TABLE-SEED-INERT | UNIVERSAL: `seed_table`'s `seed` argument is INERT in all four - it does not seed the generators the caller passes (only `seed_orm`/`seed_models` are actually deterministic). So `seed_table(..., seed=42)` (per the docs) provides NO reproducibility, yet the signature invites the assumption. | Either make `seed_table(seed=)` build and thread a seeded `FakeData`, or remove the parameter and document that determinism requires a caller-seeded `FakeData`. |
| SEED-PHP-BACKTICK | PHP-SPECIFIC: `seed_table` quotes identifiers with BACKTICKS (`INSERT INTO \`t\` (\`col\`)`) - MySQL/SQLite only. On PostgreSQL/Firebird (double-quote) and MSSQL (brackets) every `seed_table` INSERT raises a syntax error and all rows fail. The dev-admin `POST /__dev/api/seed` delegates to `seed_table`, so DASHBOARD SEEDING IS BROKEN on non-MySQL/SQLite engines. Untested (the seeder suite is SQLite-only). `seed_orm` avoids it (parameterized adapter insert). | Quote `seed_table` identifiers per the engine's dialect (or route it through the parameterized adapter path like `seed_orm`); test it on a real PG/MSSQL/Firebird. |
| SEED-NODE-DEFAULT | Node-specific: `for_field` ALWAYS returns the field default when one is set - but the comment says "use it sometimes (but not always for variety)"; the "sometimes" is unimplemented, so every seeded row gets the IDENTICAL value for any defaulted field (no variety). | Implement the "sometimes" (or drop the comment) so defaulted fields get varied fakes. |
| SEED-RUBY-QUIRKS | Ruby-specific: `FakeData#boolean` returns `0`/`1` (Integer), not `true`/`false` - a type surprise for a native-boolean column; and the idempotency short-circuit silently skips seeding a table that already holds `>= count` rows (even UNRELATED rows), returning `seeded=0` (INFO log only). | Return a native boolean; make the idempotency skip check the seeded set (or log louder). |
| SEED-DETERMINISM-PERLANG | UNIVERSAL, by design but UNDOCUMENTED: the RNG is per-language (Python Mersenne Twister vs Node `mulberry32` vs the PHP/Ruby hand-rolled generators), so the SAME seed does NOT reproduce the same rows ACROSS languages - only within one language. Acceptable for fake data, but nothing states it, so a caller may wrongly expect cross-language reproducibility. | Document that determinism is PER-LANGUAGE, not cross-language (no shared PRNG - hand-rolling one would add cost for no benefit). |
| SEED-VOCAB-PARITY | UNIVERSAL: the field-generator vocabulary (name/first_name/last_name/email/phone/integer/decimal/boolean/...) is NOT gated for parity across the four - only Python's set is fully measured, so the four can drift on which generators exist. | Pin ONE generator vocabulary present in all four (idiomatic spelling per language), gated by the fixture. |
| SEED-SECRETS-DOC | UNIVERSAL: nothing states the PRNG is NOT for secrets/tokens; a developer could reach for `FakeData` to generate an API key or password. It is a non-crypto generator. | Document the not-for-secrets boundary on the class in all four. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- SEED-DEC-01 (proposed): fix the PHP `seed_table` engine portability (SEED-PHP-BACKTICK) - it breaks the
  dev-admin seed on PG/MSSQL/Firebird - and make `seed_table(seed=)` deterministic or remove it
  (SEED-TABLE-SEED-INERT).
- SEED-DEC-02 (proposed, low): Node's default-variety (SEED-NODE-DEFAULT) and Ruby's boolean/idempotency
  quirks (SEED-RUBY-QUIRKS); document per-language determinism (SEED-DETERMINISM-PERLANG) and the
  not-for-secrets boundary (SEED-SECRETS-DOC); pin the generator vocabulary across the four (SEED-VOCAB-PARITY).

## Proposed conformance fixture

A shared fixture (real engines): `seed_table` inserts correctly on PostgreSQL/MSSQL/Firebird (catches
SEED-PHP-BACKTICK); `seed_orm`/`seed_models` reproduce identical rows for a given seed; `seed_models`
topo-orders parents before children with real FK values; failures are counted (not silent) with `strict`
re-raise.

## Integration map

- Consumers: dev fixtures, tests, the dev-admin seed endpoint (feature 127). Composes: the ORM (17), the
  fields (18), the DB facade.

## Breaking changes and migration

- Fixing PHP's `seed_table` quoting changes generated SQL (makes it work on more engines) - a correctness fix.
  Making `seed_table(seed=)` deterministic changes reproducibility - document it.

## Porting capsule

A seeder needs: a seedable zero-dep fake generator (type + column-name aware); `seed_orm` that writes through
the ORM's PARAMETERIZED path (never raw dialect-specific SQL - the PHP backtick bug); `seed_models` that
topo-sorts parents-before-children and fills child FKs from real parent PKs; deterministic output for a given
seed (and a `seed_table` seed that actually seeds, or no seed parameter); failures counted (not silent) with a
`strict` re-raise; and engine-portable SQL tested on a real PG/MSSQL/Firebird - not SQLite-only.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete (generate -> insert -> topo-sort).
- [x] Configuration, failure (counted) and security rules complete.
- [x] Wire/persistence (rows, SeedSummary) and provider contracts complete.
- [x] Four-language behaviour recorded (seed-inert universal; PHP backtick; Node/Ruby quirks).
- [x] Owner ambiguities decided (SEED-DEC-01/02).
- [x] Conformance fixture (portability + determinism + FK order) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
