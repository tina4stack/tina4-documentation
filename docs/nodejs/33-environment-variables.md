# Appendix: Environment Variables

This is a quick-reference for the 20 most important `.env` variables in Tina4 Node.js. For the complete reference of all 82 variables, see **Book 0: Understanding Tina4, Chapter 4**.

---

## Top 20 Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Bind address. `0.0.0.0` listens on all interfaces, `127.0.0.1` restricts to localhost. |
| `PORT` | `7148` | HTTP server port. |
| `TINA4_DEBUG` | `false` | Master debug toggle. Enables stack traces, Swagger UI, live reload, query logging. Never `true` in production. |
| `SECRET` | `tina4-default-secret` | Secret key for JWT signing. Long, random, never committed to git. |
| `DATABASE_URL` | `sqlite:///data/app.db` | Connection string. The URL scheme selects the driver. |
| `TINA4_AUTOCOMMIT` | `false` | Auto-commit after every write. Default is off -- use explicit `commit()`. |
| `TINA4_CSRF` | `true` | CSRF token validation on POST/PUT/PATCH/DELETE. |
| `TINA4_CORS_ORIGINS` | `*` | Comma-separated allowed origins. In production, list your actual domains. |
| `TINA4_HSTS` | _(empty/off)_ | `Strict-Transport-Security` max-age in seconds. Set to `31536000` in production with HTTPS. |
| `TINA4_CSP` | `default-src 'self'` | `Content-Security-Policy` header. |
| `TINA4_RATE_LIMIT` | `100` | Maximum requests per window per IP. |
| `TINA4_RATE_WINDOW` | `60` | Rate limit window in seconds. |
| `TINA4_SESSION_BACKEND` | `file` | Session storage. Options: `file`, `redis`, `valkey`, `mongo`, `database`. |
| `TINA4_SESSION_TTL` | `3600` | Session expiry in seconds. |
| `TINA4_SESSION_SAMESITE` | `Lax` | SameSite cookie attribute. Options: `Strict`, `Lax`, `None`. |
| `TINA4_WS_BACKPLANE` | _(none)_ | WebSocket backplane type. Set to `redis` for multi-instance broadcasts. |
| `TINA4_WS_BACKPLANE_URL` | `redis://localhost:6379` | Connection URL for the WebSocket backplane. |
| `TINA4_LOG_LEVEL` | `ERROR` | Minimum log level. Options: `ALL`, `DEBUG`, `INFO`, `WARNING`, `ERROR`. |
| `TINA4_TOKEN_LIMIT` | `60` | JWT token lifetime in minutes. |
| `SMTP_HOST` | _(none)_ | SMTP server hostname. |
| `SMTP_PORT` | `587` | SMTP server port. |
| `SMTP_USERNAME` | _(none)_ | SMTP authentication username. |
| `SMTP_PASSWORD` | _(none)_ | SMTP authentication password. |

---

## Minimal .env for Development

```bash
TINA4_DEBUG=true
```

That is it. Every other variable has a sensible default. Debug mode enables the Swagger UI, detailed error pages, and live reload. Start building.

---

## Minimal .env for Production

```bash
SECRET=your-long-random-secret-here
DATABASE_URL=postgresql://user:password@db-host:5432/myapp
TINA4_CORS_ORIGINS=https://myapp.com,https://www.myapp.com
TINA4_HSTS=31536000
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=noreply@myapp.com
SMTP_PASSWORD=your-smtp-password
```

No `TINA4_DEBUG`. It defaults to `false`, which is what you want in production. The five things you must set: a real secret, a real database, locked-down CORS origins, HSTS enabled, and SMTP credentials if your app sends email.
