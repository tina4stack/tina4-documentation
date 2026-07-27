# tina4-ruby v3.0 — Gameplan

## Current State (v2)
- **Strong:** GraphQL, WebSocket, WSDL, Session (3 backends), Localization, CRUD, API client (stdlib Net::HTTP), ORM, Migrations with rollback (.down.sql), CLI (Thor-based), Seeder, 5 database drivers
- **Weak:** No soft delete, no MongoDB driver, no ODBC, no route caching, no rate limiting, no structured logging, no queue beyond lite backend, no email
- **Third-party to remove:** Thor (CLI), twig-equivalent template engine if using one

## v3 Branch Strategy
- Create `v3` branch from current `main`
- v2 continues independently
- v3 development in monorepo under `ruby/`

## Implementation Phases

### Phase 1: Foundation (Zero-Dep Core)
1. [ ] **DotEnv parser** — parse `.env` files natively
2. [ ] **Structured logger** — JSON (prod) / text (dev), request ID tracking
3. [ ] **Database adapter interface** — standardize contract across all drivers
4. [ ] **SQLite adapter** — using `sqlite3` gem (C binding, standard)
5. [ ] **DATABASE_URL parser** — auto-detect driver from URL scheme
6. [ ] **Router refactor** — add route caching, route model binding, standardize response types
7. [ ] **Middleware pipeline** — standardize hook points
8. [ ] **Health check endpoint** — auto-registered `/health`
9. [ ] **Graceful shutdown** — `Signal.trap` for SIGTERM/SIGINT
10. [ ] **CORS middleware** — declarative config from env vars
11. [ ] **Rate limiter** — in-memory + database-backed
12. [ ] **CLI rewrite** — replace Thor with native `OptionParser` (zero-dep)

### Phase 2: ORM & Data Layer
13. [ ] **ORM refactor** — SQL-first, standardize API surface
14. [ ] **Soft delete** — `deleted_at` field, auto-filtering, `restore`, `force_delete`, `with_trashed`
15. [ ] **Relationships** — `has_one`, `has_many` with eager loading
16. [ ] **Scopes** — reusable query filters on models
17. [ ] **Field mapping** — NEW, map Ruby property names to column names
18. [ ] **Paginated results** — standardized `PaginatedResult` format
19. [ ] **Result caching** — configurable per-query cache
20. [ ] **Input validation** — from field definitions
21. [ ] **PostgreSQL adapter** — using `pg` gem
22. [ ] **MySQL adapter** — using `mysql2` gem
23. [ ] **MSSQL adapter** — using `tiny_tds` gem
24. [ ] **Firebird adapter** — using `fb` gem
25. [ ] **ODBC adapter** — NEW, using `ruby-odbc` gem
26. [ ] **Migrations** — keep existing rollback, align API

### Phase 3: Frond Template Engine
27. [ ] **Lexer** — tokenize Frond syntax
28. [ ] **Parser** — build AST
29. [ ] **Compiler** — compile to Proc/lambda
30. [ ] **Runtime** — execute with context
31. [ ] **All filters** — implement full filter set (~55 filters)
32. [ ] **All tags** — full tag set
33. [ ] **Tests** — all type tests
34. [ ] **Functions** — all built-in functions
35. [ ] **Extensibility API** — `add_filter`/`add_function`/`add_global`/`add_test`/`add_tag`
36. [ ] **Auto-escaping** — html/js/css/url strategies
37. [ ] **Sandboxing** — restrict access
38. [ ] **Template caching** — in-memory compiled cache with dev invalidation
39. [ ] **Fragment caching** — `{% cache %}` tag

### Phase 4: Auth & Sessions
40. [ ] **JWT implementation** — using stdlib `openssl`
41. [ ] **Session: file backend** — keep existing
42. [ ] **Session: Redis backend** — keep existing
43. [ ] **Session: Memcache backend** — NEW, using `dalli` gem
44. [ ] **Session: MongoDB backend** — keep existing
45. [ ] **Session: database backend** — NEW, using connected DB adapter
46. [ ] **Swagger/OpenAPI** — keep existing, standardize output

### Phase 5: Extended Features
47. [ ] **Queue (DB-backed)** — rewrite lite backend to use connected database
48. [ ] **SCSS compiler** — build native Ruby SCSS parser
49. [ ] **API client** — keep existing Net::HTTP (stdlib), align API
50. [ ] **GraphQL** — keep existing zero-dep parser, align API
51. [ ] **WebSocket** — keep existing Rack integration, align API
52. [ ] **WSDL/SOAP** — keep existing, align API
53. [ ] **Localization** — keep existing, align with JSON translation file format
54. [ ] **Email/Messenger** — NEW, using stdlib `net/smtp`
55. [ ] **Seeder/FakeData** — keep existing, align API
56. [ ] **Auto-CRUD** — keep existing, standardize endpoints
57. [ ] **Event/listener system** — NEW, simple observer pattern

### Phase 6: CLI & DX
58. [ ] **CLI: init** — scaffold project with standardized structure
59. [ ] **CLI: serve** — keep existing (Puma preferred)
60. [ ] **CLI: migrate** — keep existing with rollback
61. [ ] **CLI: seed** — keep existing
62. [ ] **CLI: test** — keep existing
63. [ ] **CLI: routes** — keep existing
64. [ ] **Debug overlay** — inject shared debug overlay in dev mode
65. [ ] **frond.js** — copy shared JS to `src/public/js/`

### Phase 7: Testing
66. [ ] **Implement all shared test specs**
67. [ ] **Frond tests** — 20 positive + 5 negative
68. [ ] **ORM tests** — full coverage
69. [ ] **Database tests** — per driver
70. [ ] **Router tests** — patterns, middleware, caching, model binding
71. [ ] **Auth tests** — JWT, session backends
72. [ ] **Queue tests** — enqueue/dequeue/retry/failure
73. [ ] **Integration tests** — end-to-end HTTP
74. [ ] **Performance benchmarks**

## Naming Conventions (Ruby Best Practice)
- Classes: `PascalCase` — `DatabaseAdapter`, `UserModel`, `FrondEngine`
- Methods: `snake_case` — `fetch_one`, `soft_delete`, `has_many`
- Constants: `UPPER_SNAKE` — `DATABASE_URL`, `TINA4_DEBUG`
- Files: `snake_case.rb` — `database_adapter.rb`, `frond_engine.rb`
- Modules: `Tina4::` — `Tina4::ORM`, `Tina4::Database`, `Tina4::Frond`
- Predicates: `?` suffix — `persisted?`, `soft_deleted?`, `valid?`
- Mutators: `!` suffix — `save!`, `delete!` (raise on failure)

## Dependencies (v3)
### Zero (built from scratch)
- Frond, JWT, SCSS, DotEnv, Queue, Logger, Rate limiter, CLI, Email, Event system, Cache

### Ruby stdlib only
- `openssl`, `json`, `net/http`, `net/smtp`, `uri`, `optparse`, `fileutils`, `time`, `socket`

### Database drivers (optional gems)
- `sqlite3` (SQLite)
- `pg` (PostgreSQL)
- `mysql2` (MySQL)
- `tiny_tds` (MSSQL)
- `fb` (Firebird)
- `ruby-odbc` (ODBC)

### Session backends (optional gems)
- `redis` (Redis)
- `dalli` (Memcache)
- `mongo` (MongoDB)
