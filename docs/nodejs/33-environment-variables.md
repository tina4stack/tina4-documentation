# Environment Variables

Tina4 Node.js is configured through environment variables, read from `.env` at the project root. Every variable has a sensible default — most projects set three or four values and leave the rest alone.

This chapter lists every variable the Node.js framework reads, grouped by subsystem. Start with the minimum-config examples at the end, then come back here when you need to tune something specific.

---

## Core Server

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Bind address. `0.0.0.0` listens on every interface. `127.0.0.1` restricts to localhost. |
| `PORT` | `7143` | HTTP server port. The Rust CLI prefers `TINA4_PORT` but falls back to `PORT`. |
| `TINA4_PORT` | _(inherits `PORT`)_ | Explicit Tina4-specific port override. Takes precedence over `PORT` when both are set. |
| `HOST_NAME` | `localhost:7148` | Fully-qualified host used in generated absolute URLs (Swagger, OAuth redirects, emails). |
| `TINA4_DEBUG` | `false` | Master debug toggle. Enables Swagger UI, dev dashboard, live reload, template dump filter, error overlay. Never set to `true` in production. |
| `TINA4_NO_BROWSER` | `false` | Stops `tina4 serve` from opening your browser on every restart. |
| `TINA4_NO_RELOAD` | `false` | Disables the dev hot-reload signal from the Rust CLI. Use when you want a stable server for debugging. |

---

## Secrets and Authentication

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET` | _(empty)_ | JWT signing secret. Must be long, random, and unique per environment. **Never commit.** |
| `TINA4_JWT_ALGORITHM` | `HS256` | JWT signing algorithm. Supports `HS256`, `HS384`, `HS512`. |
| `TINA4_TOKEN_LIMIT` | `60` | JWT token lifetime in minutes. |
| `TINA4_API_KEY` | _(empty)_ | Static API key used as a fallback to JWT. |

---

## Database

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | _(required)_ | Connection URL. Scheme selects the driver: `sqlite`, `postgres`, `mysql`. |
| `DATABASE_USERNAME` | _(empty)_ | Overrides the username embedded in `DATABASE_URL`. |
| `DATABASE_PASSWORD` | _(empty)_ | Overrides the password embedded in `DATABASE_URL`. |
| `TINA4_AUTOCOMMIT` | `false` | Auto-commit after every write. Default is off — call `commit()` explicitly. |
| `TINA4_DB_CACHE` | `false` | Enables in-memory query-result caching for read queries. |
| `TINA4_DB_CACHE_TTL` | `30` | Query cache TTL in seconds when `TINA4_DB_CACHE=true`. |
| `ORM_PLURAL_TABLE_NAMES` | `true` | When `true`, the ORM pluralises class names into table names (`User` → `users`). |

---

## CORS

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CORS_ORIGINS` | `*` | Comma-separated allowed origins. Lock down to real domains in production. |

---

## Security Headers

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CSP` | `default-src 'self'` | `Content-Security-Policy` header. |
| `TINA4_CSRF` | `false` | CSRF token validation on POST/PUT/PATCH/DELETE. |
| `TINA4_HSTS` | _(empty/off)_ | `Strict-Transport-Security` max-age in seconds. Set `31536000` in production with HTTPS. |

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
| `TINA4_SESSION_TTL` | `1800` | Session expiry in seconds (30 minutes). |
| `TINA4_SESSION_SAMESITE` | `Lax` | SameSite cookie attribute. Options: `Strict`, `Lax`, `None`. |

---

## Cache

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_CACHE_BACKEND` | `memory` | Response cache backend. Options: `memory`, `file`, `redis`. |
| `TINA4_CACHE_DIR` | `data/cache` | Cache directory for the file backend. |
| `TINA4_CACHE_TTL` | `60` | Default cache TTL in seconds. |
| `TINA4_CACHE_MAX_ENTRIES` | `1000` | Maximum cache entries. |
| `TINA4_CACHE_URL` | `redis://localhost:6379` | Connection URL for remote cache backends. |

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

> `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM`, `SMTP_FROM_NAME`, `IMAP_HOST`, `IMAP_PORT`, `IMAP_USER`, `IMAP_PASS` are accepted as legacy aliases. New projects should use the `TINA4_MAIL_*` names.

---

## Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOG_LEVEL` | `DEBUG` | Minimum log level written to console and files. Options: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `ALL`. |
| `TINA4_LOG_MAX_SIZE` | `10` | Per-file log size limit in megabytes. Rotated when exceeded. |
| `TINA4_LOG_KEEP` | `5` | Number of rotated log files to retain. |

---

## Localisation

| Variable | Default | Description |
|----------|---------|-------------|
| `TINA4_LOCALE` | `en` | Default locale for the `I18n` module. |
| `TINA4_LOCALE_DIR` | `src/locales` | Directory containing locale JSON files. |

---

## Swagger / OpenAPI

| Variable | Default | Description |
|----------|---------|-------------|
| `SWAGGER_TITLE` | `Tina4 API` | OpenAPI spec title. |

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
