# Feature 071: Memcached session provider

## Identity and status

- Matrix identity: 71 - Memcached session provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the memcached session handler in each
  repo, plus Node's `syncSocket` transport) at Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node
  `26be920`. No framework code changed.
- Dependencies: Feature 65 (lifecycle), a memcached server, the ASCII text transport
- Dependants: any deployment setting `TINA4_SESSION_BACKEND=memcached`
- Existing ADRs: ADR-0021 (no-constructor-IO, degrade), ADR-0024 (zero-dep fallback), ADR-0027
  (`ttl<=0` = default)
- Shared fixtures: `session_contract.json` PROVES ttl-honoured, ttl-units-are-normalised (the 30-day
  exptime cliff), no-constructor-IO, loud-then-degrade and zero-dep-fallback against a live memcached
  1.6.45. This packet audits the memcached-specific contract.
- Catalog phase: Sessions (providers)

## Why this feature exists

A deployment running memcached can keep sessions there. The handler speaks the memcached ASCII text
protocol over a raw socket - no client library - stores each session under a prefixed key with a
native exptime, and handles the protocol's 30-day relative-vs-absolute cliff, the same way in all
four.

## Boundary

This feature owns the memcached backend's `read`/`write`/`destroy`: the text-protocol transport, the
connection, the key namespace (with the 250-byte limit and hashing), the exptime handling, and the
JSON serialization. It DELEGATES the lifecycle to Feature 65.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Transport | raw text, stdlib socket | raw text, `fsockopen` | raw text, stdlib socket | raw text, `node:net` via worker |
| Connection model | new short-lived per command | same | same | ONE persistent worker connection |
| Host default | `localhost` | `localhost` | `localhost` | `127.0.0.1` |
| Configurable timeout | 5s | 5s | 5s | none (hard-coded 2s connect) |
| Commands | `set`/`get`/`delete` | same (+ `exists`/`touch`) | same | same |
| 30-day exptime cliff | convert (not clamp) | convert | convert | convert |
| `ttl<=0` -> default | yes | yes | yes | yes |
| Key prefix | `tina4:session:` | same | same | same |
| Key > 250 bytes / control char | SHA-256 hash | same | same | same |
| Injection (CRLF -> hash) | closed | closed | closed | closed |

This backend is at STRONG parity: the 30-day exptime cliff and the `ttl<=0` default are uniform (both
fixed across all four), the wire protocol and key handling agree, and injection is closed. The
divergences are all Node's transport shape (host, connection model, timeout) plus a control-char
coverage edge and a couple of API/naming asymmetries.

## Public surface contract

`read(id) -> data | empty` (`get <key>`, parse the `VALUE` header for the byte count, JSON-decode;
empty on a miss); `write(id, data, ttl=0)` (`set <key> 0 <exptime> <bytes>\r\n<json>`, `STORED`
expected, `ttl<=0` resolving to `TINA4_SESSION_TTL` and the exptime converted past the 30-day cliff);
`destroy(id)` (`delete <key>`, `NOT_FOUND` is success). The key is `tina4:session:<id>`, hashed to
SHA-256 when it would exceed 250 bytes or contain a space/control character.

## Configuration and precedence

`TINA4_SESSION_MEMCACHED_HOST` (default `localhost`, Node `127.0.0.1` - MC-01), `_PORT` (11211),
`_PREFIX` (`tina4:session:`), and shared `TINA4_SESSION_TTL` (3600). The constructor opens no socket
(ADR-0021). Python/PHP/Ruby open a fresh short-lived connection per command (`close()` a no-op); Node
keeps one persistent worker-thread connection, reconnecting on drop (MC-02).

## Failures, side effects and security

- ZERO-DEP: all four hand-roll the ASCII text protocol over a raw socket, no client library
  (session_contract.json zero-dep-fallback, proven).
- THE 30-DAY EXPTIME CLIFF is handled uniformly (session_contract.json ttl-units, proven): memcached
  treats an exptime > 2592000 as an ABSOLUTE unix timestamp; all four CONVERT a large relative ttl to
  an absolute stamp (never clamp), so `TINA4_SESSION_TTL=2592001` ("about a month") is not silently
  expired-on-write. (The identical guard is ALSO present in the CACHE memcached backend - verified
  2026-08-10, all four guard the 2592000 cliff; the session_contract.json ttl-units narrative that
  recorded the cache side as owed predates that fix.)
- INJECTION is closed: a key that would contain a space/control char (including CRLF) is SHA-256
  hashed, so an arbitrary id cannot inject a protocol command; the coverage edge (MC-04) is
  fail-closed robustness, not a hole.
- DEGRADE: a transport failure RAISES (write raises unless `STORED`) so Feature 65 degrades; a genuine
  miss returns empty and is distinguished from a failure.

## Wire and persistence contract

The stored value is a JSON string under `tina4:session:<id>` (or its SHA-256 when oversized/unsafe),
with the expiry held by memcached via the exptime (past the 30-day cliff, an absolute stamp). A key
round-trips across frameworks (same prefix, same JSON, same exptime handling). The observable
contract: a session set with a ttl is gone from memcached after the ttl, and a `get` miss is empty.

## Providers and substitutability

The memcached backend is selected by `TINA4_SESSION_BACKEND=memcached` (ADR-0024). It is a native-TTL
KV store like Redis/Valkey, but on the memcached text protocol; the 250-byte key limit and the
30-day cliff are its protocol-specific constraints.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| MC-01 | Default host is `127.0.0.1` on Node but `localhost` on the other three (shared shape with Redis RP-03). | Pin one default host across the four. |
| MC-02 | Node keeps one persistent worker-thread connection; Python/PHP/Ruby open a fresh short-lived connection per command. Same wire, different lifecycle/failure surface. | Confirm the connection-model divergence is intended (Node cannot do sync socket I/O without the worker); document it, or align. |
| MC-03 | Node has no configurable timeout (hard-coded 2s connect); Python/PHP/Ruby expose a `timeout` (default 5s). | Give Node a configurable timeout, or pin one value across the four. |
| MC-04 | Control-char coverage edge: Python catches all Unicode whitespace but misses a lone 0x7f; PHP/Ruby/Node catch 0x7f but miss Unicode whitespace above 0x20. Neither is a CRLF-injection vector. | Pin one unsafe-key predicate across the four (hash on any of `[\x00-\x20\x7f]` plus Unicode whitespace) for fail-closed robustness. |
| MC-05 | PHP adds `exists()`/`touch()` the other three lack; Ruby's class is `MemcachedHandler` (module `Tina4::SessionHandlers`), not `MemcachedSessionHandler` like the others. | Decide whether `exists`/`touch` are part of the contract (add to all or drop from PHP); align the Ruby class name. |
| MC-06 | The TTL default is resolved in the handler for all four here (unlike redis/mongo/database where Node resolves it in the Session layer) - so memcached is the one backend where Node's handler already honours ADR-0027. | None - recorded as the parity example. Confirm the other Node handlers converge onto this shape. |

## Owner decisions

Proposed for owner ratification:

1. HOST (MC-01), TIMEOUT (MC-03) and the UNSAFE-KEY PREDICATE (MC-04): pin one default host, one
   timeout policy (Node gets a configurable timeout), and one unsafe-key predicate across the four.
2. CONNECTION MODEL (MC-02): confirm Node's persistent-worker connection vs the others' per-command
   short-lived connection is an accepted, documented divergence (Node's runtime forces it), not a bug
   to "fix" by making the others persistent.
3. API SURFACE (MC-05): decide whether `exists`/`touch` are contract (add to all four) or PHP-only
   extras (drop); rename Ruby's class to `MemcachedSessionHandler` for parity.
4. Use memcached's already-correct handler-side TTL resolution (MC-06) as the target shape when Node's
   redis/mongo/database handlers close their ADR-0027 gaps.

## Proposed conformance fixture

Extend `session_contract.json` (its ttl-units invariant already proves the 30-day cliff on memcached)
with session-memcached cases driving four runners against a REAL memcached (no doubles): a write/read
round-trip with a native exptime; a 60-day ttl surviving with the SERVER's own reported remaining ttl
asserted (convert-not-clamp, as the ttl-units case already does); an oversized/unsafe key hashed
consistently; a CRLF-laden id not injecting a command; and a transport failure degrading loud.

## Integration map

- Feature 65 calls `read`/`write`/`destroy`; the text transport is memcached-specific.
- `session_contract.json` already proves the shared invariants (including the exptime cliff) against a
  live memcached; the memcached-specific cases above are added there.
- Cross-reference: the CACHE memcached backend carries the SAME exptime-cliff guard - verified fixed
  in all four 2026-08-10, so the session and cache memcached backends now agree. Ruby's cache backend
  keeps its own bookkeeping and takes the caller's ttl (not a converted absolute); the guard is in the
  cache-side audit (Feature 77).

## Breaking changes and migration

- Pinning the host/timeout/unsafe-key predicate is a config/robustness change; no session breaks.
- Renaming Ruby's class (MC-05) is internal (no public reference to the class name in app code).
- Adding `exists`/`touch` to the other three, or dropping them from PHP, is additive/removing an extra;
  decide per the owner decision.

## Implementation backlog

1. Add the session-memcached cases to the fixture and wire four runners against a real memcached.
2. Pin the host (MC-01), timeout (MC-03) and unsafe-key predicate (MC-04); settle the connection-model
   and API-surface questions (MC-02, MC-05).
3. (The cache memcached backend already carries the exptime-cliff guard - verified 2026-08-10; no
   port owed. Confirmed at Feature 77.)
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the memcached backend: speak the ASCII text protocol (`set`/`get`/`delete`) over a raw
socket, connecting on first use. `read` parses the `VALUE` header byte count and JSON-decodes (empty
on a miss); `write` is `set <key> 0 <exptime> <bytes>` expecting `STORED`, where the exptime resolves
`ttl<=0` to `TINA4_SESSION_TTL` and CONVERTS any value past 2592000 (30 days) to an absolute unix
timestamp (never clamp); `destroy` is `delete` (`NOT_FOUND` is success). Build the key as
`tina4:session:<id>`, SHA-256-hashing it when it would exceed 250 bytes or contain a space/control
character. Raise on a transport failure so the lifecycle degrades. Prove the port with a native-exptime
expiry, a 60-day convert-not-clamp case (assert the server's remaining ttl), an oversized-key hash,
and a CRLF-injection attempt against a real memcached.

## Audit closure checklist

- [x] Boundary and public surface complete (text-protocol read/write/destroy + key + exptime).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (zero-dep, cliff, injection, degrade).
- [x] Wire/storage and provider contracts complete (text protocol, JSON value, native exptime).
- [x] Existing-language contradictions recorded (MC-01..06; strong parity, Node transport-shape divergences).
- [x] Owner ambiguities recorded (4 proposed; host/timeout/unsafe-key and the connection model).
- [x] Proposed shared cases and mutation witnesses complete (real memcached, server-reported ttl, no doubles).
- [x] Integration map and breaking migrations complete (incl. the cache-backend cross-reference).
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
