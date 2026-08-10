# Feature 069: MongoDB session provider

## Identity and status

- Matrix identity: 69 - MongoDB session provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the mongo session handler and its raw
  wire client in each repo) at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No
  framework code changed.
- Dependencies: Feature 65 (lifecycle), a MongoDB server, the OP_MSG wire transport
- Dependants: any deployment setting `TINA4_SESSION_BACKEND=mongodb`
- Existing ADRs: ADR-0021 (no-constructor-IO, degrade), ADR-0024 (zero-dep fallback), ADR-0027
  (`ttl<=0` = default; Node's mongo handler is the recorded OWED case)
- Shared fixtures: `session_contract.json` PROVES ttl-honoured, no-constructor-IO, loud-then-degrade
  and zero-dep-fallback against a live MongoDB 7; `session_mongo_zero_ttl_never_expires` locks Node's
  current (owed) never-expires reading. This packet audits the mongo-specific contract.
- Catalog phase: Sessions (providers)

## Why this feature exists

A deployment already running MongoDB can keep sessions there. The handler speaks the MongoDB wire
protocol (OP_MSG) over a raw socket - no driver required - storing each session as a document keyed by
`_id`, with the expiry checked on read, the same way in all four.

## Boundary

This feature owns the mongo backend's `read`/`write`/`destroy` (and `gc` where present): the OP_MSG
transport, the connection, the `_id`-keyed document, the TTL mechanism, and the collection naming. It
DELEGATES the lifecycle to Feature 65.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport | driver preferred, raw OP_MSG fallback | raw OP_MSG ONLY | gem preferred, raw OP_MSG fallback | driver preferred, raw OP_MSG fallback |
| Connect timeout | 10s | 10s | 10s | 3s |
| Default DB / collection | `tina4` / `sessions` | same | same | same |
| Record | `{_id, data, expires_at, last_accessed}` | + `created_at` | `{_id, data, expires_at, updated_at}` | `{_id, data, expires_at, last_accessed}` |
| TTL mechanism | manual read-time + `gc` | manual read-time only | read-time + TTL index (gem path) + `gc` | manual read-time only |
| `ttl<=0` | -> default | -> default | -> default | NEVER-EXPIRES (owed) |
| `gc` sweeper | yes | no | yes | no |
| Injection (`_id` bound) | safe | safe | safe | safe |

All four ship a raw OP_MSG client (zero-dep, proven); PHP is raw-only. The DB/collection names are at
full parity now (historical PHP-no-collection and Ruby/Node `tina4_sessions` drifts are fixed). The
divergences: Node's `ttl<=0`, Ruby's TTL index, the missing `gc` on PHP/Node, and the connect timeout.

## Public surface contract

`read(id) -> data | empty` (`find` one by `_id`, return the embedded `data`, empty on a miss or an
expired-by-`expires_at` document); `write(id, data, ttl=0)` (upsert `{_id, data, expires_at, ...}`
where `expires_at` is an absolute deadline, `ttl<=0` resolving to `TINA4_SESSION_TTL` - except Node,
MG-01); `destroy(id)` (delete one by `_id`). The document lives in DB `tina4`, collection `sessions`.

## Configuration and precedence

`TINA4_SESSION_MONGO_URI` (canonical; legacy `_URL` alias), `_DB` (default `tina4`), `_COLLECTION`
(default `sessions`). Node additionally reads `_HOST`/`_PORT`/`_USERNAME`/`_PASSWORD` - but its
transports never SEND the credentials (the driver URI is rebuilt host:port-only and the raw path never
authenticates), so `_USERNAME`/`_PASSWORD` are currently INERT (MG-06). The connection opens on first
use (ADR-0021); the connect timeout is 3s on Node, 10s on the other three (MG-05).

## Failures, side effects and security

- ZERO-DEP: all four hand-roll OP_MSG over a raw socket, so the same `.env` works without a driver
  (session_contract.json zero-dep-fallback, proven; Ruby's `MongoWireClient` closed the last gap).
- INJECTION is closed: the id is bound as the `_id` VALUE of a filter document, never interpolated
  into a query string, in all four.
- DEGRADE: a connection/read failure RAISES so Feature 65 degrades (ADR-0021); a genuine miss is
  distinguished from a failure.
- NODE `ttl<=0` = NEVER-EXPIRES (MG-01): Node's mongo handler reads `ttl<=0` as never-expires and has
  no handler-level TTL default, contradicting ADR-0027 (`ttl<=0` = configured default), which
  Python/PHP/Ruby honour. This is the ADR-0027-recorded OWED case, locked by
  `session_mongo_zero_ttl_never_expires`.
- TTL-SWEEP GAP (MG-04): only Ruby (gem path) creates a server-side TTL index; Python and Ruby have a
  `gc()` reaper, but PHP and Node have NONE - an expired mongo document is only removed lazily on the
  next read, so an untouched-but-expired session lingers in the collection indefinitely on PHP/Node.

## Wire and persistence contract

The session is a document `{_id: <session_id>, data: <embedded>, expires_at: <absolute>, ...}` in
`tina4.sessions`. The `data` is an embedded sub-document (not a JSON string). The observable contract:
a session is readable by `_id` until `expires_at` passes; the DB and collection names are identical in
all four so a document written by one framework reads in another. The auxiliary field name diverges
(`last_accessed` vs Ruby's `updated_at`, PHP's extra `created_at`) - cosmetic (MG-03).

## Providers and substitutability

The mongo backend is selected by `TINA4_SESSION_BACKEND=mongodb` (ADR-0024). It stores documents; the
DocStore subsystem (ADR-0025/0026) is a separate concern. A future runtime implements the same
`_id`-keyed document with a read-time `expires_at` check.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MG-01 | Node's mongo handler reads `ttl<=0` as never-expires with no handler TTL default, contradicting ADR-0027; locked by `session_mongo_zero_ttl_never_expires`. | Node resolves `ttl<=0` to `TINA4_SESSION_TTL` in the handler; re-express the test as "`TINA4_SESSION_TTL=0` means never expires" (the recorded ADR-0027 close-out). |
| MG-04 | PHP and Node have no `gc()`/sweeper; an expired-but-untouched document is never removed (only lazily on read). Python/Ruby reap. | Add a `gc()` reaper (or a TTL index) to PHP and Node so expired documents are removed. |
| MG-03 | The auxiliary last-accessed field diverges: `last_accessed` (Python/PHP/Node) vs `updated_at` (Ruby); PHP also writes `created_at`. | Pin one auxiliary-field set across the four. |
| MG-05 | Connect timeout is 3s on Node, 10s on the other three. | Pin one connect timeout across the four. |
| MG-06 | Node reads `_USERNAME`/`_PASSWORD` but neither transport sends them (driver URI rebuilt host:port-only; raw path never authenticates) - inert credentials. | Either send the credentials (real AUTH) or drop the inert env vars; do not advertise auth that does nothing. |
| MG-02 | PHP is raw-OP_MSG-only (no driver path); the other three prefer a driver and fall back. | Confirm the raw-only choice for PHP is intended (it satisfies zero-dep); otherwise add a driver-preferred path for parity. |
| DOC-01 | `tina4-python/tina4_python/CLAUDE.md` still lists `tina4_sessions` as the default DB; the code default is `tina4`. | Fix the Python doc. |

## Owner decisions

Proposed for owner ratification:

1. NODE ttl=0 (MG-01): resolve `ttl<=0` to the configured default in the Node handler (the ADR-0027
   close-out), re-expressing the never-expires test as a `TINA4_SESSION_TTL=0` case.
2. REAP EXPIRED (MG-04): PHP and Node gain a `gc()` (or a TTL index) so expired documents do not
   accumulate; pin whether the contract is read-time-only, gc, or a server TTL index across the four.
3. AUXILIARY FIELDS (MG-03) and CONNECT TIMEOUT (MG-05): pin one set / one value.
4. NODE CREDENTIALS (MG-06): send them or drop them - no inert auth env vars.

## Proposed conformance fixture

Extend `session_contract.json` with mongo-backend cases driving four runners against a REAL MongoDB
(no doubles, as the existing mongo cases already do): a write/read round-trip by `_id`; an
`expires_at` past deadline reading as a miss; `TINA4_SESSION_TTL=0` giving a non-expiring document on
every backend (closing MG-01); a `gc()` removing an expired document on every backend (closing MG-04);
an `_id` with query-operator-looking bytes bound as a value (injection); and a document written by one
framework read by another (parity).

## Integration map

- Feature 65 calls `read`/`write`/`destroy`; the OP_MSG transport is mongo-specific.
- `session_contract.json` proves the shared invariants and the Node owed-case against a live MongoDB.
- The session docs describe the mongo env vars, the DB/collection defaults, and the TTL mechanism.

## Breaking changes and migration

- MG-01 changes Node `ttl<=0` from never-expires to default; a Node app passing per-call `0` for
  immortality moves to `TINA4_SESSION_TTL=0` (the ADR-0027 migration). `Breaking:` for that app.
- Adding a `gc()`/TTL index (MG-04) is additive. Sending credentials (MG-06) is additive unless an app
  relied on the current no-auth behaviour against an authed server (it would already have failed).

## Implementation backlog

1. Add the mongo cases to the session fixture and wire four runners against a real MongoDB.
2. Close MG-01 (Node ttl default) and MG-04 (PHP/Node reaper); pin MG-03/MG-05; resolve MG-06.
3. Fix the Python DB-default doc (DOC-01).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the mongo backend: speak OP_MSG over a raw socket (prefer a driver, fall back to raw),
connecting on first use. `read` finds one document by `_id` and returns its embedded `data` (empty on
a miss or a past `expires_at`); `write` upserts `{_id, data, expires_at}` with an absolute deadline,
`ttl<=0` resolving to `TINA4_SESSION_TTL` (0 = never); `destroy` deletes one by `_id`. Bind the id as
a value, never interpolate it. Provide a `gc()` (or a TTL index) so expired documents are reaped.
Raise on a transport failure so the lifecycle degrades. Prove the port with a round-trip, an expiry, a
never-expires case, a reaper, and an injection attempt against a real MongoDB.

## Audit closure checklist

- [x] Boundary and public surface complete (OP_MSG read/write/destroy + `_id` + TTL).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (zero-dep, injection, degrade).
- [x] Wire/storage and provider contracts complete (document shape, DB/collection parity).
- [x] Existing-language contradictions recorded (MG-01..06, DOC-01).
- [x] Owner ambiguities recorded (4 proposed; Node ttl=0 and the expired-document reaper are key).
- [x] Proposed shared cases and mutation witnesses complete (real MongoDB, no doubles).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
