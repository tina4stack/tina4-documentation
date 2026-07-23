# Chapter 37: Complete Feature List

Tina4 Node.js ships **97 built-in features** with zero third-party runtime dependencies. This page is the "is it already in the box?" reference. Before you reach for a library, check here first: if Tina4 ships it, use the built-in.

Every feature below is present in all four Tina4 frameworks - Python, PHP, Ruby, and Node.js - with identical behaviour, JSON shapes, environment variables, and error messages. Only the method names change to fit each language; in Node.js they are camelCase. The "instead of" note in each row names the common dependency the built-in replaces, so you never add it.

## Core HTTP

| Feature | What it does / instead of |
|---------|---------------------------|
| HTTP server (zero-dep, dev and production) | Serves HTTP with no runtime dependencies; `serve --production` auto-tunes. Instead of gunicorn/uvicorn config, Apache with mod_php, Puma tuning, or Express |
| Routing (path and typed params, wildcards) | `get`/`post` with `{id:int}` and `{...slug}` patterns. Instead of a router library |
| Route groups | Group a prefix with shared auth and middleware |
| Request object | Parsed body, query, headers, cookies, and files. Instead of body-parser |
| Response object | JSON, HTML, redirect, file, and stream, plus auto-serialised models |
| Middleware pipeline | Before and after hooks, short-circuit, per-route |
| CORS middleware | Built-in preflight and headers. Instead of a cors package |
| Rate limiting middleware | Built-in throttle. Instead of express-rate-limit or rack-attack |
| Static file serving (cache-control revalidation) | Serves the public directory with ETag and 304. Instead of serve-static |
| Health check endpoint | `/health` and `/__health`, returns 503 on broken files |
| Graceful shutdown | Clean SIGTERM and SIGINT drain |
| SSE and streaming responses | Streams from a generator, hardened. Instead of an SSE library |
| Convention auto-discovery (routes, models, seeds) | File location is configuration. Instead of manual registration |

## Database

| Feature | What it does / instead of |
|---------|---------------------------|
| Multi-driver database abstraction | SQLite, PostgreSQL, MySQL, MSSQL, Firebird, and ODBC through one URL. Instead of per-driver glue |
| Connection pooling | Round-robin connections with a pool size |
| Query builder (with `to_mongo`) | Fluent JOIN, aggregate, and GROUP BY, plus a NoSQL bridge. Instead of a query-builder library |
| ORM (active record) | Models with save, find, and where. Instead of SQLAlchemy, Eloquent, ActiveRecord, or Prisma |
| ORM relationships and eager loading | has_many, has_one, and belongs_to, with `include` |
| Soft deletes | An is_deleted flag with restore |
| Migrations (with auto-migrate on startup) | SQL-file migrations, per-engine DDL. Instead of Alembic or Phinx |
| Race-safe sequences | Atomic id generation across engines |
| SQL translator | Cross-engine dialect rewrite (LIMIT, ROWS, TOP, ILIKE, CONCAT) |
| Query cache (request and persistent) | Dedupe reads; opt-in persistent cache with backends |
| DocStore (Mongo-style, SQLite fallback) | A pymongo-style API with a zero-config local store. Instead of a Mongo dependency in dev |
| Seeder and FakeData | Deterministic fake data and bulk seeding. Instead of faker and factory libraries |
| Auto-CRUD REST generator | REST endpoints from a model |
| Validator | Request and body validation. Instead of a validation library |

## Authentication and Sessions

| Feature | What it does / instead of |
|---------|---------------------------|
| JWT authentication | Token issue and verify, RS256 and HS256. Instead of pyjwt, firebase-jwt, or jsonwebtoken |
| Password hashing (PBKDF2) | Hash and check, timing-safe. Instead of bcrypt or argon libraries |
| API-key authentication | Key validation with header fallbacks |
| Sessions (file, redis, valkey, mongo, database) | Pluggable backends that degrade loudly. Instead of a session library |

## Templates and Frontend

| Feature | What it does / instead of |
|---------|---------------------------|
| Frond template engine | Twig-compatible, with live blocks, a sandbox, and fragment caching. Instead of Jinja, Twig, ERB, or Handlebars |
| SCSS compiler | Built-in SCSS to CSS. Instead of a sass dependency |
| HtmlElement builder | Programmatic HTML, XSS-safe |
| tina4-js and frond.js frontend | A reactive frontend with AJAX and WebSocket helpers, shipped. Instead of React or Vue for admin UIs |

## Caching

| Feature | What it does / instead of |
|---------|---------------------------|
| Response cache | GET cache middleware with TTL and an X-Cache header |
| Unified cache backends | memory, file, redis, valkey, memcached, mongodb, and database, with a file fallback |

## Background and Messaging

| Feature | What it does / instead of |
|---------|---------------------------|
| Queue (lite, RabbitMQ, Kafka, Mongo) | Jobs with retry to dead-letter and a visibility timeout. Instead of Celery, Bull, or Sidekiq |
| Background tasks | Periodic in-loop callbacks, no threads |
| Service runner | Cron, daemon, and interval services |
| Events (observer) | on, emit, once, and off, with priorities. Instead of an event-emitter library |
| Messenger (SMTP and IMAP) | Send and read mail, fail-loud IMAP. Instead of nodemailer or mail gems |

## APIs and Protocols

| Feature | What it does / instead of |
|---------|---------------------------|
| API HTTP client | get, post, upload, download, retry, cookie jar, redirect-safe. Instead of requests, guzzle, faraday, or axios |
| Swagger and OpenAPI | A 3.0.3 spec from routes with `$ref` schemas and a UI. Instead of a swagger-gen dependency |
| GraphQL | A zero-dep engine with ORM auto-schema and a depth guard. Instead of graphql-core or graphql-js |
| WSDL and SOAP | SOAP 1.1 with auto-WSDL, DTD-rejecting |
| WebSocket (backplane, rooms, per-route auth) | An RFC 6455 server with Redis and NATS scale-out. Instead of ws, socket.io, or actioncable |
| Realtime collab (WebRTC calls, chat, files) | Signaling, chat, and file-transfer domain |
| MCP server (Streamable HTTP and legacy SSE) | A built-in AI tool server |

## Internationalisation

| Feature | What it does / instead of |
|---------|---------------------------|
| i18n and localization | JSON locales, interpolation, and fallback. Instead of an i18n library |

## Developer Experience

| Feature | What it does / instead of |
|---------|---------------------------|
| CLI (serve, migrate, generate, test, doctor, setup, deploy) | One toolchain. Instead of make plus scripts |
| Dev toolbar and dashboard | A route, request, query, queue, mailbox, and WebSocket inspector |
| Dev mailbox | Captures outbound mail in dev. Instead of mailhog |
| Error overlay | A rich stack-trace page in dev |
| Dev reload (WebSocket-primary hot reload) | Instant browser reload on change |
| Structured logging | Levels, JSON and human output, dev and prod file gating |
| Metrics | Built-in request and runtime metrics |
| Inline testing framework | Assertions attached to functions or described in suites |
| TestClient (xUnit plus HTTP surface) | In-process requests through the real front controller |
| Live API index and docs search | Reflects real signatures; a doc-drift detector |
| AI context scaffolding | Installs context for 7 AI tools |
| DI container | Transient and singleton registrations |
| `.env` loader and env helpers | Precedence-correct env loading |
| Gallery (interactive examples) | 7 live examples under `/__dev/` |
| Plan, ProjectIndex, and Feedback | An in-dashboard AI developer surface |

## Security and Request Handling

| Feature | What it does / instead of |
|---------|---------------------------|
| CSRF protection | A form token plus validating middleware |
| Security-headers middleware | CSP, X-Frame-Options, and Referrer-Policy. Instead of helmet |
| Request-logging middleware | Structured access logs, on by default in dev |
| Multipart file uploads | Raw file bytes on the request. Instead of multer or multipart libraries |
| Named and multiple database connections | Bind a database under a name and point a model at it |
| Project code and doc search index | SQLite FTS5 over the project |
| Broken-file tracker | `data/.broken` sentinels, health returns 503 |
| Dual-port dev server | A stable AI port at base+1000 |
| Interactive REPL console | An app-context REPL |
| Pluggable file-storage backends | Local and S3 storage. Instead of an S3 SDK for the common path |
| MongoDB as a database driver | Mongo through the same SQL-style API |
| Cookie API | Response cookies with HttpOnly, SameSite, and Secure |
| Response compression and ETag | gzip plus validators, automatically |

## Additional Capabilities

| Feature | What it does / instead of |
|---------|---------------------------|
| Doc-truth checker | A drift detector for docs versus code |
| File and attachment responses | Download or inline file responses |
| Queue job handle | An explicit ack, nack, and retry object |
| Swagger security-scheme and schema registry | Per-route security plus reusable `$ref` schemas |
| Credential-safe database URL parser | Parses `driver://user:pass@host/db` safely |
| Docker image build command | Generates a Dockerfile |
| Route table inspector | Lists the route table from the CLI |
| Self-describing CLI manifest | Emits the command set as JSON |
| Realtime chat domain models | Chat, message, and presence models |
| Firebird driver | Firebird engine support (PHP also has a PDO fallback) |
| Legacy env-var migration checker | Warns on pre-3.12 un-prefixed variables |
| Instant HTML CRUD UI | A searchable, paginated admin table from SQL |
| Secure-by-default write routes | POST, PUT, PATCH, and DELETE require auth unless marked public |
| Template auto-routing and SPA index | Templates map to routes; an SPA index fallback |
| HTTP/1.1 method conformance | Auto-HEAD, OPTIONS 204, and 405 with Allow |
| Code generators | Generate models, routes, migrations, and middleware |
| Built-in Tina4 CSS bundle | Bootstrap-compatible CSS, shipped. Instead of a CSS-framework dependency |
| In-dashboard AI agent and supervised sessions | AI chat plus supervised runs in the dashboard |

## IoT and Device Messaging

| Feature | What it does / instead of |
|---------|---------------------------|
| MQTT 3.1.1 client (QoS 0/1, TLS, retained, Last Will) | Pub/sub to any broker (Mosquitto, EMQX, HiveMQ, AWS IoT): publish, subscribe, and consume, with retained messages, a Last Will, and a per-client TLS trust store. QoS 2 is refused loudly, never silently downgraded. Instead of paho-mqtt, php-mqtt, ruby-mqtt, or mqtt.js |

## Cross-Language Parity

The same 97 features ship in every Tina4 framework. Only the package and the method-name style differ:

| Framework | Language | Install |
|-----------|----------|---------|
| tina4-python | Python 3.12+ | `pip install tina4-python` |
| tina4-php | PHP 8.2+ | `composer require tina4stack/tina4php` |
| tina4-ruby | Ruby 3.1+ | `gem install tina4ruby` |
| tina4-nodejs | Node.js 22+ | `npm install tina4-nodejs` |

Ruby ships one extra, language-native feature: ERB as a second template engine alongside Frond, for 98 in total. Frond is the cross-framework engine, so nothing is missing anywhere else.

## What Parity Means

- A route written in one framework maps directly to the others; only the syntax changes.
- A Frond template renders the same under any of the four.
- A test written against one framework's test client ports line-for-line to the others.
- The same `TINA4_*` environment variables are honoured everywhere, with the same meaning.

## Verification

Every feature is backed by real tests in all four frameworks, run against real dependencies - no mocks. A feature is not shipped until its tests pass in Python, PHP, Ruby, and Node.js, and a bug fix lands in all four before it closes.

## What Is Not in Tina4

Tina4 stays deliberately small. It carries zero third-party runtime dependencies, so there is no large tree to audit or update. The backends for queues, cache, sessions, and mail are configuration choices, not vendor lock-in: point an environment variable at Redis, RabbitMQ, or MongoDB and the same code keeps working. The goal is a framework you can read in a weekend and rely on for years.
