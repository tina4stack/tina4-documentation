# Chapter 4: Environment Variables

Every piece of Tina4 configuration lives in one file. A `.env` at the root of your project. Seventy-three variables. All optional. All with sensible defaults. This chapter is the complete reference.

## How .env Files Work

A `.env` file is plain text. Key-value pairs. Nothing more.

```env
# This is a comment
DATABASE_URL=sqlite:///data/app.db
TINA4_DEBUG=true
TINA4_PORT=7145

# Blank lines are ignored

# Values with spaces need quotes
TINA4_MAIL_FROM="My App <noreply@example.com>"

# No quotes needed for simple values
JWT_SECRET=my-secret-key-change-in-production
```

### Rules

Six rules govern the format:

1. One variable per line.
2. Format is `KEY=VALUE` -- no spaces around the `=`.
3. Lines starting with `#` are comments.
4. Blank lines are ignored.
5. Values can be wrapped in double quotes (`"value"`) or single quotes (`'value'`).
6. No variable interpolation -- `$OTHER_VAR` is treated as a literal string.

Simple format. No surprises. A developer who has never seen a `.env` file understands it in thirty seconds.

### The .env File Is Not Committed to Git

The `.env` file holds secrets. Database passwords. JWT keys. API tokens. It belongs in `.gitignore`. When you run `tina4 init`, the generated `.gitignore` already excludes it.

Commit a `.env.example` instead. Placeholder values. A map for the next developer:

```env
# .env.example -- copy to .env and fill in real values
DATABASE_URL=sqlite:///data/app.db
TINA4_DEBUG=false
JWT_SECRET=CHANGE_ME
TINA4_MAIL_HOST=smtp.example.com
TINA4_MAIL_USERNAME=
TINA4_MAIL_PASSWORD=
```

The example file documents what the application expects. The real file stays on the machine that runs it. Never in the repository.

## The Priority Chain

Tina4 resolves every configurable value through a three-level chain:

```
Constructor argument  >  .env file  >  Hardcoded default
```

Three levels. Strict order. No exceptions.

1. **Constructor argument wins.** Pass a value in code and it overrides everything.
2. **.env file is second.** No code override? The `.env` value takes over.
3. **Default is last.** Neither code nor `.env` specifies a value? The framework's built-in default applies.

### Example

```env
# .env
TINA4_PORT=8080
```

```php
// Scenario 1: Constructor override
$app = new Tina4\App(["port" => 9000]);
// Result: server starts on port 9000 (constructor wins)

// Scenario 2: No constructor override
$app = new Tina4\App();
// Result: server starts on port 8080 (.env wins)

// Scenario 3: No .env value, no constructor
// (TINA4_PORT line removed from .env)
$app = new Tina4\App();
// Result: server starts on port 7145 (default wins)
```

This pattern holds across all 68 variables. Learn it once. Apply it everywhere.

## is_truthy() -- Boolean Values

Environment variables are strings. The `.env` file has no concept of `true` or `false`. Tina4 bridges this with `is_truthy()` -- a function that recognizes exactly ten string values as `true`:

| Value | Treated as |
|-------|-----------|
| `true` | `true` |
| `True` | `true` |
| `TRUE` | `true` |
| `1` | `true` |
| `yes` | `true` |
| `Yes` | `true` |
| `YES` | `true` |
| `on` | `true` |
| `On` | `true` |
| `ON` | `true` |

**Everything else is `false`:**

| Value | Treated as |
|-------|-----------|
| `false` | `false` |
| `0` | `false` |
| `no` | `false` |
| `off` | `false` |
| _(empty string)_ | `false` |
| _(variable not set)_ | `false` |

Write whichever style your team prefers:

```env
# All of these enable debug mode
TINA4_DEBUG=true
TINA4_DEBUG=1
TINA4_DEBUG=yes
TINA4_DEBUG=on
```

**No false positives.** The string `"false"` is not truthy. The string `"FALSE"` is not truthy. A typo -- `"tru"` or `"yess"` -- is not truthy. If the value is not on the list, the answer is `false`. Fail-safe by design.

---

## Complete .env Reference

### Debug and Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_DEBUG` | `false` | Master toggle. Enables debug overlay, full stack traces, Swagger UI, live reload, query logging. **Never `true` in production.** |
| `TINA4_PORT` | `7145` | HTTP server port. Override with `--port` CLI flag. |
| `TINA4_HOST` | `0.0.0.0` | Bind address. `0.0.0.0` listens on all interfaces. `127.0.0.1` restricts to localhost. |

Three variables control the server. Port, host, debug mode. Everything else flows from these.

### Database

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///data/app.db` | Connection string. Format depends on the database driver. |
| `DATABASE_USERNAME` | _(from URL)_ | Override the username in `DATABASE_URL`. Useful when the password contains special characters that break URL parsing. |
| `DATABASE_PASSWORD` | _(from URL)_ | Override the password in `DATABASE_URL`. |

**Connection string formats:**

```env
# SQLite (default -- no credentials needed)
DATABASE_URL=sqlite:///data/app.db

# PostgreSQL
DATABASE_URL=postgresql://user:password@hostname:5432/database_name

# MySQL / MariaDB
DATABASE_URL=mysql://user:password@hostname:3306/database_name

# Microsoft SQL Server
DATABASE_URL=mssql://user:password@hostname:1433/database_name

# Firebird
DATABASE_URL=firebird://user:password@hostname:3050/path/to/database.fdb

# ODBC (uses a configured DSN)
DATABASE_URL=odbc://MY_DSN_NAME

# MongoDB (SQL queries are auto-translated)
DATABASE_URL=mongodb://user:password@hostname:27017/database_name
```

Seven database engines. One variable. The driver is selected by the URL scheme. `postgresql://` triggers the PostgreSQL driver. `mysql://` triggers MySQL. The framework reads the scheme and connects.

**Gotcha:** Special characters in your database password -- `@`, `#`, `:`, `/` -- will break URL parsing. URL-encode them (`@` becomes `%40`) or split the credentials out:

```env
DATABASE_URL=postgresql://hostname:5432/mydb
DATABASE_USERNAME=admin
DATABASE_PASSWORD=p@ss#word/123
```

Separate variables. No encoding needed. The framework joins them at connection time.

### DB Query Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_DB_CACHE` | `true` | Enable in-memory caching of query results. Identical queries within the TTL return cached results. |
| `TINA4_DB_CACHE_TTL` | `60` | Cache time-to-live in seconds. After this period, cached results expire and the next query hits the database. |

Write operations -- INSERT, UPDATE, DELETE -- invalidate relevant cache entries automatically. The cache never serves stale data after a write.

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOG_LEVEL` | `ALL` | Minimum log level for console output. Options: `ALL`, `DEBUG`, `INFO`, `WARNING`, `ERROR`. File logs capture all levels regardless. |
| `TINA4_LOG_DIR` | `logs` | Directory for log files. Relative to the project root. |
| `TINA4_LOG_FILE` | `tina4.log` | Main log file name. |
| `TINA4_LOG_MAX_SIZE` | `10M` | Maximum file size before rotation. Supports `K` (kilobytes), `M` (megabytes), `G` (gigabytes). |
| `TINA4_LOG_ROTATE` | `daily` | Rotation schedule. Options: `daily`, `hourly`, `size-only`. |
| `TINA4_LOG_RETAIN` | `30` | Days to keep rotated log files. Older files are deleted. |
| `TINA4_LOG_COMPRESS` | `true` | Gzip log files older than 2 days. Disk space recovered automatically. |
| `TINA4_LOG_SEPARATE_ERRORS` | `true` | Write errors and exceptions to a separate `error.log` alongside the main log. |
| `TINA4_LOG_QUERY` | `false` | Log all SQL queries with timing to `query.log`. Invaluable in development. Expensive in production. |
| `TINA4_LOG_ACCESS` | `false` | Write HTTP access logs in standard format to `access.log`. |

Ten variables. Full control over what gets logged, where it goes, and how long it stays.

**Log file structure:**

```
logs/
├── tina4.log                    # Current log file
├── tina4.2026-03-21.log         # Yesterday's log (rotated)
├── tina4.2026-03-20.log         # 2 days ago
├── tina4.2026-03-19.log.gz      # 3+ days ago (compressed)
├── error.log                    # Current errors only
├── error.2026-03-21.log         # Yesterday's errors
└── query.log                    # SQL queries (debug mode only)
```

Rotation, compression, and cleanup happen without intervention. The framework manages its own logs.

### CORS (Cross-Origin Resource Sharing)

| Variable | Default | Description |
|----------|---------|-------------|
| `CORS_ORIGINS` | `*` | Comma-separated allowed origins. `*` allows all (development only). In production, list your actual domains. |
| `CORS_METHODS` | `GET,POST,PUT,DELETE` | Comma-separated HTTP methods allowed in cross-origin requests. |
| `CORS_HEADERS` | `Content-Type,Authorization` | Comma-separated headers the client is allowed to send. |
| `CORS_CREDENTIALS` | `true` | Whether the browser sends cookies and auth headers in cross-origin requests. |
| `CORS_MAX_AGE` | `86400` | How long (seconds) the browser caches preflight responses. `86400` = 24 hours. |

**Example for production:**

```env
CORS_ORIGINS=https://myapp.com,https://admin.myapp.com
CORS_METHODS=GET,POST,PUT,DELETE
CORS_HEADERS=Content-Type,Authorization,X-Request-ID
CORS_CREDENTIALS=true
CORS_MAX_AGE=86400
```

**Gotcha:** `CORS_ORIGINS=*` combined with `CORS_CREDENTIALS=true` will fail. Browsers reject this combination. When credentials are enabled, you must list specific origins. The wildcard is not compatible with authenticated requests.

### Rate Limiter

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_RATE_LIMIT` | `60` | Maximum requests per window per IP address. |
| `TINA4_RATE_WINDOW` | `60` | Window duration in seconds. Default: 60 requests per 60 seconds. |

The rate limiter adds three headers to every response:

```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1679512800
```

Limit exceeded? The server returns `429 Too Many Requests` with a `Retry-After` header. The client knows exactly when to try again.

Override the limit on individual routes when the default does not fit:

```php
Router::get("/api/expensive-operation", $handler)->rateLimit(10, 60);
// This route: 10 requests per 60 seconds
// All other routes: default from .env
```

Global defaults. Per-route overrides. The granularity you need without the complexity you do not.

### Auth (JWT)

| Variable | Default | Description |
|----------|---------|-------------|
| `JWT_SECRET` | _(required if auth used)_ | Secret key for HMAC-SHA256 (HS256) signing. Long, random, never committed to git. |
| `JWT_ALGORITHM` | `HS256` | Signing algorithm. `HS256` (symmetric, simpler) or `RS256` (asymmetric, uses key files in `secrets/`). |
| `JWT_EXPIRY_DAYS` | `7` | Default token expiration in days. Tokens issued without an explicit expiry use this value. |

**Gotcha:** Use `.secure()` on any route without setting `JWT_SECRET` and every request to that route returns `500 Internal Server Error`. The framework cannot validate tokens without a key. It will not pretend otherwise.

### Sessions

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_HANDLER` | `file` | Session storage backend. Options: `file`, `redis`, `valkey`, `mongo`, `database`. |
| `SESSION_SECRET` | _(required)_ | Secret key for signing session cookies. Long, random, never committed. |
| `SESSION_TTL` | `3600` | Session expiry in seconds. Default: 1 hour. |
| `REDIS_URL` | `redis://localhost:6379` | Redis connection URL. Used when `TINA4_SESSION_HANDLER=redis`. Also used by the response cache backend. |
| `MONGODB_URL` | `mongodb://localhost:27017` | MongoDB connection URL. Used when `TINA4_SESSION_HANDLER=mongo`. |

Five backends. File-based works for single-server deployments. Redis or Valkey for multi-server setups where sessions must be shared. Choose the backend that matches your infrastructure.

### Queue

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_QUEUE_BACKEND` | `database` | Queue storage backend. Options: `database` (uses the connected DB), `rabbitmq`, `kafka`, `mongodb`. |
| `QUEUE_DRIVER` | `database` | Alias for `TINA4_QUEUE_BACKEND`. Either variable works. |
| `QUEUE_FALLBACK_DRIVER` | _(none)_ | Fallback backend if the primary goes down. Same options as `QUEUE_DRIVER`. |
| `RABBITMQ_URL` | _(none)_ | AMQP connection URL for RabbitMQ. |
| `KAFKA_BROKERS` | _(none)_ | Comma-separated Kafka broker addresses. |
| `KAFKA_GROUP_ID` | `tina4-workers` | Kafka consumer group ID. |
| `TINA4_MONGO_HOST` | `localhost` | MongoDB host for queue backend. |
| `TINA4_MONGO_PORT` | `27017` | MongoDB port for queue backend. |
| `TINA4_MONGO_DB` | `tina4` | MongoDB database name for queue backend. |
| `TINA4_MONGO_COLLECTION` | `tina4_queue` | MongoDB collection name for queue messages. |
| `TINA4_MONGO_URI` | _(none)_ | Full MongoDB connection URI (overrides host/port/db). |
| `QUEUE_FAILOVER_TIMEOUT` | `300` | Seconds without a successful pop before switching to the fallback. |
| `QUEUE_FAILOVER_DEPTH` | `10000` | Maximum queue depth before triggering failover. |
| `QUEUE_FAILOVER_ERROR_RATE` | `50` | Error rate percentage (0-100) that triggers failover. |
| `QUEUE_CIRCUIT_BREAKER_THRESHOLD` | `5` | Consecutive failures before the circuit breaker trips and stops trying the primary. |
| `QUEUE_CIRCUIT_BREAKER_COOLDOWN` | `30` | Seconds to wait before retrying the primary after the circuit breaker trips. |

**Development -- start simple:**

```env
# Database queue -- works out of the box, no additional services needed
TINA4_QUEUE_BACKEND=database
```

**Production -- add resilience:**

```env
TINA4_QUEUE_BACKEND=rabbitmq
RABBITMQ_URL=amqp://user:password@rabbitmq-host:5672/vhost
QUEUE_FALLBACK_DRIVER=database
```

RabbitMQ handles the load. The database catches what falls. The circuit breaker prevents cascade failures. Three lines of configuration. Production-grade reliability.

### Response Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CACHE_BACKEND` | `memory` | Cache storage for route-level response caching. Options: `memory` (in-process, cleared on restart), `redis` (shared, persistent), `file` (disk-based). |
| `TINA4_CACHE_TTL` | `300` | Default cache TTL in seconds for routes with `.cache()`. Override per-route with `.cache(ttl)`. |
| `TINA4_CACHE_MAX_ENTRIES` | `1000` | Maximum cached responses (memory backend only). Oldest entries are evicted at the limit. |

### Response Compression

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_COMPRESS` | `true` | Enable gzip response compression. |
| `TINA4_COMPRESS_THRESHOLD` | `1024` | Minimum response body size (bytes) before compression activates. Smaller responses ship uncompressed -- the overhead is not worth it. |
| `TINA4_COMPRESS_LEVEL` | `6` | gzip compression level (1-9). Lower = faster, larger output. Higher = slower, smaller output. `6` balances both. |
| `TINA4_MINIFY_HTML` | `true` | Strip HTML comments and collapse whitespace in production. Active only when `TINA4_DEBUG=false`. |

### Messenger (Email / SMTP)

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MAIL_HOST` | _(none)_ | SMTP server hostname (e.g., `smtp.gmail.com`, `smtp.sendgrid.net`). |
| `TINA4_MAIL_PORT` | `587` | SMTP port. `587` (TLS), `465` (SSL), `25` (unencrypted). |
| `TINA4_MAIL_USERNAME` | _(none)_ | SMTP authentication username. |
| `TINA4_MAIL_PASSWORD` | _(none)_ | SMTP authentication password. |
| `TINA4_MAIL_FROM` | _(none)_ | Default sender address. Can include a display name: `"My App <noreply@example.com>"`. |
| `TINA4_MAIL_ENCRYPTION` | `tls` | Connection encryption. `tls`, `ssl`, or `none`. Use `none` only for local development mail servers. |

Six variables. A working email system. Point at your SMTP server, set credentials, define a sender. The framework handles MIME encoding, attachments, and connection management.

### Localization (i18n)

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LANGUAGE` | `en` | Default locale. Determines which translation file (`src/locales/{locale}.json`) is loaded. |

The fallback chain for translations: requested locale > `TINA4_LANGUAGE` > `en` > raw key. Four levels deep. A translation is always found or the key itself is returned. Nothing breaks.

### WebSocket

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_WS_MAX_FRAME_SIZE` | `1048576` | Maximum WebSocket frame size in bytes (default: 1MB). |
| `TINA4_WS_MAX_CONNECTIONS` | `10000` | Maximum concurrent WebSocket connections. |
| `TINA4_WS_PING_INTERVAL` | `30` | Seconds between server-sent ping frames. Keeps connections alive through proxies and load balancers. |
| `TINA4_WS_PING_TIMEOUT` | `10` | Seconds to wait for a pong response before closing the connection. No response means the client is gone. |

### Dev Dashboard

The dev dashboard at `/__dev` is automatically available when `TINA4_DEBUG=true`. No additional environment variables are needed. In production, set `TINA4_DEBUG=false` and the dashboard disappears entirely.

### Error Handling (.broken Files)

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_BROKEN_DIR` | `data/.broken` | Directory for `.broken` marker files created by unhandled exceptions in production. |
| `TINA4_BROKEN_THRESHOLD` | `1` | Number of `.broken` files that flips the health check to `503 Service Unavailable`. Container orchestrators -- Kubernetes, Docker Swarm -- use this signal to restart unhealthy containers. |
| `TINA4_BROKEN_AUTO_RESOLVE` | `0` | Seconds before `.broken` files are auto-deleted. `0` means manual resolution only -- via the admin console or by deleting the files directly. |
| `TINA4_BROKEN_MAX_FILES` | `100` | Maximum `.broken` files to retain. Oldest are deleted at the limit. |

The `.broken` system turns unhandled exceptions into infrastructure signals. An exception fires. A marker file appears. The health check fails. The orchestrator restarts the container. No human intervention needed for transient failures.

---

## Minimal .env for Development

Getting started? One line:

```env
TINA4_DEBUG=true
```

Everything else uses sensible defaults:

- Port `7145`
- SQLite database at `data/app.db`
- File-based sessions
- Database-backed queue
- In-memory response cache
- gzip compression enabled
- All CORS origins allowed
- 60 requests per minute rate limit

One line. A working development environment. Add variables when you need them. Not before.

## Minimal .env for Production

```env
TINA4_DEBUG=false
DATABASE_URL=postgresql://app_user:strong_password@db-host:5432/myapp
JWT_SECRET=a-very-long-random-string-at-least-32-characters
SESSION_SECRET=another-very-long-random-string
CORS_ORIGINS=https://myapp.com
TINA4_MAIL_HOST=smtp.sendgrid.net
TINA4_MAIL_PORT=587
TINA4_MAIL_USERNAME=apikey
TINA4_MAIL_PASSWORD=SG.xxxxx
TINA4_MAIL_FROM="My App <noreply@myapp.com>"
```

Ten lines. A production application. Debug disabled. Real database. Signed tokens. Signed sessions. Locked CORS. Email configured. Everything else keeps its defaults.

## Full .env Template

Copy this to your `.env.example` as a starting point:

```env
# =============================================================================
# Tina4 Environment Configuration
# Copy this file to .env and fill in your values
# =============================================================================

# --- Debug & Server ---
TINA4_DEBUG=false
TINA4_PORT=7145
TINA4_HOST=0.0.0.0

# --- Database ---
DATABASE_URL=sqlite:///data/app.db
# DATABASE_USERNAME=
# DATABASE_PASSWORD=

# --- Logging ---
TINA4_LOG_LEVEL=ALL
TINA4_LOG_DIR=logs
TINA4_LOG_FILE=tina4.log
TINA4_LOG_MAX_SIZE=10M
TINA4_LOG_ROTATE=daily
TINA4_LOG_RETAIN=30
TINA4_LOG_COMPRESS=true
TINA4_LOG_SEPARATE_ERRORS=true
TINA4_LOG_QUERY=false
TINA4_LOG_ACCESS=false

# --- CORS ---
CORS_ORIGINS=*
CORS_METHODS=GET,POST,PUT,DELETE
CORS_HEADERS=Content-Type,Authorization
CORS_CREDENTIALS=true
CORS_MAX_AGE=86400

# --- Rate Limiting ---
TINA4_RATE_LIMIT=60
TINA4_RATE_WINDOW=60

# --- Auth (JWT) ---
JWT_SECRET=CHANGE_ME
JWT_ALGORITHM=HS256
JWT_EXPIRY_DAYS=7

# --- Sessions ---
TINA4_SESSION_HANDLER=file
SESSION_SECRET=CHANGE_ME
SESSION_TTL=3600
# REDIS_URL=redis://localhost:6379
# MONGODB_URL=mongodb://localhost:27017

# --- Queue ---
TINA4_QUEUE_BACKEND=database
# QUEUE_FALLBACK_DRIVER=
# RABBITMQ_URL=
# KAFKA_BROKERS=
# KAFKA_GROUP_ID=tina4-workers
# TINA4_MONGO_HOST=localhost
# TINA4_MONGO_PORT=27017
# TINA4_MONGO_DB=tina4
# TINA4_MONGO_COLLECTION=tina4_queue
# TINA4_MONGO_URI=
# QUEUE_FAILOVER_TIMEOUT=300
# QUEUE_FAILOVER_DEPTH=10000
# QUEUE_FAILOVER_ERROR_RATE=50
# QUEUE_CIRCUIT_BREAKER_THRESHOLD=5
# QUEUE_CIRCUIT_BREAKER_COOLDOWN=30

# --- Response Cache ---
TINA4_CACHE_BACKEND=memory
TINA4_CACHE_TTL=300
TINA4_CACHE_MAX_ENTRIES=1000

# --- DB Query Cache ---
TINA4_DB_CACHE=true
TINA4_DB_CACHE_TTL=60

# --- Compression ---
TINA4_COMPRESS=true
TINA4_COMPRESS_THRESHOLD=1024
TINA4_COMPRESS_LEVEL=6
TINA4_MINIFY_HTML=true

# --- Email (SMTP) ---
# TINA4_MAIL_HOST=smtp.example.com
# TINA4_MAIL_PORT=587
# TINA4_MAIL_USERNAME=
# TINA4_MAIL_PASSWORD=
# TINA4_MAIL_FROM="App Name <noreply@example.com>"
# TINA4_MAIL_ENCRYPTION=tls

# --- Localization ---
TINA4_LANGUAGE=en

# --- WebSocket ---
TINA4_WS_MAX_FRAME_SIZE=1048576
TINA4_WS_MAX_CONNECTIONS=10000
TINA4_WS_PING_INTERVAL=30
TINA4_WS_PING_TIMEOUT=10

# --- Dev Dashboard ---
# The dev dashboard at /__dev is enabled by TINA4_DEBUG=true (no additional variables needed)

# --- Error Handling ---
TINA4_BROKEN_DIR=data/.broken
TINA4_BROKEN_THRESHOLD=1
TINA4_BROKEN_AUTO_RESOLVE=0
TINA4_BROKEN_MAX_FILES=100
```

## Summary

| Count | Category |
|-------|----------|
| 3 | Debug and server configuration |
| 3 | Database |
| 2 | DB query cache |
| 10 | Logging |
| 5 | CORS |
| 2 | Rate limiter |
| 3 | Auth (JWT) |
| 5 | Sessions |
| 15 | Queue |
| 3 | Response cache |
| 4 | Compression |
| 6 | Messenger (email) |
| 1 | Localization |
| 4 | WebSocket |
| 3 | Dev admin console |
| 4 | Error handling |
| **73** | **Total** |

Seventy-three variables. Every one follows the same priority chain: constructor > `.env` > default. Every boolean is interpreted by `is_truthy()`. Every variable has a sensible default that works for development without any configuration.

One file. Seventy-three knobs. Turn what you need. Leave the rest alone.
