# Feature 067: Redis session provider

## Identity and status

- Matrix identity: 67 - Redis session provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the redis session handler in each repo,
  plus the RESP wire client) at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No
  framework code changed.
- Dependencies: Feature 65 (the lifecycle), a Redis server, the RESP transport
- Dependants: any deployment setting `TINA4_SESSION_BACKEND=redis`
- Existing ADRs: ADR-0021 (no-constructor-IO, loud-then-degrade), ADR-0024 (zero-dep fallback, one
  env var selects the backend), ADR-0027 (`ttl<=0` = default)
- Shared fixtures: `session_contract.json` already PROVES ttl-honoured, no-constructor-IO, loud-then-
  degrade and zero-dep-fallback for this backend against a live Redis 7. This packet audits the
  redis-specific contract.
- Catalog phase: Sessions (providers)

## Why this feature exists

A multi-instance deployment needs a session store every instance shares. Redis is that store: the
handler speaks the RESP protocol over a raw socket (no client library required), stores each session
under a prefixed key with a native server-side TTL, and degrades loudly if Redis is unreachable - the
same way in all four.

## Boundary

This feature owns the redis backend's `read`/`write`/`destroy`: the RESP transport, the connection
and AUTH, the key namespace, the native-TTL write, and the JSON serialization. It DELEGATES the
lifecycle, id validation and cookie to Feature 65. Valkey (Feature 68) is the same protocol on a
Redis fork.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport | optional `redis` pkg, else raw RESP | raw RESP only | optional `redis` gem, else raw RESP | raw RESP only |
| Host default | `localhost` | `localhost` | `localhost` | `127.0.0.1` |
| Connect timeout | 10s | 10s | 5s | 2s |
| AUTH (RESP, skip blank) | yes | yes | yes | yes |
| Write command | `SETEX`, else `SET` (ttl<=0) | always `SETEX` | always `SETEX` | `SETEX`, else `SET` (ttl<=0) |
| Native server TTL | yes | yes | yes | yes |
| Key prefix | `tina4:session:` | same | same | same |
| Injection (RESP bulk strings) | safe | safe | safe | safe |
| `ttl<=0` -> default | in handler | in handler | in handler | in Session |

All four have a zero-dependency raw-RESP path (proven). The divergences: the SET-vs-SETEX fallback,
the connect-timeout value, the default host, and where the TTL default is resolved.

## Public surface contract

`read(id) -> data | empty` (`GET <prefix><id>`, JSON-decoded; empty on miss/parse-fail);
`write(id, data, ttl=0)` (`SETEX <key> <ttl> <json>` with a native server-side expiry, `ttl<=0`
resolving to `TINA4_SESSION_TTL`); `destroy(id)` (`DEL <key>`). The key is `tina4:session:<id>`, the
value a JSON string. Expiry is the server's, not a stored deadline.

## Configuration and precedence

`TINA4_SESSION_REDIS_HOST` (default `localhost`, Node `127.0.0.1` - HP-04), `_PORT` (6379),
`_PASSWORD` (unset -> no AUTH), `_DB` (0), `_PREFIX` (`tina4:session:`), and shared `TINA4_SESSION_TTL`
(3600). The constructor opens no socket (ADR-0021); the connection opens on first use with a connect
timeout that DIVERGES (10/10/5/2s, HP-02). Python and Ruby prefer an installed `redis` client and fall
back to raw RESP; PHP and Node are raw-only.

## Failures, side effects and security

- ZERO-DEP: the raw-RESP path (`*N\r\n$len\r\n<arg>\r\n...`) needs no client library, so the same
  `.env` works with or without the optional package (session_contract.json zero-dep-fallback, proven).
- INJECTION is closed: every command is a RESP array of length-prefixed bulk strings, so a session id
  can never inject a command or key fragment.
- AUTH: the password rides a RESP `AUTH` command, skipped when blank; it never appears in a log line.
- DEGRADE: a connection or read failure RAISES, so Feature 65's loud-then-degrade policy (ADR-0021)
  applies - the request still serves, `save` returns false, the failure is logged.
- SET-VS-SETEX (RP-01): Python and Node fall back to a non-expiring `SET` when `ttl<=0`; PHP and Ruby
  ALWAYS `SETEX`, so `TINA4_SESSION_TTL=0` sends `SETEX <key> 0 <value>`, which Redis REJECTS - a
  non-expiring session (the ADR-0027 never-expires path) is impossible on PHP/Ruby redis.

## Wire and persistence contract

The stored value is a JSON string under `tina4:session:<id>`, with the expiry held by Redis itself
(via `SETEX`/`EXPIRE`), not embedded in the value. A key round-trips across frameworks (same prefix,
same JSON). The observable contract: a session set with a TTL is gone from Redis after the TTL, and a
`GET` miss is an empty session.

## Providers and substitutability

The redis backend is one provider behind Feature 65's interface, selected by
`TINA4_SESSION_BACKEND=redis` (ADR-0024). Valkey (Feature 68) is the same RESP protocol; the two
handlers are near-identical apart from env-var prefix. PHP additionally exposes `EXISTS`/`EXPIRE`
(`touch()`); the other three do not.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| RP-01 | PHP and Ruby always `SETEX`, so `TINA4_SESSION_TTL=0` (the ADR-0027 never-expires path) sends `SETEX ... 0`, which Redis rejects; Python/Node fall back to `SET`. | Pin the never-expires handling: `SET` (no expiry) when the resolved ttl is 0, in all four. |
| RP-02 | Connect timeout diverges: Python 10s, PHP 10s, Ruby 5s, Node 2s. | Pin one connect timeout (or one env var) across the four. |
| RP-03 | Default host is `127.0.0.1` in Node but `localhost` in the other three; on a dual-stack box `localhost` may resolve to `::1` first. | Pin one default host across the four. |
| RP-04 | Python and Ruby prefer an optional `redis` client and fall back to raw; PHP and Node are raw-only. The Python docs claim Valkey needs a `valkey` package, but the code imports `redis`. | Confirm the optional-client policy is intended and consistent; fix the Python doc drift. |
| RP-05 | The TTL default is resolved in the handler for Python/PHP/Ruby but in the Session layer for Node (ADR-0027 handler-boundary owed, shared with Feature 65 SS-05). | Node resolves `ttl<=0` to the default in the handler too (the ADR-0027 close-out). |

## Owner decisions

Proposed for owner ratification:

1. NEVER-EXPIRES (RP-01): the redis backend uses `SET` (no expiry) when the resolved ttl is 0 in all
   four, so `TINA4_SESSION_TTL=0` is expressible on every backend (it is not on PHP/Ruby redis today).
2. CONNECT TIMEOUT (RP-02) and DEFAULT HOST (RP-03): pin one value each across the four.
3. OPTIONAL-CLIENT POLICY (RP-04): confirm preferring an installed client with a raw fallback is the
   intended shape (it is the zero-dep-fallback contract); fix the Python valkey-package doc.
4. Node closes the ADR-0027 handler-boundary (RP-05) in step with Feature 69/70.

## Proposed conformance fixture

Extend `session_contract.json` with redis-backend cases driving four runners against a REAL Redis (no
doubles): a write/read round-trip with a native TTL that really expires; `TINA4_SESSION_TTL=0` giving a
non-expiring key on every backend; an id with RESP-special bytes not injecting a command; AUTH with a
real password; and a connection failure degrading loud (over a real stopped port).

## Integration map

- Feature 65 calls `read`/`write`/`destroy`; the RESP transport is shared with Valkey (68).
- `session_contract.json` already proves the shared invariants against a live Redis; the redis-specific
  cases above are added there.
- The session docs describe the redis env vars, the key prefix and the native TTL.

## Breaking changes and migration

- Fixing RP-01 makes `TINA4_SESSION_TTL=0` produce a non-expiring session on PHP/Ruby redis (today it
  errors); additive, no session breaks.
- Pinning the connect timeout / default host is a config change; a deployment relying on the old value
  adjusts its env. `Breaking:` only if the pinned default differs from what a deployment assumed.

## Implementation backlog

1. Add the redis cases to the session fixture and wire four runners against a real Redis.
2. Fix RP-01 (never-expires), pin RP-02/RP-03, close RP-05 (Node handler default).
3. Fix the Python valkey-package doc (RP-04).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the redis backend: speak RESP over a raw socket (arrays of length-prefixed bulk strings),
connecting on first use (never in the constructor) with `AUTH` only when a password is set. `read` is
`GET <prefix><id>` JSON-decoded (empty on miss); `write` is `SETEX <key> <ttl> <json>` with a native
server TTL, using `SET` (no expiry) when the resolved ttl is 0, where `ttl<=0` resolves to
`TINA4_SESSION_TTL`; `destroy` is `DEL`. Raise on a transport failure so the lifecycle degrades. Prove
the port with a native-TTL expiry, a never-expires case, an injection attempt, and a degrade.

## Audit closure checklist

- [x] Boundary and public surface complete (RESP read/write/destroy + key + native TTL).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (zero-dep, injection, AUTH, degrade).
- [x] Wire/storage and provider contracts complete (RESP, JSON value, native TTL).
- [x] Existing-language contradictions recorded (RP-01..05).
- [x] Owner ambiguities recorded (4 proposed; the never-expires SET/SETEX is the key call).
- [x] Proposed shared cases and mutation witnesses complete (real Redis, no doubles).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
