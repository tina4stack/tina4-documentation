# Tina4 v3 - Contract and Spec Map

> The living index that ties every audited feature to its machine-checked
> contract, its decisions, and its proven-in-all-four status. This is the
> backbone of a future formal Tina4 language specification.
> **Last synced:** 2026-08-07 (release 3.13.96 in progress)

## Why this map exists

Tina4 is one framework in four languages. A "spec" that lives only as prose
drifts the moment one implementation changes. So the real specification is being
built as **machine-checked contracts**: a shared JSON fixture per subsystem,
whose invariants are proven by a named test in every framework and gated by one
checker (`scripts/audit-contract-fixtures.py`, ADR-0024 rule 6). A contract that
is green is a behaviour all four frameworks are held to.

This file is the map from features to those contracts. It answers one question
per feature: **is its behaviour specified, decided, and proven in all four - or
still owed?** As each feature is audited it moves down the pipeline below, and
its row here is updated. Keeping this map current is how the audit work
accumulates into a language spec instead of scattering.

## The spec, in three layers

1. **[MASTER-SPEC.md](MASTER-SPEC.md)** - the prose API contract per feature
   (last full pass 2026-03-21). Readable, but it predates the contract fixtures,
   so where a fixture exists **the fixture is authoritative for behaviour** and
   MASTER-SPEC is the narrative around it. A future formal spec is produced by
   folding the fixtures + ADRs back into this document.
2. **Contract fixtures** (`fixtures/*_contract.json`) - the machine-checked,
   four-way-proven behavioural invariants. The authoritative layer.
3. **ADRs** (`decisions/ADR-*.md`) - the decisions behind the contracts (41
   allocated). An invariant cites the ADR that settled it.

## The pipeline (how a feature reaches the spec)

A feature is "specified" only when it has walked all six steps. This mirrors the
audit method in [98-feature-audit.md](98-feature-audit.md).

1. **Audit** - measure LOC/CC/MI four-way, read all four, pick the best mechanism.
2. **Plan** - park it as `features/NNN-<name>.md` (26 exist).
3. **Decide** - any behaviour fork gets an `ADR-NNNN.md`.
4. **Fixture** - write `fixtures/<name>_contract.json` with the invariants + the
   conformance cases as data.
5. **Prove** - a named suite carrying those case names in ALL FOUR; the auditor
   green; the full suites green on the lab.
6. **Fold** - reflect the proven contract into MASTER-SPEC.

## Layer 2: machine-checked contracts (proven behaviour)

Source of truth for the counts: `python3 scripts/audit-contract-fixtures.py`.
Re-run it and re-sync this table whenever a fixture changes.

| Subsystem | Feature # | Fixture | Invariants | Proven | Owed | ADRs | Named suites (all 4) |
|---|---|---|---:|---:|---:|---|---|
| Router + dispatch | 6 | `dispatch_contract.json` | 8 | 8 | 0 | 0010-0013 | yes |
| Health check | 8 | `health_contract.json` | 5 | 5 | 0 | 0016 | yes |
| JWT + session | 41-42 | `session_contract.json` | 6 | 6 | 0 | 0021, 0024 | yes (5 carry a witness rule) |
| Cache backends | 43 | `cache_contract.json` | 8 | 8 | 0 | 0020, 0024 | yes |
| Queue backends | 48 | `queue_contract.json` | 7 | 7 | 0 | 0022-0024 | yes |
| Swagger / OpenAPI | 47 | `swagger_contract.json` | 10 | 10 | 0 | 0004, 0041 | yes (added 2026-08-07) |
| DocStore | - | `docstore_contract.json` | 9 | 9 | 0 | 0024, 0025, 0035, 0036 | yes |
| tina4-css | - | `tina4css_contract.json` | 1 | 1 | 0 | 0004 | yes |
| Messenger | 0 (pilot) | `messenger_contract.json` | 14 | 14 | 0 | 0004, 0041, 0042 | yes (real GreenMail) |

**Totals: 68 invariants, 68 proven, 0 owed** (2026-08-07). Every pluggable
subsystem with a fixture is now held to its contract four-way. Messenger closed
last: the read/send shapes were already unified by the 3.13.96 parity commits
(decisions G4-G7), so the suites prove shipped behaviour; ADR-0042 records the
uid-is-the-IMAP-UID rule. TWO follow-ups fell out of the messenger round, filed
not gated: read() attachment BYTES are retrievable only in Python
(`attachments_data`) while the other three return metadata-only attachments; and
PHP's read() carries `msgno` (a sequence number ADR-0042 says is not a public id)
plus a `message_id` that duplicates `headers`.

## Layer 1 only: audited and decided, no machine-checked fixture yet

These closed through an audit + a `features/NNN` plan (+ an ADR where a fork
existed), but do not yet have a JSON contract fixture. They are specified by
their plan and ADR, and are the first candidates to promote to Layer 2.

| Feature | Plan | Decision / ADR | State |
|---|---|---|---|
| 1 DotEnv parser | `features/001-dotenv.md` | SYNTHESISE | closed (4 defects re-closed 2026-08-01) |
| 2 Structured logger | `features/002-structured-logger.md` | SYNTHESISE | closed 2026-08-05 |
| 3 DB adapter interface | `features/003-database-adapter-interface.md` | REDESIGN | closed (CRUD left the adapters) |
| 4 SQLite adapter + write path | `features/004-sqlite-adapter.md` | GAP (P1) | closed, 1 deferred to feat 18 |
| 5 DATABASE_URL parser | `features/005-database-url-parser.md` | PROMOTE php | shipped all 4 |
| 7 Middleware pipeline | `features/007-middleware-pipeline.md` | ADR-0014 | closed, merged to v3 |
| 9 Graceful shutdown | `features/009-graceful-shutdown.md` | ADR-0017 | closed, merged to v3 |
| 10 CORS middleware | `features/010-cors-middleware.md` | ADR-0018 | closed (deny by default) |
| 11-12, 79 Rate limiter / response types / route groups | - | ADR-0019 | closed, merged to v3 |
| 13 ORM base class | `features/013-orm-base-class.md` | PROMOTE ruby | closed |
| 14 Soft delete | `features/014-soft-delete.md` | GAP | closed, 1 outstanding |
| 15 Relationships + eager load | `features/015-relationships.md` | PROVISIONAL | closed |
| 16 Scopes | `features/016-scopes.md` | SYNTHESISE | closed |
| 17 Field mapping | `features/017-field-mapping.md` | ADR-0008 | closed |
| 18 Paginated results | `features/018-paginated-results.md` | PROMOTE php | **RE-OPENED 2026-08-05** - `.count` means true-total in 2 of 4, rows-returned in the other 2; the envelope launders a truncation. Breaking fix pending. |
| 19 Result / ORM caching | `features/019-orm-result-caching.md` | GAP (ruby) | closed |
| 20 Input validation | `features/020-input-validation.md` | PROMOTE node | closed |
| 28-31 Frond engine | `features/028-031-frond-engine.md` | PROMOTE python | closed as one row |
| 32 Frond filters | `features/032-frond-filters.md` | SYNTHESISE | closed |
| 37 Auto-escaping | `features/037-auto-escaping.md` | UNIFORM | closed, 1 owner call |
| 38 Sandboxing | `features/038-sandboxing.md` | PROMOTE php (P1) | shipped all 4 |
| 50 Api / HTTP client | (this release) | frameworks-outrank-internal | `send_request` unified 2026-08-07 (Python was the outlier; Ruby cannot use bare `send`). No fixture yet. |

## Layer 0: not yet audited (66 features)

Every audited feature so far found something broken and invisible - none came
back clean - so these are unexamined, not "probably fine" (98-feature-audit.md).
Each still owes the full pipeline: audit -> plan -> ADR -> fixture -> proven.

- **21-27 Migrations** - **NEXT UP.** Extensive per-framework suites already
  exist (kind-contract, passed-column, footguns, auto-migrate, CLI, default-path
  in all four); the owed work is the four-way measurement + a shared
  `migrations_contract.json`.
- **33-36** Frond tags / tests / functions / extensibility
- **39-40** Template cache / fragment cache
- **44-46** (data/ORM remainder)
- **49-78** (services, realtime, i18n, container, events, CLI subcommands, MCP, ...)
- **80-98** (setup wizard, deploy, generators, doctor, metrics, ...)

The authoritative live list of members and grouping is
[01-FEATURE-MATRIX.md](01-FEATURE-MATRIX.md).

## Keeping this map current (the discipline)

This map only earns its name if it stays synced. On each of these events, update
the matching row here in the SAME change:

- **A feature audit closes** -> add/move its Layer 1 row, cite its `features/NNN`
  plan and ADR.
- **A fixture is written or an invariant flips owed -> proven** -> re-run
  `scripts/audit-contract-fixtures.py`, copy its proven/owed counts into Layer 2.
- **An ADR is allocated** -> cite it on the invariant and the row.
- **A feature moves out of Layer 0** -> strike it from the not-yet-audited list.

The auditor's own numbers, never a hand count, are the source of truth for
proven/owed. A row here that disagrees with the auditor is a bug in this file.

## Snapshot (2026-08-07)

- 98 features: ~30 audited (Layer 1 or 2), 66 not started (Layer 0).
- 9 contract fixtures, 68 invariants, **68 proven / 0 owed** (messenger closed
  2026-08-07).
- 41 ADRs allocated (`decisions/`), highest ADR-0041; ADR-0042 authored this
  release for the messenger uid rule.
- The path to a formal language spec: every Layer-0 feature reaches Layer 2, the
  owed count reaches 0, and MASTER-SPEC is regenerated from the fixtures + ADRs.
