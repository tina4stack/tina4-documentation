# 3.13.99 implementation status

First-pass release. One feature fully completed in all four frameworks (real no-mock tests + shared
fixture, lab-green on the .99 lab) before the next. This table is updated, committed, and pushed as each
feature lands. Detail: [IMPLEMENTATION-3.13.99.md](IMPLEMENTATION-3.13.99.md). Decisions:
[OWNER-DECISIONS.md](OWNER-DECISIONS.md).

**Progress: 40 / 52 features lab-green + 1 new (MAIL-REDIRECT `TINA4_MAIL_REDIRECT_TO`) done** (feature 50 Frond compiler DEFERRED to 3.13.100 fast-follow, owner call 2026-08-12). Done: Phase 1 + Phase 2 + Phase 3 (9-13) + 17 + 18 + 19 + 20 + 21 + 22 + 23 + 24 + 26 + 27 + 28 + 29 + 15 + MAIL-REDIRECT. **Phase 4 COMPLETE (13/13).** Write-path fixes: WRITE-PATH (Node insert fail-loud) + FIREBIRD-KEY-TYPE (Ruby FB Symbol keys) both DONE. 40 + 42 + 45 + 32 + 46 + 128 DONE. Next: 130 (Phase 5 dynamic version). Phase 5: 7/9.

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
| 18 | ORM fields | DONE | 22/25/23/26 | 6dffcdc / d97a405 / df93891 / 9476369 |
| 19 | Input validation | DONE | 21/38/44/24 | b9fbd7e / cd9ab0d / b427f8b / bf0ea6a |
| 20 | Soft delete | DONE | 14/12/14/12 | 6c190c2 / 3d10d5e / a6ce6ad / f33ed9b |
| 21 | Relationships | DONE | 12/10/10/10 | 2e9a69a / 94ccf77 / df9bbe6 / ad51731 |
| 22 | Imperative relationships | DONE | 5/5/5/5 | 558a000 / 4e1d5df / 236f894 / 4126c4a |
| 23 | Scopes | DONE | 6/6/6/6 | 087826e / 9506410 / 67eb165 / 53b2065 |
| 24 | Paginated results | DONE | 37/31/11/38 | 761873a / a8088ec / c8f8a93 / feaf660 |
| 26 | Instance loading | DONE | 2/2/2/40 | 6095243 / 4807b62 / 1c6d0c5 / 5b5cdcc |
| 27 | AutoCrud | DONE | 6/6/6/6 | 9941536 / 51cd524 / d5cdd95 / 1c4f7cd |
| 28 | Seeder / fake data | DONE | 75/133/155/265 | 80e897b / 6208fbb / 3dc8ee8 / 248a0ee |
| 29 | Request model | DONE | 4/31/36/31 | 7df99c8 / 88edd95 / 776b3c0 / c3acf40 |
| 15 | Migrations | DONE | 93/104/95/37 | 9289017 / 49b404a / 8f8640b / 9e79da6 |

## Phase 5 - HTTP / dev-tooling parity

| # | Feature | Status | Lab (py/php/rb/node) | Commits py / php / rb / node |
|---|---------|--------|----------------------|------------------------------|
| 40 | Compression / ETag | DONE | 6/6/6/6 | 4a389f9 / 5f8e85e / aa2f2d4 / ce7e672 |
| 42 | Error pages | DONE | 14/14/14/54 | 7af21c6 / ac26239 / f2b8d84 / a03d752 |
| 45 | Swagger / OpenAPI | DONE | 13/13/13/13 | 47fbcf2 / e28a08b / d7d1514 / cc8c739 |
| 32 | Route groups | DONE | 5/5/5/5 | 14df0ed / 7b8dc44 / 6eb11bd / 94c6cb0 |
| 46 | Default landing page | DONE | 5/4/4/15 | 77a872a / 196e334 / 430d63a / 246702c |
| 128 | Dual test port | DONE | 4/5/7/7 | f529bf2 / fdf27d3 / 838a0ac / 1fb4d4a |
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
