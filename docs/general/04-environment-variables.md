# Chapter 4: Environment Variables

Every piece of Tina4 configuration lives in one file. A `.env` at the root of your project. All optional. All with sensible defaults. Identical across Python, PHP, Ruby, and Node.js. This chapter is the complete reference.

## How .env Files Work

A `.env` file is plain text. Key-value pairs. Nothing more.

```bash
# This is a comment
DATABASE_URL=sqlite:///data/app.db
TINA4_DEBUG=true

# Blank lines are ignored

# Values with spaces need quotes
TINA4_MAIL_FROM="My App <noreply@example.com>"

# No quotes needed for simple values
SECRET=my-secret-key-change-in-production
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

```bash
# .env.example -- copy to .env and fill in real values
DATABASE_URL=sqlite:///data/app.db
TINA4_DEBUG=false
SECRET=CHANGE_ME
SMTP_HOST=smtp.example.com
SMTP_USERNAME=
SMTP_PASSWORD=
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

This pattern holds across all variables and all four language implementations. Learn it once. Apply it everywhere.

## Boolean Values

Environment variables are strings. The `.env` file has no concept of `true` or `false`. Tina4 recognises these values as truthy:

| Value | Treated as |
|-------|-----------|
| `true`, `True`, `TRUE` | `true` |
| `1` | `true` |
| `yes`, `Yes`, `YES` | `true` |
| `on`, `On`, `ON` | `true` |

**Everything else is `false`:**

| Value | Treated as |
|-------|-----------|
| `false`, `0`, `no`, `off` | `false` |
| _(empty string)_ | `false` |
| _(variable not set)_ | `false` |

Write whichever style your team prefers:

```bash
# All of these enable debug mode
TINA4_DEBUG=true
TINA4_DEBUG=1
TINA4_DEBUG=yes
```

---

## Complete .env Reference

### Server

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Bind address. `0.0.0.0` listens on all interfaces (required for Docker). `127.0.0.1` restricts to localhost. |
| `PORT` | See below | HTTP server port. Each framework has a unique default to avoid conflicts when running side-by-side. |
| `TINA4_DEBUG` | `false` | Master toggle. Enables debug overlay, full stack traces, Swagger UI, live reload, query logging. **Never `true` in production.** |

**Default ports by framework:**

| Framework | Default Port |
|-----------|-------------|
| Python | `7145` |
| PHP | `7146` |
| Ruby | `7147` |
| Node.js | `7148` |

### Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET` | `tina4-default-secret` | Secret key for JWT signing (HMAC-SHA256). Long, random, never committed to git. **Change this in production.** |
| `TINA4_API_KEY` | _(none)_ | Static API key for bearer token authentication. When set, requests with `Authorization: Bearer {TINA4_API_KEY}` are accepted. |
| `TINA4_TOKEN_LIMIT` | `60` | Token lifetime in minutes. Tokens issued by `get_token()` / `getToken()` expire after this many minutes. |

### CSRF Protection

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CSRF` | `true` | Enable CSRF token validation on POST/PUT/PATCH/DELETE. Set to `false` to disable (e.g. for internal microservices behind a firewall). |

CSRF is **on by default**. When enabled:
- POST/PUT/PATCH/DELETE requests must include a `formToken` in the request body or an `X-Form-Token` header.
- GET/HEAD/OPTIONS requests are not checked.
- Requests with a valid `Authorization: Bearer` token skip CSRF validation.
- Routes marked `@noauth()` skip CSRF validation.
- Tokens in query strings are **rejected** (security risk).

To disable for internal services:

```bash
TINA4_CSRF=false
```

### Database

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///data/app.db` | Connection string. The URL scheme selects the driver. |
| `DATABASE_USERNAME` | _(from URL)_ | Override the username in `DATABASE_URL`. Useful when credentials contain special characters. |
| `DATABASE_PASSWORD` | _(from URL)_ | Override the password in `DATABASE_URL`. |
| `TINA4_AUTOCOMMIT` | `false` | Enable auto-commit after every write operation. Default is off -- use explicit `commit()` calls. |

**Connection string formats:**

```bash
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

# MongoDB (SQL queries are auto-translated)
DATABASE_URL=mongodb://user:password@hostname:27017/database_name
```

**Gotcha:** Special characters in your database password -- `@`, `#`, `:`, `/` -- will break URL parsing. URL-encode them (`@` becomes `%40`) or split the credentials into separate variables.

### DB Query Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_DB_CACHE` | `false` | Enable in-memory caching of query results. |
| `TINA4_DB_CACHE_TTL` | `30` | Cache time-to-live in seconds. |

### ORM

| Variable | Default | Description |
|----------|---------|-------------|
| `ORM_PLURAL_TABLE_NAMES` | `false` | Append "s" to auto-generated table names. When `false` (default), `Product` maps to `product`. When `true`, `Product` maps to `products`. |

### CORS (Cross-Origin Resource Sharing)

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CORS_ORIGINS` | `*` | Comma-separated allowed origins. `*` allows all. In production, list your actual domains. |
| `TINA4_CORS_METHODS` | `GET,POST,PUT,PATCH,DELETE,OPTIONS` | Comma-separated HTTP methods allowed in cross-origin requests. |
| `TINA4_CORS_HEADERS` | `Content-Type,Authorization,X-Request-ID` | Comma-separated headers the client is allowed to send. |
| `TINA4_CORS_CREDENTIALS` | `true` | Whether the browser sends cookies and auth headers in cross-origin requests. |
| `TINA4_CORS_MAX_AGE` | `86400` | How long (seconds) the browser caches preflight responses. `86400` = 24 hours. |

**Gotcha:** `TINA4_CORS_ORIGINS=*` combined with `TINA4_CORS_CREDENTIALS=true` is invalid per the CORS spec. Tina4 handles this automatically -- when origin is `*`, the credentials header is not sent.

### Security Headers

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_FRAME_OPTIONS` | `SAMEORIGIN` | `X-Frame-Options` header. Prevents clickjacking. Options: `DENY`, `SAMEORIGIN`. |
| `TINA4_HSTS` | _(empty/off)_ | `Strict-Transport-Security` max-age in seconds. Set to `31536000` (1 year) in production with HTTPS. |
| `TINA4_CSP` | `default-src 'self'` | `Content-Security-Policy` header. Controls which resources the browser is allowed to load. |
| `TINA4_REFERRER_POLICY` | `strict-origin-when-cross-origin` | `Referrer-Policy` header. Controls what referrer info is sent with requests. |
| `TINA4_PERMISSIONS_POLICY` | `camera=(), microphone=(), geolocation=()` | `Permissions-Policy` header. Disables browser features your app doesn't need. |

The `X-Content-Type-Options: nosniff` and `X-XSS-Protection: 0` headers are always set (no env variable -- these are security best practices).

### Rate Limiter

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_RATE_LIMIT` | `100` | Maximum requests per window per IP address. |
| `TINA4_RATE_WINDOW` | `60` | Window duration in seconds. Default: 100 requests per 60 seconds. |

The rate limiter adds three headers to every response:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 85
X-RateLimit-Reset: 60
```

When the limit is exceeded, the server returns `429 Too Many Requests`.

### Sessions

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_BACKEND` | `file` | Session storage backend. Options: `file`, `redis`, `valkey`, `mongo`, `database`. |
| `TINA4_SESSION_PATH` | `data/sessions` | Directory for file-based sessions. Relative to the project root. |
| `TINA4_SESSION_TTL` | `3600` | Session expiry in seconds. Default: 1 hour. |
| `TINA4_SESSION_SAMESITE` | `Lax` | SameSite cookie attribute. Options: `Strict`, `Lax`, `None`. |

#### Redis/Valkey Session Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_REDIS_HOST` | `127.0.0.1` | Redis host. |
| `TINA4_SESSION_REDIS_PORT` | `6379` | Redis port. |
| `TINA4_SESSION_REDIS_PASSWORD` | _(none)_ | Redis password. |
| `TINA4_SESSION_REDIS_DB` | `0` | Redis database number. |
| `TINA4_SESSION_REDIS_PREFIX` | `tina4:session:` | Key prefix for session data. |
| `TINA4_SESSION_VALKEY_HOST` | `localhost` | Valkey host. |
| `TINA4_SESSION_VALKEY_PORT` | `6379` | Valkey port. |
| `TINA4_SESSION_VALKEY_PASSWORD` | _(none)_ | Valkey password. |
| `TINA4_SESSION_VALKEY_DB` | `0` | Valkey database number. |
| `TINA4_SESSION_VALKEY_PREFIX` | `tina4:session:` | Key prefix for session data. |

#### MongoDB Session Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_MONGO_URI` | _(none)_ | Full MongoDB connection URI. Overrides host/port. |
| `TINA4_SESSION_MONGO_HOST` | `localhost` | MongoDB host. |
| `TINA4_SESSION_MONGO_PORT` | `27017` | MongoDB port. |
| `TINA4_SESSION_MONGO_USERNAME` | _(none)_ | MongoDB username. |
| `TINA4_SESSION_MONGO_PASSWORD` | _(none)_ | MongoDB password. |
| `TINA4_SESSION_MONGO_DB` | `tina4_sessions` | MongoDB database name. |
| `TINA4_SESSION_MONGO_COLLECTION` | `sessions` | MongoDB collection for session data. |

### Queue

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_QUEUE_BACKEND` | `file` | Queue storage backend. Options: `file`, `rabbitmq`, `kafka`, `mongodb`. |
| `TINA4_QUEUE_PATH` | `data/queue` | Directory for file-based queue storage (when using `file` backend). |
| `TINA4_QUEUE_URL` | _(none)_ | Generic connection URL for queue backend. |

#### RabbitMQ Queue Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_RABBITMQ_HOST` | `localhost` | RabbitMQ host. |
| `TINA4_RABBITMQ_PORT` | `5672` | RabbitMQ port. |
| `TINA4_RABBITMQ_USERNAME` | `guest` | RabbitMQ username. |
| `TINA4_RABBITMQ_PASSWORD` | `guest` | RabbitMQ password. |
| `TINA4_RABBITMQ_VHOST` | `/` | RabbitMQ virtual host. |

#### Kafka Queue Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_KAFKA_BROKERS` | `localhost:9092` | Comma-separated Kafka broker addresses. |
| `TINA4_KAFKA_GROUP_ID` | `tina4_consumer_group` | Kafka consumer group ID. |

#### MongoDB Queue Backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MONGO_URI` | _(none)_ | Full MongoDB connection URI. Overrides host/port. |
| `TINA4_MONGO_HOST` | `localhost` | MongoDB host. |
| `TINA4_MONGO_PORT` | `27017` | MongoDB port. |
| `TINA4_MONGO_USERNAME` | _(none)_ | MongoDB username. |
| `TINA4_MONGO_PASSWORD` | _(none)_ | MongoDB password. |
| `TINA4_MONGO_DB` | `tina4` | MongoDB database name. |
| `TINA4_MONGO_COLLECTION` | `tina4_queue` | MongoDB collection for queue messages. |

### Response Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CACHE_BACKEND` | `memory` | Cache storage. Options: `memory` (in-process), `redis`, `file`. |
| `TINA4_CACHE_TTL` | `60` | Default cache TTL in seconds for cached routes. |
| `TINA4_CACHE_MAX_ENTRIES` | `1000` | Maximum cached responses (memory backend). Oldest entries evicted at the limit. |
| `TINA4_CACHE_DIR` | `data/cache` | Directory for file-based cache. |
| `TINA4_CACHE_URL` | `redis://localhost:6379` | Redis connection URL for cache backend. |

### Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOG_LEVEL` | `ERROR` | Minimum log level. Options: `ALL`, `DEBUG`, `INFO`, `WARNING`, `ERROR`. |
| `TINA4_LOG_MAX_SIZE` | `10` | Maximum log file size in MB before rotation. |
| `TINA4_LOG_KEEP` | `5` | Number of rotated log files to keep. |

### Messenger (Email / SMTP)

Tina4 supports two naming conventions for SMTP variables. The `SMTP_*` variables are the primary names. The `TINA4_MAIL_*` variables are aliases that take precedence when both are set.

| Variable | Alias | Default | Description |
|----------|-------|---------|-------------|
| `SMTP_HOST` | `TINA4_MAIL_HOST` | `localhost` | SMTP server hostname. |
| `SMTP_PORT` | `TINA4_MAIL_PORT` | `587` | SMTP port. `587` (TLS), `465` (SSL), `25` (unencrypted). |
| `SMTP_USERNAME` | `TINA4_MAIL_USERNAME` | _(none)_ | SMTP authentication username. |
| `SMTP_PASSWORD` | `TINA4_MAIL_PASSWORD` | _(none)_ | SMTP authentication password. |
| `SMTP_FROM` | `TINA4_MAIL_FROM` | `noreply@localhost` | Default sender address. |
| `SMTP_FROM_NAME` | `TINA4_MAIL_FROM_NAME` | _(none)_ | Sender display name. |
| `TINA4_MAIL_ENCRYPTION` | — | `tls` | Connection encryption. `tls`, `ssl`, or `none`. |

#### IMAP (for reading email)

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAP_HOST` | _(falls back to SMTP_HOST)_ | IMAP server hostname. |
| `IMAP_PORT` | `993` | IMAP port (993 = SSL). |

### Localization (i18n)

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOCALE` | `en` | Default locale. Determines which translation file (`src/locales/{locale}.json`) is loaded. |
| `TINA4_LOCALE_DIR` | `src/locales` | Directory containing translation JSON files. |

### Swagger / OpenAPI

| Variable | Default | Description |
|----------|---------|-------------|
| `SWAGGER_TITLE` | `Tina4 API` | API title shown in Swagger UI. |
| `SWAGGER_VERSION` | `1.0.0` | API version shown in Swagger UI. |
| `SWAGGER_DESCRIPTION` | _(none)_ | API description. |

### File Uploads

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MAX_UPLOAD_SIZE` | `10485760` | Maximum upload size in bytes. Default: 10 MB. |

### WebSocket

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_WS_PORT` | `8080` | WebSocket server port (when running as separate process). |
| `TINA4_WS_BACKPLANE` | _(none)_ | WebSocket backplane type. Set to `redis` to relay broadcasts across instances. |
| `TINA4_WS_BACKPLANE_URL` | `redis://localhost:6379` | Connection URL for the WebSocket backplane. |

### Services (Background Workers)

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SERVICE_DIR` | `src/services` | Directory for service worker scripts. |
| `TINA4_SERVICE_SLEEP` | `5` | Seconds between service worker ticks. |

### Dev Mailbox

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MAILBOX_DIR` | `data/mailbox` | Directory for captured dev emails. |

---

## Minimal .env for Development

Getting started? One line:

```bash
TINA4_DEBUG=true
```

Everything else uses sensible defaults:

- Binds to `0.0.0.0` on the framework's default port
- SQLite database at `data/app.db`
- File-based sessions (1 hour TTL)
- File-based queue
- In-memory response cache
- CORS allows all origins
- 100 requests per minute rate limit
- CSRF protection enabled
- Security headers active

One line. A working development environment. Add variables when you need them. Not before.

## Minimal .env for Production

```bash
TINA4_DEBUG=false
SECRET=a-very-long-random-string-at-least-32-characters
DATABASE_URL=postgresql://app_user:strong_password@db-host:5432/myapp
TINA4_CORS_ORIGINS=https://myapp.com
TINA4_HSTS=31536000
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=SG.xxxxx
SMTP_FROM=noreply@myapp.com
```

Ten lines. A production application. Debug disabled. Real database. Signed tokens. Locked CORS. HSTS enabled. Email configured. Everything else keeps its defaults.

## Docker .env

When running in Docker, `HOST` must be `0.0.0.0` so the container accepts connections from outside. This is already the default, but if you override it, keep this in mind:

```bash
# Required for Docker -- do NOT set to 127.0.0.1
HOST=0.0.0.0
PORT=7145
TINA4_DEBUG=false
```

## Full .env Template

Copy this to your `.env.example` as a starting point:

```bash
# =============================================================================
# Tina4 Environment Configuration
# Copy this file to .env and fill in your values
# =============================================================================

# --- Server ---
HOST=0.0.0.0
# PORT=7145
TINA4_DEBUG=false

# --- Authentication ---
SECRET=CHANGE_ME
# TINA4_API_KEY=
TINA4_TOKEN_LIMIT=60

# --- CSRF ---
TINA4_CSRF=true

# --- Database ---
DATABASE_URL=sqlite:///data/app.db
# DATABASE_USERNAME=
# DATABASE_PASSWORD=
# TINA4_AUTOCOMMIT=false

# --- DB Query Cache ---
# TINA4_DB_CACHE=false
# TINA4_DB_CACHE_TTL=30

# --- ORM ---
# ORM_PLURAL_TABLE_NAMES=false

# --- CORS ---
TINA4_CORS_ORIGINS=*
TINA4_CORS_METHODS=GET,POST,PUT,PATCH,DELETE,OPTIONS
TINA4_CORS_HEADERS=Content-Type,Authorization,X-Request-ID
TINA4_CORS_CREDENTIALS=true
TINA4_CORS_MAX_AGE=86400

# --- Security Headers ---
# TINA4_FRAME_OPTIONS=SAMEORIGIN
# TINA4_HSTS=
# TINA4_CSP=default-src 'self'
# TINA4_REFERRER_POLICY=strict-origin-when-cross-origin
# TINA4_PERMISSIONS_POLICY=camera=(), microphone=(), geolocation=()

# --- Rate Limiting ---
TINA4_RATE_LIMIT=100
TINA4_RATE_WINDOW=60

# --- Logging ---
TINA4_LOG_LEVEL=ERROR
# TINA4_LOG_MAX_SIZE=10
# TINA4_LOG_KEEP=5

# --- Sessions ---
TINA4_SESSION_BACKEND=file
# TINA4_SESSION_PATH=data/sessions
TINA4_SESSION_TTL=3600
# TINA4_SESSION_REDIS_HOST=127.0.0.1
# TINA4_SESSION_REDIS_PORT=6379
# TINA4_SESSION_VALKEY_HOST=localhost
# TINA4_SESSION_VALKEY_PORT=6379

# --- Queue ---
TINA4_QUEUE_BACKEND=file
# TINA4_RABBITMQ_HOST=localhost
# TINA4_RABBITMQ_PORT=5672
# TINA4_RABBITMQ_USERNAME=guest
# TINA4_RABBITMQ_PASSWORD=guest
# TINA4_KAFKA_BROKERS=localhost:9092
# TINA4_KAFKA_GROUP_ID=tina4_consumer_group
# TINA4_MONGO_HOST=localhost
# TINA4_MONGO_PORT=27017
# TINA4_MONGO_DB=tina4
# TINA4_MONGO_COLLECTION=tina4_queue

# --- Response Cache ---
TINA4_CACHE_BACKEND=memory
TINA4_CACHE_TTL=60
TINA4_CACHE_MAX_ENTRIES=1000

# --- Email (SMTP) ---
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587
# SMTP_USERNAME=
# SMTP_PASSWORD=
# SMTP_FROM=noreply@example.com

# --- Localization ---
TINA4_LOCALE=en

# --- Swagger ---
SWAGGER_TITLE=Tina4 API
SWAGGER_VERSION=1.0.0
# SWAGGER_DESCRIPTION=

# --- File Uploads ---
# TINA4_MAX_UPLOAD_SIZE=10485760

# --- Services ---
# TINA4_SERVICE_DIR=src/services
# TINA4_SERVICE_SLEEP=5
```

## Summary

| Count | Category |
|-------|----------|
| 3 | Server (HOST, PORT, TINA4_DEBUG) |
| 3 | Authentication (SECRET, TINA4_API_KEY, TINA4_TOKEN_LIMIT) |
| 1 | CSRF (TINA4_CSRF) |
| 4 | Database (DATABASE_URL, USERNAME, PASSWORD, AUTOCOMMIT) |
| 2 | DB query cache |
| 5 | CORS |
| 5 | Security headers |
| 2 | Rate limiter |
| 3 | Logging |
| 14 | Sessions (base + Redis + Valkey + MongoDB) |
| 15 | Queue (base + RabbitMQ + Kafka + MongoDB) |
| 5 | Response cache |
| 8 | Messenger (SMTP + IMAP) |
| 2 | Localization |
| 3 | Swagger |
| 1 | File uploads |
| 3 | WebSocket |
| 2 | Services |
| 1 | Dev mailbox |
| **82** | **Total** |

Every variable follows the same priority chain: constructor > `.env` > default. Every boolean is interpreted consistently across all four frameworks. Every variable has a sensible default that works for development without any configuration.

One file. Eighty-two knobs. Turn what you need. Leave the rest alone.
