# Environment Variables

> **⚠️ BREAKING CHANGE, Tina4 v3.12.0**
>
> Every framework env var now requires the `TINA4_` prefix. The legacy un-prefixed names (`DATABASE_URL`, `SECRET`, `SMTP_HOST`, `HOST_NAME`, etc.) no longer work. Setting them at startup makes the framework refuse to boot with a list of renames.
>
> Run `tina4 env --migrate` to rewrite your existing `.env` automatically, or rename manually using the table below. The runtime guard prints the same mapping if it detects legacy names.
>
> **Conventional names stay un-prefixed:** `PORT`, `HOST`, `NODE_ENV`, `RACK_ENV`, `RUBY_ENV`, `ENVIRONMENT`. These are runtime/PaaS conventions, not framework config.


Tina4 PHP is configured through environment variables, read from `.env` at the project root. Every variable has a sensible default, most projects set three or four values and leave the rest alone.

The **Universal** section below is identical across Python, PHP, Ruby, and Node.js: same variables, same defaults, same grouping. The **AI / Dev-Admin** section covers the dashboard's AI and developer tooling. The **Framework-specific** section at the end lists the handful of variables only this framework reads.

Start with the minimum-config examples at the end, then come back here when you need to tune something specific.

---

## Universal

These variables behave the same way in every Tina4 framework. Defaults are canonical, the framework reads each one and applies the listed default when it's unset.

### Core Server

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_DEBUG` | `false` | Master debug toggle. Enables Swagger UI, dev dashboard, live reload, template dump filter, error overlay. Never set to `true` in production. |
| `TINA4_ENV` | `development` | Runtime environment label. Values like `development`, `staging`, `production` control dev-only features. |
| `HOST` | `0.0.0.0` | Bind address. `0.0.0.0` listens on every interface. `127.0.0.1` restricts to localhost. |
| `TINA4_HOST` | `0.0.0.0` | Framework-prefixed bind address. Pairs with `HOST`, set either one. |
| `PORT` | `7146` | HTTP server port. The Rust CLI prefers `TINA4_PORT` but falls back to `PORT`. |
| `TINA4_PORT` | `7146` | Framework-prefixed port override. Pairs with `PORT`, set either one. |
| `TINA4_HOST_NAME` | `localhost:<port>` | Fully-qualified host used in generated absolute URLs (Swagger, OAuth redirects, emails) and for localhost detection. |
| `CI` | _(none)_ | Standard CI flag. When set, suppresses dev-secret auto-minting so test runs stay deterministic. |
| `TINA4_SUPPRESS` | `false` | Suppresses the framework startup banner. Useful in CI runs and systemd units where stdout is parsed. |
| `TINA4_NO_RELOAD` | `false` | Disables the dev hot-reload signal from the Rust CLI. Use when you want a stable server for debugging. |
| `TINA4_NO_AI_PORT` | `false` | Disables the secondary stable AI port started alongside the dev server. |
| `TINA4_NO_BROWSER` | `false` | Stops `tina4 serve` from opening your browser on every restart. Recommended during active development. |
| `TINA4_OVERRIDE_CLIENT` | _(none)_ | Set truthy to start without the Rust CLI supervisor (`tina4 serve`). Used in Docker images and CI runners; bypasses SCSS compilation, the file watcher, and live reload. |
| `TINA4_ALLOW_LEGACY_ENV` | `false` | Bypass the v3.12 boot guard that rejects un-prefixed legacy env vars. Use only in CI / migration scripts during the transition window. |
| `TINA4_TRAILING_SLASH_REDIRECT` | `false` | When truthy, requests to `/foo/` are 301-redirected to `/foo` so clients see one canonical URL per route. The root `/` is exempt. |
| `TINA4_TEMPLATE_ROUTING` | `on` | Auto-routing of templates from `src/templates/`. Set to `off`, `false`, `0`, `no`, or `disabled` to require an explicit route for every URL. |
| `TINA4_TEMPLATE_CACHE_TTL` | `0` | Frond compiled-template cache TTL in seconds. `0` keeps compiled templates in memory permanently; a positive value recompiles after N seconds. `tina4 serve` invalidates the cache on file change. |
| `TINA4_HEALTH_PATH` | `/__health` | URL for the built-in liveness/readiness endpoint. |
| `TINA4_PUBLIC_DIR` | _(none)_ | Override directory served as static files under `/`. When unset, the framework searches the bundled and project public assets. |
| `TINA4_ENV_FILE` | `.env` | Path to the dotenv file loaded at boot, before any other framework config. Point at `.env.staging` or `.env.production` to switch the whole config tree. |
| `TINA4_MAX_UPLOAD_SIZE` | `10485760` | Maximum multipart upload size in bytes (10 MB). Larger requests are rejected before parsing. |
| `TINA4_DEV_POLL_INTERVAL` | `3000` | Milliseconds between dev-mode file-change polls when the WebSocket reload channel is unavailable. |
| `TINA4_SSE_HEARTBEAT` | `15` | Server-Sent Events keep-alive interval in seconds. |

### Logging

stdout is always on. With `TINA4_LOG_OUTPUT` unset, the log **file** is written only in development (`TINA4_DEBUG` truthy); production and containers stay stdout-only so a log file never bloats the writable layer. Set `TINA4_LOG_OUTPUT=file`/`both`, or point `TINA4_LOG_FILE` at a path, to force a file. Switch `TINA4_LOG_FORMAT=json` for one structured record per line.

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOG_LEVEL` | `INFO` | Minimum level shown on the console (stdout). The log file always records every level. Options: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. |
| `TINA4_LOG_REQUESTS` | _(inherits `TINA4_DEBUG`)_ | Per-request access logging. On by default in dev; set explicitly to override. |
| `TINA4_LOG_OUTPUT` | `stdout` | Where logs go. Options: `stdout`, `file`, `both`. When unset, the file is written only in development; explicit `file`/`both` always writes a file. |
| `TINA4_LOG_FORMAT` | `text` | Output format. `text` writes the human-readable form; `json` writes one structured record per line. |
| `TINA4_LOG_ROTATE_SIZE` | `10485760` | Bytes per file before rotation (10 MB). `0` disables rotation entirely. |
| `TINA4_LOG_ROTATE_KEEP` | `5` | Number of rotated files to keep (`app.log.1` ... `app.log.N`). |
| `TINA4_LOG_MAX_SIZE` | _(legacy alias)_ | Legacy alias for `TINA4_LOG_ROTATE_SIZE`. |
| `TINA4_LOG_KEEP` | `5` | Legacy alias for `TINA4_LOG_ROTATE_KEEP`. |
| `TINA4_LOG_FILE` | _(empty)_ | Path to a log file. Empty leaves logs on stdout. Relative paths resolve against `TINA4_LOG_DIR`; absolute paths are used verbatim. Setting any path forces file output. |
| `TINA4_LOG_DIR` | `logs` | Directory for log files. Joined with `TINA4_LOG_FILE` when the latter is relative. |
| `TINA4_LOG_FUNC` | _(empty)_ | When truthy, includes the calling function name in each log line. |
| `TINA4_LOG_STRICT` | `false` | When `true`, raises on a log-write failure instead of swallowing it. |

### Database

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_DATABASE_URL` | `sqlite:///data/app.db` | Connection URL. Scheme selects the driver: `sqlite`, `postgres`, `mysql`, `firebird`. |
| `TINA4_DATABASE_USERNAME` | _(empty)_ | Overrides the username embedded in `TINA4_DATABASE_URL`. |
| `TINA4_DATABASE_PASSWORD` | _(empty)_ | Overrides the password embedded in `TINA4_DATABASE_URL`. |
| `TINA4_DB_POOL` | `0` | Default connection-pool size when the caller doesn't pass `pool=` explicitly. `0` uses a single connection; a positive integer enables round-robin pooling. |
| `TINA4_AUTOCOMMIT` | `true` | Standalone writes auto-commit on their own connection (durable + visible across a pool); explicit transactions stay atomic. Set `false` for strict manual-commit mode. |
| `TINA4_AUTO_MIGRATE` | `true` | Run pending migrations on startup when a `migrations/` folder exists. Non-breaking, a failed migration is logged and the service still boots; the explicit `tina4 migrate` CLI stays fail-fast. Set `false` to disable (e.g. multi-instance production that migrates as a separate deploy step). |
| `TINA4_DATABASE_FIREBIRD_PATH` | _(none)_ | Overrides the database path/alias parsed from `TINA4_DATABASE_URL` for Firebird. Useful for Windows backslash paths and split-config setups. |
| `TINA4_ORM_PLURAL_TABLE_NAMES` | `false` | When `true`, the ORM pluralises class names into table names (`User` → `users`). Default keeps them singular. |

### Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_DB_CACHE` | `false` | Persistent cross-request query-result cache for read queries. |
| `TINA4_AUTO_CACHING` | `false` | Request-scoped query cache. Off by default to avoid read-after-write staleness within a request. |
| `TINA4_DB_CACHE_TTL` | `30` | Persistent query cache TTL in seconds when `TINA4_DB_CACHE=true`. |
| `TINA4_AUTO_CACHING_TTL` | `5` | Request-scoped query cache TTL in seconds. |
| `TINA4_DB_CACHE_BACKEND` | `memory` | Backend for the persistent DB cache. Options: `memory`, `redis`, `valkey`, `memcached`. |
| `TINA4_DB_CACHE_URL` | _(none)_ | Connection URL for a remote persistent DB cache backend. |
| `TINA4_CACHE_BACKEND` | `memory` | Response / KV cache backend. Options: `memory`, `file`, `redis`, `valkey`, `memcached`, `mongodb`, `database`. Falls back to `file` if the configured backend is unreachable. |
| `TINA4_CACHE_URL` | _(varies by backend)_ | Connection URL for remote cache backends. For `database`, falls back to `TINA4_DATABASE_URL` when unset. |
| `TINA4_CACHE_USERNAME` | _(empty)_ | Username for the cache backend. May also be embedded in `TINA4_CACHE_URL`. |
| `TINA4_CACHE_PASSWORD` | _(empty)_ | Password for the cache backend. May also be embedded in `TINA4_CACHE_URL` (e.g. `redis://:pass@host`). Memcached is unauthenticated. |
| `TINA4_CACHE_TTL` | `60` | Default response cache TTL in seconds. |
| `TINA4_CACHE_MAX_ENTRIES` | `1000` | Maximum cache entries. Oldest entries evicted first. |
| `TINA4_CACHE_DIR` | `data/cache` | Cache directory for the file backend. |

### Secrets and Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SECRET` | _(none)_ | JWT/signing secret. No built-in or guessable default. In development the framework auto-mints one to `.env.local`; in CI/production it stays blank and the framework warns. Must be long, random, and unique per environment. **Never commit.** |
| `TINA4_API_KEY` | _(empty)_ | Static bearer API key used as a fallback to JWT. Unset disables it. |
| `TINA4_TOKEN_LIMIT` | `60` | JWT / form-token lifetime in minutes. |
| `TINA4_JWT_ALGORITHM` | `HS256` | JWT signing algorithm. Supports `HS256`, `HS384`, `HS512`. |

### Sessions

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_BACKEND` | `file` | Storage backend. Options: `file`, `redis`, `valkey`, `mongo`, `database`. |
| `TINA4_SESSION_TTL` | `3600` | Session expiry in seconds. |
| `TINA4_SESSION_PATH` | `data/sessions` | Filesystem path for the file backend. |
| `TINA4_SESSION_STRICT` | `false` | When `true`, re-raises on a session backend failure instead of degrading gracefully. |
| `TINA4_SESSION_NAME` | `tina4_session` | Name of the session cookie sent to the browser. |
| `TINA4_SESSION_SAMESITE` | `Lax` | SameSite cookie attribute. Options: `Strict`, `Lax`, `None`. |
| `TINA4_SESSION_HTTPONLY` | `true` | Sets the `HttpOnly` cookie attribute so JavaScript on the page cannot read the session ID. |
| `TINA4_SESSION_SECURE` | `false` | Sets the `Secure` cookie attribute so the session cookie is only sent over HTTPS. Turn on in production. |
| `TINA4_SESSION_REDIS_HOST` | `localhost` | Redis session host. |
| `TINA4_SESSION_REDIS_PORT` | `6379` | Redis session port. |
| `TINA4_SESSION_REDIS_PASSWORD` | _(none)_ | Redis session auth password. |
| `TINA4_SESSION_REDIS_DB` | `0` | Redis session database number. |
| `TINA4_SESSION_VALKEY_HOST` | `localhost` | Valkey session host. |
| `TINA4_SESSION_VALKEY_PORT` | `6379` | Valkey session port. |
| `TINA4_SESSION_VALKEY_PASSWORD` | _(none)_ | Valkey session auth password. |
| `TINA4_SESSION_VALKEY_DB` | `0` | Valkey session database number. |
| `TINA4_SESSION_VALKEY_PREFIX` | `tina4:session:` | Key prefix for Valkey session entries. |
| `TINA4_SESSION_MONGO_URL` | `mongodb://localhost:27017` | MongoDB session connection string. |
| `TINA4_SESSION_MONGO_DB` | `tina4` | MongoDB session database name. |
| `TINA4_SESSION_MONGO_COLLECTION` | `sessions` | MongoDB session collection name. |

### CORS

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CORS_ORIGINS` | `*` | Comma-separated allowed origins. Lock down to real domains in production. |
| `TINA4_CORS_METHODS` | `GET, POST, PUT, DELETE, PATCH, OPTIONS` | Allowed request methods. |
| `TINA4_CORS_HEADERS` | `Content-Type,Authorization,X-Request-ID` | Allowed request headers. |
| `TINA4_CORS_MAX_AGE` | `86400` | Preflight cache lifetime in seconds. |
| `TINA4_CORS_CREDENTIALS` | `false` | Send `Access-Control-Allow-Credentials: true`. Opt-in, combining `true` with `TINA4_CORS_ORIGINS=*` is unsafe. |

### Security Headers

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_FRAME_OPTIONS` | `SAMEORIGIN` | `X-Frame-Options` header. Set `DENY` to forbid all framing. |
| `TINA4_HSTS` | _(empty/off)_ | `Strict-Transport-Security` max-age in seconds. Set `31536000` in production with HTTPS. |
| `TINA4_CSP` | `default-src 'self'` | `Content-Security-Policy` header. |
| `TINA4_REFERRER_POLICY` | `strict-origin-when-cross-origin` | `Referrer-Policy` header. |
| `TINA4_PERMISSIONS_POLICY` | `camera=(), microphone=(), geolocation=()` | `Permissions-Policy` header. |
| `TINA4_CSRF` | `true` | CSRF token validation on POST/PUT/PATCH/DELETE. Enabled by default; disable with `TINA4_CSRF=false`. |
| `TINA4_RATE_LIMIT` | `100` | Maximum requests per window per IP. Set `0` to disable. |
| `TINA4_RATE_WINDOW` | `60` | Rate-limit window in seconds. |

### Localisation

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOCALE` | `en` | Default locale for the I18n module. |
| `TINA4_LOCALE_DIR` | `src/locales` | Directory containing locale JSON files. |

### Email

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MAIL_HOST` | `localhost` | SMTP server hostname. |
| `TINA4_MAIL_PORT` | `587` | SMTP server port. |
| `TINA4_MAIL_USERNAME` | _(empty)_ | SMTP authentication username. |
| `TINA4_MAIL_PASSWORD` | _(empty)_ | SMTP authentication password. |
| `TINA4_MAIL_FROM` | _(inherits username or `noreply@localhost`)_ | Default sender email address. |
| `TINA4_MAIL_FROM_NAME` | _(empty)_ | Default sender display name. |
| `TINA4_MAIL_ENCRYPTION` | `tls` | Connection encryption. Options: `tls`, `ssl`, `none`. |
| `TINA4_MAIL_IMAP_HOST` | _(empty)_ | IMAP server for inbound mail. |
| `TINA4_MAIL_IMAP_PORT` | `993` | IMAP server port. |
| `TINA4_MAIL_IMAP_USERNAME` | _(inherits `TINA4_MAIL_USERNAME`)_ | IMAP authentication username. |
| `TINA4_MAIL_IMAP_PASSWORD` | _(inherits `TINA4_MAIL_PASSWORD`)_ | IMAP authentication password. |
| `TINA4_MAIL_IMAP_ENCRYPTION` | `tls` | IMAP transport encryption. Options: `tls`, `starttls`, `none`. Invalid values fall back to `tls`. |
| `TINA4_MAIL_TLS_INSECURE` | `false` | When `true`, skips TLS certificate validation. Leave off outside trusted dev setups. |
| `TINA4_MAILBOX_DIR` | `data/mailbox` | Dev mailbox directory. All outbound mail lands here when `TINA4_DEBUG=true`. |

### Queues

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_QUEUE_BACKEND` | `file` | Queue backend. Options: `file`, `kafka`, `rabbitmq`, `mongo`, `database`. |
| `TINA4_QUEUE_PATH` | `data/queue` | Filesystem path for the file backend. |
| `TINA4_QUEUE_URL` | _(none)_ | Unified connection URL for remote backends (AMQP / Kafka / Mongo). Per-field variables below override it. |
| `TINA4_KAFKA_BROKERS` | `localhost:9092` | Comma-separated broker list. |
| `TINA4_KAFKA_GROUP_ID` | `tina4_consumer_group` | Kafka consumer group ID. |
| `TINA4_RABBITMQ_HOST` | `localhost` | RabbitMQ host. |
| `TINA4_RABBITMQ_PORT` | `5672` | RabbitMQ port. |
| `TINA4_RABBITMQ_USERNAME` | `guest` | RabbitMQ username. |
| `TINA4_RABBITMQ_PASSWORD` | `guest` | RabbitMQ password. |
| `TINA4_RABBITMQ_VHOST` | `/` | RabbitMQ virtual host. |
| `TINA4_MONGO_URI` | _(empty)_ | Full MongoDB connection string. Overrides host/port when set. |
| `TINA4_MONGO_HOST` | `localhost` | MongoDB host. |
| `TINA4_MONGO_PORT` | `27017` | MongoDB port. |
| `TINA4_MONGO_USERNAME` | _(empty)_ | MongoDB username. |
| `TINA4_MONGO_PASSWORD` | _(empty)_ | MongoDB password. |
| `TINA4_MONGO_DB` | `tina4` | MongoDB database name. |
| `TINA4_MONGO_COLLECTION` | `tina4_queue` | MongoDB collection name for jobs. |

### WebSocket

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_WS_BACKPLANE` | _(none)_ | Backplane type for multi-instance broadcasts. Options: `redis`, `nats`. Empty = local-only. |
| `TINA4_WS_BACKPLANE_URL` | `redis://localhost:6379` | Connection URL for the chosen backplane (NATS defaults to `nats://localhost:4222`). |
| `TINA4_WS_ALLOWED_ORIGINS` | _(empty)_ | Comma-separated WebSocket origin allow-list. Empty allows all origins. |
| `TINA4_WS_IDLE_TIMEOUT` | `0` | Idle-connection reaper interval in seconds. `0` disables it. |
| `TINA4_WS_MAX_FRAME_SIZE` | `1048576` | Maximum WebSocket frame size in bytes (1 MB). |

### GraphQL

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_GRAPHQL_ENDPOINT` | `/graphql` | URL path the GraphQL handler is mounted on. POST serves queries, GET serves the IDE. |
| `TINA4_GRAPHQL_AUTO_SCHEMA` | `true` | Auto-build the GraphQL schema from every registered ORM model on boot. Set `false` to define the schema manually. |
| `TINA4_GRAPHQL_MAX_DEPTH` | `50` | Maximum query selection depth (DoS guard). `0` or lower disables the limit. |

### Swagger / OpenAPI

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SWAGGER_ENABLED` | _(inherits `TINA4_DEBUG`)_ | Toggle the Swagger UI independently of debug mode. Set `true` in production to keep API docs available. |
| `TINA4_SWAGGER_TITLE` | `Tina4 API` | OpenAPI spec title. |
| `TINA4_SWAGGER_VERSION` | `1.0.0` | OpenAPI spec version. |
| `TINA4_SWAGGER_DESCRIPTION` | _(empty)_ | OpenAPI spec description. |
| `TINA4_SWAGGER_CONTACT_EMAIL` | _(empty)_ | Contact email rendered in the spec's `info.contact.email` field. |
| `TINA4_SWAGGER_LICENSE` | _(empty)_ | License name in the spec's `info.license.name` field (e.g. `MIT`, `Apache-2.0`). |

### Services (background tasks)

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SERVICE_DIR` | `src/services` | Directory scanned for service classes. |
| `TINA4_SERVICE_SLEEP` | `5` | Seconds the service runner sleeps between iterations. |

---

## AI / Dev-Admin (Python today - rolling out to all)

These power the dev dashboard's AI chat, RAG code search, and the MCP developer-tools endpoint. They are fully wired in Python today and rolling out to PHP, Ruby, and Node.js for parity. The dashboard AI defaults to a **local model served via Ollama** - nothing leaves your machine unless you point the URLs at a remote endpoint. If you run the hosted Tina4 AI services, put their URLs in your own `.env`.

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MCP` | _(inherits `TINA4_DEBUG`)_ | Toggle the built-in MCP dev-tools server. Set explicitly to keep the MCP endpoint exposed in a debug-disabled deployment. |
| `TINA4_MCP_PORT` | _(framework port + 2000)_ | TCP port for the MCP server. The offset keeps it clear of the main server and the AI test port. |
| `TINA4_MCP_REMOTE` | `false` | The MCP dev tools auto-enable in debug mode only on localhost. Set `TINA4_MCP_REMOTE=true` to allow them on a non-localhost host (an explicit `TINA4_MCP=true` also exposes them on any host). |
| `TINA4_AI_URL` | `http://localhost:11437/api/chat` | OpenAI-compatible chat/completion endpoint. Ollama by default; can point at any compatible provider. |
| `TINA4_AI_MODEL` | `qwen2.5-coder:14b` | Model identifier the endpoint should serve. |
| `TINA4_RAG_URL` | `http://localhost:11438` | RAG service endpoint for framework code search. |
| `TINA4_RAG_TOPK` | `4` | Number of nearest-neighbour matches the RAG search returns per query. |
| `TINA4_VISION_URL` | `http://localhost:11437/api/chat` | Vision-model endpoint for the dev dashboard vision tools. |
| `TINA4_EMBED_URL` | `http://localhost:11437/api/embeddings` | Embeddings endpoint used to index the framework and `src/`. |
| `TINA4_IMAGE_URL` | `http://localhost:11437/api/generate` | Image-generation endpoint for the dev dashboard image tools. |
| `TINA4_SUPERVISOR_URL` | `http://localhost:9999` | URL of the Rust agent supervisor proxied by the dev dashboard. Derived from the agent/base port when unset. |
| `TINA4_AGENT_PORT` | _(none)_ | Agent port used to derive `TINA4_SUPERVISOR_URL`. |
| `TINA4_ENABLE_FEEDBACK` | `false` | Master switch for the dev-dashboard feedback widget. |
| `TINA4_FEEDBACK_WHITELIST` | _(empty)_ | Comma-separated allow-list of users who can submit feedback. |
| `TINA4_FEEDBACK_DEV_USER` | _(empty)_ | Identity attached to feedback submitted from the dev dashboard. |

---

## Framework-specific (PHP)

These variables only the PHP framework reads.

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_JWT_ALGORITHM` | `HS256` | JWT signing algorithm. Supports `HS256`, `HS384`, `HS512`. |
| `TINA4_SESSION_HANDLER` | _(inherits `TINA4_SESSION_BACKEND`)_ | Alternate session handler/backend name. Overrides `TINA4_SESSION_BACKEND`. |
| `TINA4_SESSION_REDIS_URL` | _(none)_ | Full `redis://` URL for Redis sessions. Overrides the individual host/port fields. |
| `TINA4_PHP_SESSION_NAME` | `PHPSESSID` | Cookie name used by native PHP `$_SESSION` (separate from the framework session). |
| `TINA4_PHP_SESSION_PATH` | _(basePath/data/sessions-php)_ | `session.save_path` for native PHP sessions, configured before `session_start()`. |
| `TINA4_WS_PORT` | _(inherits port)_ | Separate port for a standalone WebSocket server. Leave unset to share the HTTP port. |

---

## Configuration Recipes

The tables above list every knob. These are the setups most apps actually reach for, ready to paste into `.env`. Each block sets only what the feature needs. Everything else keeps its default.

### PostgreSQL in production

One URL points the ORM, the migrations, and the query builder at Postgres. Credentials can ride in the URL or sit in their own variables, which keeps the password out of your shell history.

```bash
TINA4_DATABASE_URL=postgresql://localhost:5432/myapp
TINA4_DATABASE_USERNAME=myapp
TINA4_DATABASE_PASSWORD=changeme
TINA4_DB_POOL=4
```

`TINA4_DB_POOL=4` opens four connections and rotates across them. Leave it at `0` for a single connection on a small app.

### A shared cache on Redis

The response cache and the cross-request query cache both speak to the same Redis. Point them at it and every instance shares one cache, invalidated globally on every write.

```bash
TINA4_CACHE_BACKEND=redis
TINA4_CACHE_URL=redis://localhost:6379
TINA4_DB_CACHE=true
TINA4_DB_CACHE_BACKEND=redis
TINA4_DB_CACHE_URL=redis://localhost:6379
```

If Redis is down or the driver is missing, the cache logs a warning and falls back to the file backend. It never silently stops caching.

### Sessions that survive more than one box

The file backend is fine for a single server. Move sessions to Redis the moment you run more than one instance, so a user stays logged in whichever instance answers the next request.

```bash
TINA4_SESSION_BACKEND=redis
TINA4_SESSION_REDIS_HOST=localhost
TINA4_SESSION_REDIS_PORT=6379
TINA4_SESSION_SECURE=true
TINA4_SESSION_SAMESITE=Strict
```

`TINA4_SESSION_SECURE=true` keeps the cookie off plain HTTP. Turn it on once you have TLS.

### A queue on RabbitMQ or Kafka

One URL is enough for RabbitMQ; the per-field variables only exist for split configs. The queue API stays identical whichever backend you pick.

```bash
TINA4_QUEUE_BACKEND=rabbitmq
TINA4_QUEUE_URL=amqp://guest:guest@localhost:5672/
```

Kafka reads a broker list instead:

```bash
TINA4_QUEUE_BACKEND=kafka
TINA4_KAFKA_BROKERS=localhost:9092
TINA4_KAFKA_GROUP_ID=myapp_workers
```

### WebSocket broadcasts across instances

A single server broadcasts in memory. Add a backplane and a message sent on one instance reaches clients connected to every other instance.

```bash
TINA4_WS_BACKPLANE=redis
TINA4_WS_BACKPLANE_URL=redis://localhost:6379
TINA4_WS_ALLOWED_ORIGINS=https://myapp.com
```

Set the origin allow-list in production. Empty allows every origin, which is fine in dev and risky on the public internet.

### Locked-down production headers

The defaults are already safe. These four tighten the screws for a public site on HTTPS.

```bash
TINA4_CORS_ORIGINS=https://myapp.com,https://www.myapp.com
TINA4_HSTS=31536000
TINA4_FRAME_OPTIONS=DENY
TINA4_SESSION_SECURE=true
```

Never pair `TINA4_CORS_CREDENTIALS=true` with `TINA4_CORS_ORIGINS=*`. Name your real origins instead.

### The dev dashboard AI, kept local

The dashboard AI talks to a local model through Ollama by default, so nothing leaves your machine. Point the URLs elsewhere only when you run the hosted Tina4 AI services.

```bash
TINA4_AI_URL=http://localhost:11437/api/chat
TINA4_AI_MODEL=qwen2.5-coder:14b
TINA4_RAG_URL=http://localhost:11438
```

---

## Minimal `.env` for Development

```bash
TINA4_DEBUG=true
TINA4_LOG_LEVEL=DEBUG
TINA4_NO_BROWSER=true
```

Debug mode lights up the Swagger UI, the dev dashboard, detailed error pages, and live reload. Keeping the browser flag on stops a new tab opening every time you save a file.

---

## Minimal `.env` for Production

```bash
TINA4_SECRET=your-long-random-secret-here
TINA4_DATABASE_URL=postgresql://user:password@db-host:5432/myapp
TINA4_CORS_ORIGINS=https://myapp.com,https://www.myapp.com
TINA4_HSTS=31536000
TINA4_MAIL_HOST=smtp.example.com
TINA4_MAIL_PORT=587
TINA4_MAIL_USERNAME=noreply@myapp.com
TINA4_MAIL_PASSWORD=your-smtp-password
TINA4_MAIL_FROM=noreply@myapp.com
```

No `TINA4_DEBUG`. It defaults to `false`, which is what you want in production. Set a real secret, a real database, locked-down CORS origins, HSTS, and SMTP credentials if you send email. Everything else has a production-appropriate default.
