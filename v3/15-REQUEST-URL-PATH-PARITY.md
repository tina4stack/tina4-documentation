# Request URL / Path / Query-String Parity

## Goal
Unify the request object's URL-related properties across all four frameworks so
a developer (or AI agent) writes the same accessor in any language and gets the
same shape. Eliminate the confusion that has AI agents looping between
`request.url` and `request.path`.

## Context
Audit (2026-05-15) showed three different shapes:

| Framework | `path` | `url` | `query_string` / `queryString` |
|-----------|--------|-------|--------------------------------|
| Python    | ✅ path-only | ❌ missing | ✅ raw query string |
| PHP       | ✅ path-only | ✅ full URL | ❌ missing |
| Ruby      | ✅ path-only | ✅ full URL | ✅ raw query string |
| Node.js   | ❌ missing | ⚠️ Node `IncomingMessage.url` = path+query | ❌ missing |

Docs reference `request.url` in Python examples (logging, scaffolding) — that
attribute doesn't exist, so following the docs would crash. Docs reference
`req.path` in Node examples — also missing.

## Target shape (all four frameworks)

| Attribute | Type | Example | Meaning |
|-----------|------|---------|---------|
| `method` | string | `"GET"` | HTTP method |
| `path` | string | `"/users/42"` | URL path only — no query string |
| `url` | string | `"https://api.example.com/users/42?page=2"` | Full absolute URL — scheme + host + port + path + query |
| `query_string` / `queryString` | string | `"page=2"` | Raw query string (no leading `?`) |
| `query` | dict/array | `{ page: "2" }` | Parsed query params |

Per-language naming:
- Python: `query_string` (snake)
- Ruby:   `query_string` (snake)
- Node:   `queryString` (camel)
- PHP:    `$queryString` (camel — PHP method-style convention)

## Design decisions (approved 2026-05-15)
1. **Node.js `.url` is overridden** to mean the full URL — parity with PHP/Ruby/Python.
   This is a breaking change relative to Node's `IncomingMessage.url` convention.
   Acceptable for v3 parity alignment.
2. **`queryString` added everywhere** — raw query string is useful enough that
   reconstructing it from the parsed dict is wasteful and lossy (order, repeat
   keys, encoding).

## Checklist

### Python (reference)
- [ ] Add `url` and ensure `query_string` is in `__slots__`
- [ ] Compute `url` in `Request.from_scope` (scheme + host + port + path + query)
- [ ] Honor `x-forwarded-proto` and `x-forwarded-host` if present
- [ ] Tests: positive case, with query string, with forwarded headers, no host header fallback

### PHP
- [ ] Add `public readonly string $queryString` property
- [ ] Populate in constructor from `$_SERVER['QUERY_STRING']` (or equivalent)
- [ ] Tests: positive + empty + special chars

### Ruby
- [ ] Already has all three — verify behavior matches Python reference
- [ ] Spec tests asserting parity

### Node.js
- [ ] Add `path: string` to `Tina4Request` interface
- [ ] Add `queryString: string` to `Tina4Request` interface
- [ ] In `createRequest`: set `tReq.path = url.pathname`
- [ ] In `createRequest`: set `tReq.queryString = url.search.replace(/^\?/, "")`
- [ ] In `createRequest`: overwrite `tReq.url` with the full absolute URL string
- [ ] Honor `x-forwarded-proto` for scheme
- [ ] Update existing tests + add new ones

### Docs
- [ ] Fix `docs/python/15-logging.md` — `request.url` now works
- [ ] Fix `docs/python/19-scaffolding.md` — same
- [ ] Fix `docs/nodejs/02-routing.md` and `03-request-response.md` — `req.path` now works
- [ ] Fix `docs/nodejs/10-middleware-security.md` — clarify `req.url` is now full URL
- [ ] Add `request.url` / `request.path` / `request.queryString` table to the request-response chapter in all four languages

### Audit gate
- [ ] Extend `tina4-documentation/scripts/audit-truth.py` to assert
      `request.<attr>` references resolve against the actual Request class

## Risks / Open questions
- Node's `IncomingMessage.url` is a writable string property — overwriting it
  works at runtime, but middleware or libraries that read it before Tina4
  wraps the request will see the original. Tina4 only ever exposes the wrapped
  `Tina4Request` to handlers, so this is fine in practice.
- Anyone relying on `req.url` to be path+query in Node user code will break.
  Document loudly in v3 release notes.

## Parity dashboard (live)
| Step               | Python | PHP    | Ruby   | Node.js |
|--------------------|--------|--------|--------|---------|
| `.path`            | ✅      | ✅      | ✅      | ❌ BUILD |
| `.url` (full)      | ❌ BUILD | ✅      | ✅      | ❌ BUILD |
| `queryString`/`query_string` | ✅      | ❌ BUILD | ✅      | ❌ BUILD |
| Tests              | ❌ BUILD | ❌ BUILD | ❌ BUILD | ❌ BUILD |
| Docs               | ❌ FIX  | ❌ FIX  | ❌ FIX  | ❌ FIX  |
| Audit-truth        | ❌ BUILD | —      | —      | —       |
