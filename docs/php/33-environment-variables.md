# Environment Variables

Tina4 is configured through environment variables, read from `.env` at the project root. Every variable has a sensible default — most projects set three or four values and leave the rest alone.

This chapter lists every variable the PHP framework reads, grouped by subsystem. Start with the minimum-config examples at the end, then come back here when you need to tune something specific.

---

## Core Server

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Bind address. `0.0.0.0` listens on every interface. `127.0.0.1` restricts to localhost. |
| `PORT` | `7145` | HTTP server port. The Rust CLI prefers `TINA4_PORT` but falls back to `PORT`. |
| `TINA4_PORT` | _(inherits `PORT`)_ | Explicit Tina4-specific port override. Takes precedence over `PORT` when both are set. |
| `TINA4_WS_PORT` | _(inherits port)_ | Separate port for the WebSocket server. Leave unset to share the HTTP port. |
| `HOST_NAME` | `localhost:7145` | Fully-qualified host used in generated absolute URLs (Swagger, OAuth redirects, emails). |
| `TINA4_DEBUG` | `false` | Master debug toggle. Enables Swagger UI, dev dashboard, live reload, template dump filter, error overlay. Never set to `true` in production. |
| `TINA4_DEBUG_LEVEL` | `ERROR` | Minimum message level shown when `TINA4_DEBUG=true`. Options: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `ALL`. |
| `TINA4_NO_BROWSER` | `false` | Stops `tina4 serve` from opening your browser on every restart. Recommended during active development. |
| `TINA4_NO_RELOAD` | `false` | Disables the dev hot-reload signal from the Rust CLI. Use when you want a stable server for debugging. |
| `TINA4_SUPPRESS` | `false` | Hides the Tina4 startup banner. Useful in CI and systemd units where stdout is ingested. |
| `TINA4_VERSION` | _(framework)_ | Override the version string reported by `/__dev/api/system`. Mostly for testing. |
| `TINA4_CLI_SERVE` | _(none)_ | Set internally by the Rust CLI to signal managed mode. Do not set manually. |
| `TINA4_INCLUDE_LOCATIONS` | `src/routes,src/orm,src/app` | Comma-separated directories auto-included at boot. |

---

## Secrets and Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET` | _(empty)_ | JWT signing secret. Must be long, random, and unique per environment. **Never commit.** |
| `JWT_ALGORITHM` | `HS256` | JWT signing algorithm. Supports `HS256`, `HS384`, `HS512`. |
| `TINA4_TOKEN_LIMIT` | `60` | JWT token lifetime in minutes. |
| `TINA4_API_KEY` | _(empty)_ | Static API key used by `Auth::validateApiKey()` as a fallback to JWT. |

---

## Database

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | `sqlite:///data/app.db` | Connection URL. Scheme selects the driver: `sqlite`, `postgres`, `mysql`, `mssql`, `sqlserver`, `firebird`. |
| `DATABASE_USERNAME` | _(empty)_ | Overrides the username embedded in `DATABASE_URL`. |
| `DATABASE_PASSWORD` | _(empty)_ | Overrides the password embedded in `DATABASE_URL`. |
| `DB_URL` | _(empty)_ | Legacy alias for `DATABASE_URL`. Prefer `DATABASE_URL` in new projects. |
| `TINA4_AUTOCOMMIT` | `false` | Auto-commit after every write. Default is off — call `commit()` explicitly. |
| `TINA4_DB_CACHE` | `false` | Enables in-memory query-result caching for read queries. |
| `TINA4_DB_CACHE_TTL` | `60` | Query cache TTL in seconds when `TINA4_DB_CACHE=true`. |
| `TINA4_MIGRATION_ID` | _(timestamp)_ | Override the migration ID used when recording applied migrations. |

---

## CORS

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CORS_ORIGINS` | `*` | Comma-separated allowed origins. Lock down to real domains in production. |
| `TINA4_CORS_METHODS` | `GET,POST,PUT,PATCH,DELETE,OPTIONS` | Allowed request methods. |
| `TINA4_CORS_HEADERS` | `Content-Type,Authorization,X-Requested-With` | Allowed request headers. |
| `TINA4_CORS_CREDENTIALS` | `false` | Send `Access-Control-Allow-Credentials: true`. Required for cross-origin cookies. |
| `TINA4_CORS_MAX_AGE` | `600` | Preflight cache lifetime in seconds. |

---

## Security Headers

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CSP` | `default-src 'self'` | `Content-Security-Policy` header. |
| `TINA4_CSRF` | `true` | CSRF token validation on POST/PUT/PATCH/DELETE. Requires `_csrf` in the body or `X-CSRF-Token` header. |
| `TINA4_HSTS` | _(empty/off)_ | `Strict-Transport-Security` max-age in seconds. Set `31536000` in production with HTTPS. |
| `TINA4_FRAME_OPTIONS` | `DENY` | `X-Frame-Options` header. Set `SAMEORIGIN` if you embed your own app in an iframe. |
| `TINA4_REFERRER_POLICY` | `strict-origin-when-cross-origin` | `Referrer-Policy` header. |
| `TINA4_PERMISSIONS_POLICY` | _(empty)_ | `Permissions-Policy` header. Example: `geolocation=(), microphone=()`. |

---

## Rate Limiting

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_RATE_LIMIT` | `100` | Maximum requests per window per IP. Set `0` to disable. |
| `TINA4_RATE_WINDOW` | `60` | Rate-limit window in seconds. |

---

## Sessions

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_BACKEND` | `file` | Storage backend. Options: `file`, `redis`, `valkey`, `mongo`, `database`. |
| `TINA4_SESSION_HANDLER` | _(inherits `_BACKEND`)_ | Alternate handler class name. Overrides `TINA4_SESSION_BACKEND`. |
| `TINA4_SESSION_TTL` | `3600` | Session expiry in seconds. |
| `TINA4_SESSION_SAMESITE` | `Lax` | SameSite cookie attribute. Options: `Strict`, `Lax`, `None`. |
| `TINA4_SESSION_PATH` | `data/sessions` | Filesystem path for the file backend. |

### Redis/Valkey session backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_REDIS_HOST` | `localhost` | Redis host. |
| `TINA4_SESSION_REDIS_PORT` | `6379` | Redis port. |
| `TINA4_SESSION_REDIS_PASSWORD` | _(none)_ | Redis auth password. |
| `TINA4_SESSION_REDIS_DB` | `0` | Redis database number. |
| `TINA4_SESSION_REDIS_URL` | _(none)_ | Full `redis://` URL. Overrides the individual fields when set. |
| `TINA4_SESSION_VALKEY_HOST` | `localhost` | Valkey host. |
| `TINA4_SESSION_VALKEY_PORT` | `6379` | Valkey port. |
| `TINA4_SESSION_VALKEY_PASSWORD` | _(none)_ | Valkey auth password. |
| `TINA4_SESSION_VALKEY_DB` | `0` | Valkey database number. |

### MongoDB session backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SESSION_MONGO_URL` | `mongodb://localhost:27017` | MongoDB connection string. |
| `TINA4_SESSION_MONGO_DB` | `tina4` | MongoDB database name. |

---

## Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CACHE_BACKEND` | `memory` | Response cache backend. Options: `memory`, `file`, `redis`. |
| `TINA4_CACHE_DIR` | `data/cache` | Cache directory for the file backend. |
| `TINA4_CACHE_TTL` | `60` | Default cache TTL in seconds. |
| `TINA4_CACHE_MAX_ENTRIES` | `1000` | Maximum cache entries. Oldest entries evicted first. |
| `TINA4_CACHE_URL` | _(none)_ | Connection URL for remote cache backends (Redis, Memcached). |

---

## Queues

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_QUEUE_BACKEND` | `file` | Queue backend. Options: `file`, `kafka`, `rabbitmq`, `mongo`, `database`. |
| `TINA4_QUEUE_PATH` | `data/queue` | Filesystem path for the file backend. |
| `TINA4_QUEUE_URL` | _(none)_ | Connection URL for remote backends. |

### Kafka queue backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_KAFKA_BROKERS` | `localhost:9092` | Comma-separated broker list. |
| `TINA4_KAFKA_GROUP_ID` | `tina4_consumer_group` | Kafka consumer group ID. |

### RabbitMQ queue backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_RABBITMQ_HOST` | `localhost` | RabbitMQ host. |
| `TINA4_RABBITMQ_PORT` | `5672` | RabbitMQ port. |
| `TINA4_RABBITMQ_USERNAME` | `guest` | RabbitMQ username. |
| `TINA4_RABBITMQ_PASSWORD` | `guest` | RabbitMQ password. |
| `TINA4_RABBITMQ_VHOST` | `/` | RabbitMQ virtual host. |

### MongoDB queue backend

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MONGO_URI` | _(none)_ | Full MongoDB connection string. Overrides host/port when set. |
| `TINA4_MONGO_HOST` | `localhost` | MongoDB host. |
| `TINA4_MONGO_PORT` | `27017` | MongoDB port. |
| `TINA4_MONGO_USERNAME` | _(none)_ | MongoDB username. |
| `TINA4_MONGO_PASSWORD` | _(none)_ | MongoDB password. |
| `TINA4_MONGO_DB` | `tina4` | MongoDB database name. |
| `TINA4_MONGO_COLLECTION` | `tina4_queue` | MongoDB collection name for jobs. |

---

## WebSocket Backplane

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_WS_BACKPLANE` | _(none)_ | Backplane type. Set `redis` for multi-instance broadcasts. |
| `TINA4_WS_BACKPLANE_URL` | `redis://localhost:6379` | Connection URL for the backplane. |

---

## Email

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MAIL_HOST` | _(none)_ | SMTP server hostname. |
| `TINA4_MAIL_PORT` | `587` | SMTP server port. |
| `TINA4_MAIL_USERNAME` | _(none)_ | SMTP authentication username. |
| `TINA4_MAIL_PASSWORD` | _(none)_ | SMTP authentication password. |
| `TINA4_MAIL_FROM` | _(none)_ | Default sender email address. |
| `TINA4_MAIL_FROM_NAME` | _(none)_ | Default sender display name. |
| `TINA4_MAIL_ENCRYPTION` | `tls` | Connection encryption. Options: `tls`, `ssl`, `none`. |
| `TINA4_MAIL_IMAP_HOST` | _(none)_ | IMAP server for inbound mail. |
| `TINA4_MAIL_IMAP_PORT` | `993` | IMAP server port. |
| `TINA4_MAILBOX_DIR` | `data/mailbox` | Dev mailbox directory. All outbound mail lands here when `TINA4_DEBUG=true`. |

> `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` are also accepted as aliases for the `TINA4_MAIL_*` equivalents. New projects should use the `TINA4_MAIL_*` names.

---

## Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOG_LEVEL` | `ERROR` | Minimum log level written to files. Options: `ALL`, `DEBUG`, `INFO`, `WARNING`, `ERROR`. |
| `TINA4_LOG_DEBUG` | `0` | Numeric flag for debug-level messages. Used internally by `Debug::message()`. |
| `TINA4_LOG_INFO` | `1` | Numeric flag for info-level messages. |
| `TINA4_LOG_ERROR` | `3` | Numeric flag for error-level messages. |
| `TINA4_LOG_MAX_SIZE` | `10485760` | Per-file log size limit in bytes (10 MB). Rotated when exceeded. |
| `TINA4_LOG_KEEP` | `5` | Number of rotated log files to retain. |

---

## Uploads

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_MAX_UPLOAD_SIZE` | `10485760` | Maximum multipart upload size in bytes (10 MB). |

---

## Localisation

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOCALE` | `en` | Default locale for `I18n`. |
| `TINA4_LOCALE_DIR` | `src/locale` | Directory containing locale JSON files. |

---

## Services (background tasks)

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_SERVICE_DIR` | `src/services` | Directory scanned for service classes. |
| `TINA4_SERVICE_SLEEP` | `1` | Default tick interval (seconds) when a service does not specify one. |

---

## AI and MCP Tooling

The dashboard AI chat and the framework's RAG-based code search both default to a **local qwen2.5-coder model served via Ollama**. Nothing leaves your machine unless you point `TINA4_AI_URL` at a remote endpoint.

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_AI_URL` | `http://localhost:11434` | OpenAI-compatible HTTP endpoint for the chat/completion model (Ollama by default). |
| `TINA4_AI_MODEL` | `qwen2.5-coder` | Model identifier the endpoint should serve. |
| `TINA4_RAG_URL` | _(inherits `TINA4_AI_URL`)_ | Embedding endpoint for the framework RAG index. |
| `TINA4_RAG_MODEL` | `nomic-embed-text` | Embedding model used to index the framework and `src/`. |
| `TINA4_MCP_REMOTE` | `false` | Allow the MCP server to bind on non-localhost interfaces. **Never enable in production.** |
| `TINA4_NO_AI_PORT` | `false` | Disables the MCP port listener in dev mode. |
| `TINA4_OVERRIDE_CLIENT` | `false` | Allow the framework to start without the Rust CLI (`tina4 serve`). Used in Docker images and CI runners; bypasses SCSS compilation, the file watcher, and live reload. |

---

## HTTP Status Constants

For use in route handlers instead of raw integers:

```php
return $response->json($data, \Tina4\HTTP_CREATED);
return $response("<error/>", \Tina4\HTTP_BAD_REQUEST, \Tina4\APPLICATION_XML);
```

See [Chapter 3: Request and Response](./03-request-response.md#http-status-constants) for the full table.

---

## Log-Level Constants

Passed to `Debug::message()` to tag severity:

| Constant | Description |
|----------|-------------|
| `TINA4_LOG_DEBUG` | Verbose developer messages. |
| `TINA4_LOG_INFO` | Normal operational messages. |
| `TINA4_LOG_WARNING` | Non-fatal anomalies. |
| `TINA4_LOG_ERROR` | Recoverable errors. |
| `TINA4_LOG_CRITICAL` | Fatal or security-relevant events. |

```php
\Tina4\Debug::message("User " . $id . " missed the cache", TINA4_LOG_INFO);
```

---

## Minimal `.env` for Development

```bash
TINA4_DEBUG=true
TINA4_DEBUG_LEVEL=DEBUG
TINA4_NO_BROWSER=true
```

That is it. Debug mode lights up the Swagger UI, the dev dashboard, detailed error pages, and live reload. Keeping the browser flag on stops a new tab opening every time you save a file.

---

## Minimal `.env` for Production

```bash
SECRET=your-long-random-secret-here
DATABASE_URL=postgresql://user:password@db-host:5432/myapp
TINA4_CORS_ORIGINS=https://myapp.com,https://www.myapp.com
TINA4_HSTS=31536000
TINA4_MAIL_HOST=smtp.example.com
TINA4_MAIL_PORT=587
TINA4_MAIL_USERNAME=noreply@myapp.com
TINA4_MAIL_PASSWORD=your-smtp-password
TINA4_MAIL_FROM=noreply@myapp.com
```

No `TINA4_DEBUG`. It defaults to `false`, which is what you want in production. Set a real secret, a real database, locked-down CORS origins, HSTS, and SMTP credentials if you send email. Everything else has a production-appropriate default.
