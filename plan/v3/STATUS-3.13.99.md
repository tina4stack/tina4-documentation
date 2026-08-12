# 3.13.99 implementation status

First-pass release. One feature fully completed in all four frameworks (real no-mock tests + shared
fixture, lab-green on the .99 lab) before the next. This table is updated, committed, and pushed as each
feature lands. Detail: [IMPLEMENTATION-3.13.99.md](IMPLEMENTATION-3.13.99.md). Decisions:
[OWNER-DECISIONS.md](OWNER-DECISIONS.md).

**Progress: 22 / 52 features lab-green** (feature 50 Frond compiler DEFERRED to 3.13.100 fast-follow, owner call 2026-08-12). Done: Phase 1 + Phase 2 + Phase 3 (9-13) + 17. In progress: 18 (Phase 4 ORM fields, next).

Status: DONE = lab-green all four (independently re-verified) . WIP = in progress . TODO = not started.
Lab column = per-framework test counts py/php/ruby/node in the consolidated green run.

## Phase 1 - security cluster

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 37 | CSRF protection | DONE | 59/56/44/46 | 3249495 / 001f966a / dbcd6a2 / cc6642a |
| 127 | Dev-admin security | DONE | 9/9/9/9 | 41b3aeb / 698e6a6 / ab06e5c / 97d4f22 |
| 41 | Static assets | DONE | 40/43/30/52 | c51c686 / c422f4b / e24a3fa / 77592ad |
| 43 | Request-id | DONE | 9/9/9/11 | 1d324d5 / 1d9d607 / 1bfc060 / 0828904 |
| 53 | Frond tag confinement | DONE | 5/5/5/5 | f858c11 / 42a0723 / a1ff8af / 22e6057 |
| 14 | Mongo mass-delete guard | DONE | 7/7/7/7 | 3315d1c / baf1af5 / d45c119 / ad62c2d |
| 36 | Security headers | DONE | 4/4/4/5 | bfc1597 / 853c47c / 6e44205 / aa73dbf |
| 129 | Port takeover safety | DONE | 5/16/5/5 | fdd7d86 / 40cd4c0 / 75f78ae / ae7332d |
| 126 | Debug overlay redaction | DONE | 22/22/22/48 | 7b460ea / df860de / 93c1e06 / f9afed3 |
| 132 | Inline testing | DONE | 61/8/48/59 | d854b9d / e797e9b / e477caf / e4202b5 |

## Phase 2 - data-loss / silent no-op

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 44 | File upload | DONE | 6/6/6/8 | 9fd483c / a6bb4b3 / dab136f / 5a9bdbe |
| 47 | Background tasks | DONE | 6/6/6/7 | 1d4fb4d / 9f62bde / 32f9539 / fe6e069 |
| 25 | ORM result caching | DONE | 8/8/8/8 | 9329fbc / d6fca93 / cdbeee3 / c472089 |
| 16 | Database next-id | DONE | 5/5/5/5 | f735e6b / 833cceb / d22c507 / 3fbf63b |
| 7 | SQL translator | DONE | 6/6/6/6 | 4fbe199 / d386bcd / 216290f / 93b5c1e |
| 14b | Mongo truncate() parity | DONE | 9/9/9/9 | 079873e / 7ac2c0b / abc5aa5 / 5d2afea |

## Phase 3 - DB providers

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 9 | PostgreSQL provider | DONE | 13/13/13/13 | f67e73d / 2258bbb / 09e254a / 5fe1778 |
| 10 | MySQL provider | DONE | 12/10/10/10 | 99487c9 / 1551c9d / af1ee43 / 979b1c0 |
| 11 | MSSQL provider | DONE | 9/7/8/7 | 4491cf8 / 1deb9d6 / 937a35c / 2de3fa4 |
| 12 | Firebird provider | DONE | 11/10/28/10 | de441c5 / 27dd66e / 286cd03 / 47d3d4e |
| 13 | ODBC provider | DONE | 11/10/10/11 | a3c89bd / ae6e83b / 6c3c8ab / ceef906 |

## Phase 4 - ORM / validation / correctness

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 17 | ORM base class | DONE | 5/5/5/5 | a18da9d / 4e454f2 / bbf35b6 / 39931bd |
| 18 | ORM fields | TODO | - | - |
| 19 | Input validation | TODO | - | - |
| 20 | Soft delete | TODO | - | - |
| 21 | Relationships | TODO | - | - |
| 22 | Imperative relationships | TODO | - | - |
| 23 | Scopes | TODO | - | - |
| 24 | Paginated results | TODO | - | - |
| 26 | Instance loading | TODO | - | - |
| 27 | AutoCrud | TODO | - | - |
| 28 | Seeder / fake data | TODO | - | - |
| 29 | Request model | TODO | - | - |
| 15 | Migrations | TODO | - | - |

## Phase 5 - HTTP / dev-tooling parity

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 40 | Compression / ETag | TODO | - | - |
| 42 | Error pages | TODO | - | - |
| 45 | Swagger / OpenAPI | TODO | - | - |
| 32 | Route groups | TODO | - | - |
| 46 | Default landing page | TODO | - | - |
| 128 | Dual test port | TODO | - | - |
| 130 | Dynamic version | TODO | - | - |
| 131 | Test client | TODO | - | - |
| 133 | Carbonah benchmarks | TODO | - | - |

## Phase 6 - Frond

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 48/49 | Lexer/parser positions | TODO | - | - |
| 50 | Frond compiler (ruby+node) | DEFERRED -> 3.13.100 | - | fast-follow (owner call 2026-08-12) |
| 52 | Frond filters | TODO | - | - |
| 54 | Frond tests | TODO | - | - |
| 55 | Frond functions | TODO | - | - |
| 56 | Frond extensibility | TODO | - | - |
| 57 | Auto-escaping | TODO | - | - |
| 58 | Sandboxing | TODO | - | - |
| 59 | Template caching | TODO | - | - |
| 60 | Fragment caching | TODO | - | - |
