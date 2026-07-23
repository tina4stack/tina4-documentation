# Tina4 built-in feature reference (all 4 languages)

The canonical "is it already in the box?" table. Before you add a third-party library, check here:
if Tina4 already ships it, use the built-in. 97 rows; 96 are present in all four frameworks, 1 is
Ruby-native (ERB). Source of truth for the per-framework feature-list doc pages (they regenerate
from this file so they cannot drift into three different numbers again). Companion to
`feature-recount.md` (the audit evidence) and `feature-union-table.md` (the count decision).

## How to read the language columns

- Y = shipped and public in that framework (audited 2026-07-23 with file:line evidence, each
  framework booted and hit over the wire, not only grepped).
- Entry points are shown in **Python-master naming**. The same concept has an idiomatic name in
  each language: **Python/Ruby** snake_case (`get_token`), **PHP/Node** camelCase (`getToken`),
  Ruby under the `Tina4::` namespace. Only the name changes; behaviour, JSON, env vars and error
  messages are identical by mandate.
- "Instead of" names the common third-party dependency the built-in replaces, so you do not add it.

## Core HTTP (13)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 1 | HTTP server (zero-dep, dev + production) | Serves HTTP with no runtime deps; `serve --production` auto-tunes. Instead of gunicorn/uvicorn-config, Apache+mod_php, Puma tuning, Express | Y | Y | Y | Y |
| 2 | Routing (path/typed params, wildcards) | `@get`/`@post` + `{id:int}`/`{...slug}`. Instead of a router lib | Y | Y | Y | Y |
| 3 | Route groups | `Router.group(prefix)` with shared auth/middleware | Y | Y | Y | Y |
| 4 | Request object | Parsed body, query, headers, cookies, files. Instead of body-parser | Y | Y | Y | Y |
| 5 | Response object | JSON/HTML/redirect/file/stream + auto-serialize models | Y | Y | Y | Y |
| 6 | Middleware pipeline | before_/after_ hooks, short-circuit, per-route | Y | Y | Y | Y |
| 7 | CORS middleware | Built-in preflight + headers. Instead of cors | Y | Y | Y | Y |
| 8 | Rate limiting middleware | Built-in throttle. Instead of express-rate-limit/rack-attack | Y | Y | Y | Y |
| 9 | Static file serving (cache-control revalidation) | Serves `public/` with ETag/304. Instead of serve-static | Y | Y | Y | Y |
| 10 | Health check endpoint | `/health` + `/__health`, 503 on broken files | Y | Y | Y | Y |
| 11 | Graceful shutdown | Clean SIGTERM/SIGINT drain | Y | Y | Y | Y |
| 12 | SSE / streaming responses | `response.stream(generator)`, hardened. Instead of an SSE lib | Y | Y | Y | Y |
| 13 | Convention auto-discovery (routes/models/seeds) | File location IS config. Instead of manual registration | Y | Y | Y | Y |

## Database (14)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 14 | Multi-driver DB abstraction | SQLite/PostgreSQL/MySQL/MSSQL/Firebird/ODBC via one URL. Instead of per-driver glue | Y | Y | Y | Y |
| 15 | Connection pooling | `pool=N` round-robin connections | Y | Y | Y | Y |
| 16 | Query Builder (+ `to_mongo`) | Fluent JOIN/aggregate/GROUP BY; NoSQL bridge. Instead of a QB lib | Y | Y | Y | Y |
| 17 | ORM (Active Record) | Models, save/find/where. Instead of SQLAlchemy/Eloquent/ActiveRecord/Prisma | Y | Y | Y | Y |
| 18 | ORM relationships + eager loading | has_many/has_one/belongs_to, `include=` | Y | Y | Y | Y |
| 19 | Soft deletes | `soft_delete` + is_deleted, restore() | Y | Y | Y | Y |
| 20 | Migrations (+ auto-migrate on startup) | SQL-file migrations, per-engine DDL. Instead of Alembic/Phinx | Y | Y | Y | Y |
| 21 | Race-safe sequences (`get_next_id`) | Atomic id generation across engines | Y | Y | Y | Y |
| 22 | SQL translator | Cross-engine dialect rewrite (LIMIT/ROWS/TOP/ILIKE/CONCAT) | Y | Y | Y | Y |
| 23 | Query cache (request + persistent) | Dedupe reads; opt-in persistent w/ backends | Y | Y | Y | Y |
| 24 | DocStore (Mongo-style, SQLite fallback) | pymongo-style API, zero-config local. Instead of a Mongo dep in dev | Y | Y | Y | Y |
| 25 | Seeder / FakeData | Deterministic fake data + bulk seeding. Instead of faker + factory libs | Y | Y | Y | Y |
| 26 | Auto-CRUD REST generator | REST endpoints from a model | Y | Y | Y | Y |
| 27 | Validator | Request/body validation. Instead of a validation lib | Y | Y | Y | Y |

## Auth and sessions (4)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 28 | JWT authentication | get_token/valid_token, RS256/HS256. Instead of pyjwt/firebase-jwt/jsonwebtoken | Y | Y | Y | Y |
| 29 | Password hashing (PBKDF2) | hash_password/check_password, timing-safe. Instead of bcrypt/argon libs | Y | Y | Y | Y |
| 30 | API-key authentication | validate_api_key, header fallbacks | Y | Y | Y | Y |
| 31 | Sessions (file/redis/valkey/mongo/db) | Pluggable backends, degrade-loud. Instead of a session lib | Y | Y | Y | Y |

## Templates and frontend (4)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 32 | Frond template engine | Twig-compatible, live blocks, sandbox, fragment cache. Instead of Jinja/Twig/ERB/Handlebars | Y | Y | Y | Y |
| 33 | SCSS compiler | Built-in SCSS to CSS. Instead of a sass dep | Y | Y | Y | Y |
| 34 | HtmlElement builder | Programmatic HTML, XSS-safe | Y | Y | Y | Y |
| 35 | tina4-js / frond.js frontend | Reactive frontend + AJAX/WS helpers, shipped. Instead of React/Vue for admin UIs | Y | Y | Y | Y |

## Caching (2)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 36 | Response cache | GET cache middleware, TTL, X-Cache | Y | Y | Y | Y |
| 37 | Unified cache backends | memory/file/redis/valkey/memcached/mongodb/database, file fallback | Y | Y | Y | Y |

## Background and messaging (5)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 38 | Queue (lite/RabbitMQ/Kafka/Mongo) | Jobs, retry to dead-letter, visibility timeout. Instead of Celery/Bull/Sidekiq | Y | Y | Y | Y |
| 39 | Background tasks | Periodic in-loop callbacks, no threads | Y | Y | Y | Y |
| 40 | Service runner | Cron/daemon/interval services | Y | Y | Y | Y |
| 41 | Events (observer) | on/emit/once/off, priorities. Instead of an event-emitter lib | Y | Y | Y | Y |
| 42 | Messenger (SMTP/IMAP) | Send + read mail, fail-loud IMAP. Instead of nodemailer/mail gems | Y | Y | Y | Y |

## APIs and protocols (7)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 43 | Api HTTP client | get/post/upload/download, retry, cookie jar, redirect-safe. Instead of requests/guzzle/faraday/axios | Y | Y | Y | Y |
| 44 | Swagger / OpenAPI | 3.0.3 spec from routes + `$ref` schemas, UI. Instead of a swagger gen dep | Y | Y | Y | Y |
| 45 | GraphQL | Zero-dep engine, ORM auto-schema, depth guard. Instead of graphql-core/graphql-js | Y | Y | Y | Y |
| 46 | WSDL / SOAP | SOAP 1.1 + auto-WSDL, DTD-rejecting | Y | Y | Y | Y |
| 47 | WebSocket (backplane, rooms, per-route auth) | RFC 6455 server, Redis/NATS scale-out. Instead of ws/socket.io/actioncable | Y | Y | Y | Y |
| 48 | Realtime collab (WebRTC calls/chat/files) | Signaling + chat + file transfer domain | Y | Y | Y | Y |
| 49 | MCP server (Streamable HTTP + legacy SSE) | Built-in AI tool server | Y | Y | Y | Y |

## Internationalisation (1)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 50 | i18n / localization | JSON locales, interpolation, fallback. Instead of an i18n lib | Y | Y | Y | Y |

## Developer experience (15)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 51 | CLI (serve/migrate/generate/test/doctor/setup/deploy) | One toolchain. Instead of make + scripts | Y | Y | Y | Y |
| 52 | Dev toolbar + dashboard (DevAdmin) | Route/request/query/queue/mailbox/WS inspector | Y | Y | Y | Y |
| 53 | Dev mailbox | Captures outbound mail in dev. Instead of mailhog | Y | Y | Y | Y |
| 54 | Error overlay | Rich stack-trace page in dev | Y | Y | Y | Y |
| 55 | Dev reload (WebSocket-primary hot reload) | Instant browser reload on change | Y | Y | Y | Y |
| 56 | Structured logging (Log) | Levels, JSON/human, dev/prod file gating | Y | Y | Y | Y |
| 57 | Metrics | Built-in request/runtime metrics | Y | Y | Y | Y |
| 58 | Inline testing framework | `@tests`/describe-it assertions | Y | Y | Y | Y |
| 59 | TestClient (xUnit + HTTP surface) | In-process requests through the real front controller | Y | Y | Y | Y |
| 60 | Live API index / docs search | Reflects real signatures; doc drift detector | Y | Y | Y | Y |
| 61 | AI context scaffolding | Installs context for 7 AI tools | Y | Y | Y | Y |
| 62 | DI container | Transient + singleton registrations | Y | Y | Y | Y |
| 63 | `.env` loader + env helpers | Precedence-correct env loading | Y | Y | Y | Y |
| 64 | Gallery (interactive examples) | 7 live examples at `/__dev/` | Y | Y | Y | Y |
| 65 | Plan / ProjectIndex / Feedback | In-dashboard AI developer surface | Y | Y | Y | Y |

## Security and request handling (Section B, 13)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 66 | CSRF protection | Form token + validating middleware | Y | Y | Y | Y |
| 67 | Security-headers middleware | CSP, X-Frame-Options, Referrer-Policy. Instead of helmet | Y | Y | Y | Y |
| 68 | Request-logging middleware | Structured access logs, dev-default | Y | Y | Y | Y |
| 69 | Multipart file uploads | `request.files`, raw bytes. Instead of multer/multipart libs | Y | Y | Y | Y |
| 70 | Named / multiple DB connections | bind_database(db, name=) + per-model `_db` | Y | Y | Y | Y |
| 71 | Project code/doc search index | SQLite FTS5 over the project | Y | Y | Y | Y |
| 72 | Broken-file tracker | `data/.broken` sentinels, /health 503 | Y | Y | Y | Y |
| 73 | Dual-port dev server | Stable AI port at base+1000 | Y | Y | Y | Y |
| 74 | Interactive REPL console | App-context REPL | Y | Y | Y | Y |
| 75 | Pluggable file-storage backends | Local / S3 storage. Instead of an S3 SDK for the common path | Y | Y | Y | Y |
| 76 | MongoDB as a database driver | Mongo via the same SQL-ish API | Y | Y | Y | Y |
| 77 | Cookie API | `response.cookie`, HttpOnly/SameSite/Secure | Y | Y | Y | Y |
| 78 | Response compression + ETag | gzip + validators automatically | Y | Y | Y | Y |

## Additional capabilities (Section C, 19)

| # | Feature | What it does / instead of | Py | PHP | Rb | Node |
|---|---------|---------------------------|----|-----|----|----|
| 79 | Doc-truth checker | `check_docs`/`sync_docs` drift detector | Y | Y | Y | Y |
| 80 | File / attachment responses | `response.file(...)` download/inline | Y | Y | Y | Y |
| 81 | Queue job handle | Explicit ack/nack/retry object | Y | Y | Y | Y |
| 82 | Swagger security-scheme + schema registry | Per-route security + reusable `$ref` schemas | Y | Y | Y | Y |
| 83 | Credential-safe DB URL parser | Parses `driver://user:pass@host/db` safely | Y | Y | Y | Y |
| 84 | Docker image build command | `deploy docker` generates Dockerfile | Y | Y | Y | Y |
| 85 | Route table inspector | `routes` command lists the table | Y | Y | Y | Y |
| 86 | Self-describing CLI manifest | `commands --json` | Y | Y | Y | Y |
| 87 | Realtime chat domain models | Chat/message/presence models | Y | Y | Y | Y |
| 88 | Firebird driver | Firebird engine support (PHP also has a PDO fallback) | Y | Y | Y | Y |
| 89 | Legacy env-var migration checker | Warns on pre-3.12 un-prefixed vars | Y | Y | Y | Y |
| 90 | Instant HTML CRUD UI | Searchable/paginated admin table from SQL | Y | Y | Y | Y |
| 91 | Second template engine | ERB alongside Frond -- **Ruby-native** (Frond is the cross-framework engine, row 32) | . | . | Y | . |
| 92 | Secure-by-default write routes | POST/PUT/PATCH/DELETE require auth unless `noauth` | Y | Y | Y | Y |
| 93 | Template auto-routing + SPA index | Templates map to routes; SPA index fallback | Y | Y | Y | Y |
| 94 | HTTP/1.1 method conformance | Auto-HEAD, OPTIONS 204, 405 + Allow | Y | Y | Y | Y |
| 95 | Code generators | `generate model/route/migration/middleware` | Y | Y | Y | Y |
| 96 | Built-in Tina4 CSS bundle | Bootstrap-compatible CSS, shipped. Instead of a CSS framework dep | Y | Y | Y | Y |
| 97 | In-dashboard AI agent + supervised sessions | AI chat + supervised runs in DevAdmin | Y | Y | Y | Y |

## Totals

- **97 rows.** 96 present in all four; **1 Ruby-native** (row 91, ERB -- ERB is a Ruby technology,
  Frond is the cross-framework engine at row 32, so there is nothing to port).
- Per framework: Python 96, PHP 96, Ruby 97, Node 96. The published family count is **97**.
- PHP also ships a Firebird PDO fallback (row 88) as a language-specific extra; it is not a separate
  cross-framework feature, so it is not its own row.
