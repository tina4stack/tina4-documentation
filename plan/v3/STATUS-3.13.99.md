# 3.13.99 implementation status

First-pass release. One feature fully completed in all four frameworks (real no-mock tests + shared
fixture, lab-green on the .99 lab) before the next. This table is updated, committed, and pushed as each
feature lands. Detail: [IMPLEMENTATION-3.13.99.md](IMPLEMENTATION-3.13.99.md). Decisions:
[OWNER-DECISIONS.md](OWNER-DECISIONS.md).

**Progress: 2 / 53 features lab-green.** Done: 37, 127. In progress: 41 (next).

Status: DONE = lab-green all four (independently re-verified) . WIP = in progress . TODO = not started.
Lab column = per-framework test counts py/php/ruby/node in the consolidated green run.

## Phase 1 - security cluster

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 37 | CSRF protection | DONE | 59/56/44/46 | 3249495 / 001f966a / dbcd6a2 / cc6642a |
| 127 | Dev-admin security | DONE | 9/9/9/9 | 41b3aeb / 698e6a6 / ab06e5c / 97d4f22 |
| 41 | Static assets | TODO | - | - |
| 43 | Request-id | TODO | - | - |
| 53 | Frond tag traversal | TODO | - | - |
| 14 | Mongo mass-delete guard | TODO | - | - |
| 36 | Security headers | TODO | - | - |
| 129 | Port takeover safety | TODO | - | - |
| 126 | Debug overlay redaction | TODO | - | - |
| 132 | Inline testing | TODO | - | - |

## Phase 2 - data-loss / silent no-op

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 44 | File upload | TODO | - | - |
| 47 | Background tasks | TODO | - | - |
| 25 | ORM result caching | TODO | - | - |
| 16 | Database next-id | TODO | - | - |
| 7 | SQL translator | TODO | - | - |

## Phase 3 - DB providers

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 9 | PostgreSQL provider | TODO | - | - |
| 10 | MySQL provider | TODO | - | - |
| 11 | MSSQL provider | TODO | - | - |
| 12 | Firebird provider | TODO | - | - |
| 13 | ODBC provider | TODO | - | - |

## Phase 4 - ORM / validation / correctness

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 17 | ORM base class | TODO | - | - |
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
| 50 | Frond compiler (ruby+node, BIG - confirm .99 vs fast-follow) | TODO | - | - |
| 52 | Frond filters | TODO | - | - |
| 54 | Frond tests | TODO | - | - |
| 55 | Frond functions | TODO | - | - |
| 56 | Frond extensibility | TODO | - | - |
| 57 | Auto-escaping | TODO | - | - |
| 58 | Sandboxing | TODO | - | - |
| 59 | Template caching | TODO | - | - |
| 60 | Fragment caching | TODO | - | - |
