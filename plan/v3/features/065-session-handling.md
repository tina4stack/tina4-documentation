# Feature 065: Session lifecycle

## Identity and status

- Matrix identity: 65 - Session lifecycle
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 by reading each session module, its file
  backend, and its cookie/route integration at current HEADs - Python `386cd6d`
  (`tina4_python/session/__init__.py`), PHP `743b7469` (`Tina4/Session.php`), Ruby `c61250c8`
  (`lib/tina4/session.rb`), Node `26be920` (`packages/core/src/session.ts` + `dispatchPipeline.ts`).
  No framework code changed.
- Dependencies: the cookie/header surface (Feature 6 dispatch), the session providers (Features
  66-71), Feature 64 (a session may carry an auth token, but validation is Feature 64)
- Dependants: every stateful request; the CSRF flow; the dev-admin UI
- Existing ADRs: ADR-0021 (session id opaque + strict adoption + no-constructor-IO + loud-then-
  degrade), ADR-0027 (`ttl<=0` means the configured default, not never-expires), ADR-0028 (the
  database backend follows the configured connection), ADR-0024 (`session_contract.json`)
- Shared fixtures: `session_contract.json` exists and gates the PROVIDER half (ttl honoured, ttl
  units, loud-then-degrade, no-constructor-IO, every-engine, zero-dep-fallback). The LIFECYCLE half
  (entropy, adoption, set semantics, `all()` filtering, cookie attributes, destroy, stored-false,
  regenerate) is NOT yet gated and is owed.
- Catalog phase: Security / sessions

## Why this feature exists

An application needs one session surface that mints an unguessable id, adopts a returning id only
when it is safe to, stores and reads request state, defends against fixation, and sets a hardened
cookie - the SAME way in every language, so a session behaves identically wherever the app runs.
This feature owns that lifecycle. The individual storage backends (file, Redis, Valkey, MongoDB,
memcached, database) are Features 66-71; JWT validation is Feature 64.

## Boundary

Feature 65 owns: session-id generation and strict adoption, fixation defense (regenerate), the
data surface (`get`/`set`/`delete`/`all`/`has`/`clear`), dirty tracking and `save`, `destroy`, the
`flash` one-shot, the session cookie (name and attributes), the backend-failure policy, and the
common provider interface the backends implement. It DELEGATES the actual storage to Features 66-71,
the header transport to the dispatch layer, and any JWT in the session to Feature 64.

## Existing implementation evidence

Measured from source at the HEADs above. The uniform rows are the settled contract; the divergent
rows are the owner decisions.

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| ID entropy | 256-bit (`token_urlsafe(32)`) | 128-bit (`random_bytes(16)`) | 256-bit (`SecureRandom.hex(32)`) | 128-bit (`randomBytes(16)`) |
| Strict adoption (regex + store-holds) | correct | correct | correct | correct |
| File name = SHA-256 of id | yes | yes | yes | yes |
| Store-outage preserves the id | yes | yes | yes | yes |
| `set()` persistence | LAZY (defer to save) | EAGER (auto-save) | LAZY | EAGER |
| `all()` hides reserved keys | NO (exposes `_flash_*`) | YES (`_meta`, `_flash_*`) | NO (exposes `_flash_*`, token) | YES (`_`-prefixed) |
| Stored `false`/`0`/`""` | returned | returned | returned | returned |
| Stored `null` -> default | yes | yes | yes | yes |
| HttpOnly on a malformed config value | FAILS OPEN | FAILS OPEN (app path) | FAILS CLOSED | FAILS CLOSED |
| `ttl<=0` (ADR-0027) | = default | = default | = default | = NEVER-EXPIRES (owed) |
| `destroy()` expires the client cookie | no | no | no | no |
| Backend write failure | degrade | degrade | degrade | degrade |

## Public surface contract

Language-neutral surface (method casing follows each language; reserved key names and the cookie
attribute names are DATA and are identical):

- `start(session_id=None) -> id` - start or adopt. Adopts the supplied id ONLY if it matches
  `[A-Za-z0-9_-]{1,128}` AND the store already holds it (ADR-0021 strict mode); otherwise mints a
  fresh id. `start` doubles as adopt; there is no separate `adopt`.
- `get(key, default=None)`, `set(key, value)`, `delete(key)`, `has(key) -> bool`, `clear()`.
- `all() -> dict` - the user data, with reserved/internal keys removed.
- `save() -> bool` - persist if dirty; returns false on a backend write failure (dirty retained).
- `regenerate() -> id` - rotate the id and PRESERVE the data (post-login fixation defense).
- `destroy()` - delete the store entry and end the session.
- `flash(key, value=None)` - dual-mode: set with a value, read-and-clear without.
- `cookie_header(name=None) -> str` - the Set-Cookie value.
- `gc()` - garbage-collect expired sessions.

The provider interface every backend implements: `read(id)`, `write(id, data, ttl=0)`,
`destroy(id)` required; `gc(max_lifetime)` optional. There is no `exists` method in any framework -
it is NOT part of the contract.

## Inputs and outputs

- Adoption input: an optional cookie id. Output: the adopted id (on a well-formed, known id) or a
  fresh minted id (on malformed, unknown, or store-outage - see the outage rule).
- Data: `get`/`set` operate on an in-memory dict; `save` writes it to the backend with the resolved
  TTL. A stored `false`/`0`/`""` reads back verbatim; a stored `null` reads back as the default
  (deliberate cross-language `??`/`nil?` semantics; `has()` disambiguates).
- Cookie output: `name=<id>; Path=/; HttpOnly; SameSite=<v>; [Secure]; Max-Age=<ttl>` - attributes
  per the cookie rules below.

## Lifecycle and operation graph

1. ADOPT: `start(cookie_id)` validates the alphabet, then reads the store. A well-formed KNOWN id is
   adopted; a malformed or well-formed-UNKNOWN id is discarded and a fresh id minted. A store READ
   FAILURE preserves the supplied id (degrade to empty) rather than rotating - the outage rule.
2. READ/WRITE: `get`/`set` mutate the in-memory data and set the dirty flag. Persistence is either
   lazy (at request end via `save`) or eager (on each `set`) - the divergence SS-02.
3. REGENERATE: rotate the id, keep the data, destroy the old record, persist under the new id.
4. DESTROY: delete the store entry and clear local state. Whether the client cookie is actively
   expired is the divergence SS-06 (today: no framework emits an expiring cookie).
5. SAVE: on a backend failure, log loud and degrade - the request still serves, `save` returns
   false, the dirty flag is retained for retry (ADR-0021); strict mode re-raises.

## Configuration and precedence

Environment variables (canonical set in all four): `TINA4_SESSION_BACKEND` (default file; an unknown
value RAISES), `TINA4_SESSION_TTL` (default 3600), `TINA4_SESSION_STRICT` (default false),
`TINA4_SESSION_PATH` (default `data/sessions`), `TINA4_SESSION_NAME` (default `tina4_session`),
`TINA4_SESSION_SAMESITE` (default Lax), `TINA4_SESSION_HTTPONLY` (default true),
`TINA4_SESSION_SECURE` (default false).

Precedence and drift to settle:
- PHP additionally accepts `TINA4_SESSION_HANDLER` as the primary backend selector (falling back to
  `TINA4_SESSION_BACKEND`); the other three read only `TINA4_SESSION_BACKEND`. Standardise (EN-01).
- PHP documents `TINA4_SESSION_REDIS_URL` (`Session.php:23`) but the Redis handler never reads it -
  doc drift (DOC-01).

## Failures, side effects and security

- FIXATION is defended uniformly: strict adoption (a well-formed-unknown id is discarded, ADR-0021)
  and `regenerate()` (rotate + preserve data) are correct in all four. This is the security core and
  it holds.
- PATH TRAVERSAL is closed: the file backend derives the on-disk name from a SHA-256 of the id after
  a validate-or-refuse guard, so the historical `../` arbitrary-write/read (PHP and Node) is gone.
- STORE OUTAGE does not log users out: a read that THROWS preserves the supplied id and degrades to
  an empty session; only a HEALTHY miss discards the id (ADR-0021). Correct in all four.
- HttpOnly FAIL-OPEN (SS-04): Python (`session/__init__.py:603`) and PHP (`DotEnv.php:417` via
  `Session::cookieHeader`) decide HttpOnly with a truthy-ALLOWLIST on a default-ON flag, so a
  malformed value (`TINA4_SESSION_HTTPONLY=enabled`) DROPS HttpOnly. Ruby (`session.rb:322`) and Node
  (`session.ts:894`) use a DENYLIST (`false/0/no/off`) and keep HttpOnly on for any unrecognised
  value - fail closed, the correct behaviour. (PHP's Router auto-path hardcodes HttpOnly on, so only
  the app-callable `cookieHeader()` path is exposed; Python's live path IS `cookie_header`.)
- `all()` LEAKS INTERNALS (SS-03): Python and Ruby return the full data dict including `_flash_*`
  (and, in Ruby, a stored auth token), so an app that serialises `session.all()` into a response
  leaks reserved keys. PHP and Node strip reserved keys (`_meta`/`_flash_*` and `_`-prefixed). The
  documented contract is "excludes internals", so Python and Ruby violate their own docs.
- DESTROY LEAVES THE COOKIE (SS-06): no framework emits an expiring `Set-Cookie` (Max-Age=0) on
  `destroy()`; the stale cookie lingers client-side until the next request rejects the now-unknown id
  via strict adoption. Server-side revocation is immediate and safe, but the OWASP "invalidate the
  client cookie on logout" step is skipped.
- SameSite UNVALIDATED (SS-08): all four interpolate `TINA4_SESSION_SAMESITE` verbatim, so a
  malformed value ships as `SameSite=<garbage>` (browsers fall back to Lax; benign but unhardened).

## Wire and persistence contract

- Cookie: `tina4_session=<id>; Path=/; HttpOnly; SameSite=Lax; [Secure]; Max-Age=<ttl>`. Secure is
  off by default and auto-on for an https request (proxy-aware via `x-forwarded-proto`) or
  `SameSite=None`. No `Expires` (Max-Age only) except PHP's Router path which uses `Expires=`.
- Stored record: the data dict plus an absolute expiry deadline resolved at WRITE time from the TTL
  (ADR-0027). A read never consults a handler's TTL, so a reader configured differently cannot
  misjudge another writer's record.
- The id is opaque (ADR-0021): a lookup token carrying no structure the server interprets.

## Providers and substitutability

A provider implements `read`/`write`/`destroy` (and optional `gc`); the lifecycle is provider-
agnostic. Backend selection is one env var (ADR-0024), an unknown name RAISES (no silent disk
fallback), and a backend that fails to construct degrades to a null/in-memory session rather than a
500. The interface is a formal type in Python (a base class) and Node (a TS interface) but
duck-typed convention in PHP and Ruby - a structure gap (SS-07), not a behaviour gap.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| SS-01 | ID entropy is 256-bit in Python/Ruby but 128-bit in PHP (`Session.php:194`) and Node (`session.ts:596`). A 2-2 split. | Pin one entropy (owner decision 1) and gate it in all four. |
| SS-02 | `set()` is LAZY in Python/Ruby (persist at request end) but EAGER in PHP (`Session.php:220`) and Node (`session.ts:618`) - a backend write per mutation, and a store write for a read-only request. | Pin one persistence model (owner decision 2) and gate it. |
| SS-03 | `all()` strips reserved keys in PHP (`Session.php:281`) and Node (`session.ts:653`) but exposes `_flash_*` (and a token in Ruby) in Python (`session/__init__.py:507`) and Ruby (`session.rb:239`), violating the documented "excludes internals". | `all()` strips reserved keys in all four (owner decision 3). |
| SS-04 | HttpOnly FAILS OPEN on a malformed value in Python (`session/__init__.py:603`) and PHP (`DotEnv.php:417`), but fails closed in Ruby/Node. Security. | Fail-closed (denylist) parse in all four (owner decision 4). |
| SS-05 | Node reads `ttl<=0` as NEVER-EXPIRES on file/database/mongodb (`session.ts:247`), contradicting ADR-0027 (`ttl<=0` = configured default); Python/PHP/Ruby comply. Already recorded as "Node is OWED" in ADR-0027. | Implement ADR-0027 in Node's three handlers; re-express `session_mongo_zero_ttl_never_expires` as "`TINA4_SESSION_TTL=0` means never expires". |
| SS-06 | `destroy()` deletes the store entry but emits no expiring `Set-Cookie` in any framework; the client keeps a dead cookie until the next request. | Emit an expiring cookie (Max-Age=0) on destroy in all four (owner decision 5). |
| SS-07 | The provider interface is a formal type in Python/Node but duck-typed in PHP/Ruby; the contract is convention-only there. | Document the provider contract uniformly; a formal interface (PHP/Ruby) is optional hardening. |
| SS-08 | `TINA4_SESSION_SAMESITE` is emitted unvalidated in all four; a malformed value ships literally. | Coerce an invalid SameSite to Lax (allow-list Lax/Strict/None) in all four. |
| EN-01 | PHP selects the backend with `TINA4_SESSION_HANDLER` (fallback `TINA4_SESSION_BACKEND`); the others read only `TINA4_SESSION_BACKEND`. | Standardise on `TINA4_SESSION_BACKEND`; keep `TINA4_SESSION_HANDLER` as a documented alias or drop it. |
| DOC-01 | PHP documents `TINA4_SESSION_REDIS_URL` but the Redis handler never reads it. | Fix the doc or read the var. |
| FX-01 | `session_contract.json` gates the provider half only; the lifecycle surface is ungated. | Extend `session_contract.json` with the lifecycle invariants (owner decision 6). |

Not defects (settled, uniform): strict adoption, SHA-256 file naming, store-outage preservation,
stored-`false`, regenerate, degrade-on-failure, and the stored-`null`-returns-default rule (a
deliberate cross-language choice; `has()` disambiguates).

## Owner decisions

Proposed for owner ratification. The uniform behaviour is settled by ADR-0021/0024/0027; these are
the open calls.

1. ID ENTROPY (SS-01). Recommend 256-bit in all four (PHP and Node bump `random_bytes(16)` ->
   `random_bytes(32)` / `randomBytes(16)` -> `randomBytes(32)`). Both clear the OWASP 64-bit floor,
   but there is no security reason to ship HALF the entropy, Python is the master, and more entropy
   has no downside. Breaking only in that ids get longer.
2. `set()` PERSISTENCE (SS-02). Recommend LAZY in all four (PHP and Node stop auto-saving in
   `set`/`delete`/`clear`/`flash`; persist once at request end via `save`). Lazy avoids a store write
   for a read-only request (the ratified Python no-file-for-read-only lock-in test) and the
   per-mutation round-trips of eager, and it matches Django/Rails/express-session (ADR-0012 mainstream
   tier). A behaviour change for PHP/Node, so it needs explicit sign-off.
3. `all()` FILTERING (SS-03). Recommend `all()` strips reserved keys (`_meta`, `_flash_*`, and any
   internal `_`-prefixed key) in all four, matching PHP/Node and the documented contract. Python and
   Ruby are broken against their own docs and must change (fix Python, do not mirror the leak).
4. HttpOnly PARSE (SS-04). Recommend fail-closed (denylist `false/0/no/off`, default ON) in all four;
   Python and PHP fix their allowlist parse. Security hardening; Ruby/Node are already correct.
5. DESTROY COOKIE (SS-06). Recommend `destroy()` emits an expiring `Set-Cookie` (Max-Age=0, empty
   value) in all four, so logout invalidates the client cookie (OWASP) rather than relying on the
   next request. Uniform addition.
6. FIXTURE (FX-01). Extend `session_contract.json` with the lifecycle invariants (entropy, adoption,
   set-persistence, `all()` filtering, HttpOnly-fail-closed, destroy-cookie, stored-false, regenerate)
   so the lifecycle is one executable oracle alongside the provider invariants.

ADR-0027 (SS-05) is already Accepted and records Node as OWED; it is an implementation task, not a
new decision. SS-07 (formal interface), SS-08 (SameSite allow-list), EN-01 and DOC-01 are minor
hardening/consistency items to fold into the same pass.

## Proposed conformance fixture

Extend `plan/v3/fixtures/session_contract.json` with lifecycle invariants driving four runners
against REAL storage (no doubles - a store outage is a real stopped backend, a resume is a real
filesystem/redis read, as the existing session tests already do):

- id-entropy: a minted id carries the ratified entropy (owner decision 1), identical in all four.
- strict-adoption: a well-formed-unknown cookie id is discarded and a fresh id minted; a known id is
  adopted; a store-outage preserves the supplied id (over a real stopped backend).
- file-name-is-hashed: a `../`-laden id never becomes a path; the file name is the SHA-256.
- set-persistence: the ratified model (owner decision 2) - a read-only request writes nothing (lazy)
  or the pinned behaviour, identical in all four.
- all-filters-internals: `all()` never returns a `_flash_*`/`_meta`/reserved key (owner decision 3).
- httponly-fail-closed: a malformed `TINA4_SESSION_HTTPONLY` still emits HttpOnly (owner decision 4).
- destroy-expires-cookie: `destroy()` emits a Max-Age=0 cookie (owner decision 5).
- stored-false: a stored `false`/`0`/`""` reads back, not the default (real write + real resume).
- regenerate: the id rotates, the data survives, the old record is destroyed.
- ttl-zero-is-default: `write(id, data, 0)` uses `TINA4_SESSION_TTL`, and `TINA4_SESSION_TTL=0` is
  the never-expires path (ADR-0027) - closes Node's owed gap.

## Integration map

- The dispatch layer reads the cookie and emits Set-Cookie; the session module builds the header.
- Features 66-71 are the storage providers behind the `read`/`write`/`destroy` interface.
- Feature 64 owns any JWT stored in the session; ADR-0021 keeps the session id itself opaque.
- Central fixture, four runners, the CI matrix, and the session docs (`docs/*/sessions*`, plus the
  CLAUDE.md session sections that claim `all()` excludes internals) update together.

## Breaking changes and migration

- Owner decision 1 lengthens ids (PHP/Node) - cosmetic; existing sessions still validate.
- Owner decision 2 makes PHP/Node lazy: an app relying on a mid-request eager write must call `save()`
  explicitly if it needs persistence before request end. `Breaking:` note.
- Owner decision 3 makes Python/Ruby `all()` stop returning `_flash_*`: an app reading a flash value
  out of `all()` must use `flash()`/`get()`. `Breaking:` and a leak fix.
- Owner decision 4 (HttpOnly) and 5 (destroy cookie) are security hardening; no app breaks.
- SS-05 (Node ttl=0) is a `Breaking:` for a Node app that passed a per-call `0` to mean immortal - it
  now means the default; immortality moves to `TINA4_SESSION_TTL=0` (ADR-0027 migration).

## Implementation backlog

1. Extend `session_contract.json` with the lifecycle invariants (FX-01) and wire four runners.
2. Ratify owner decisions 1-6; gate entropy (SS-01), set-persistence (SS-02), `all()` filtering
   (SS-03), HttpOnly fail-closed (SS-04) and destroy-cookie (SS-06) in all four.
3. Close Node's ADR-0027 gap (SS-05): three handlers resolve `ttl<=0` to the default; re-express the
   never-expires test.
4. Fold in SS-07 (document/formalise the provider interface), SS-08 (SameSite allow-list), EN-01 and
   DOC-01.
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the session as: mint a 256-bit opaque id; adopt a returning id ONLY when it matches
`[A-Za-z0-9_-]{1,128}` and the store holds it, else mint fresh; preserve the supplied id on a store
OUTAGE (degrade to empty) and discard only on a healthy miss. Store the data under a SHA-256 file
name (file backend), never the raw id. `get`/`set` on an in-memory dict with dirty tracking, persist
lazily at request end, and return a stored `false`/`0`/`""` (default only on absent/`null`). `all()`
returns user data with reserved keys stripped. `regenerate()` rotates the id and keeps the data;
`destroy()` deletes the store entry AND emits an expiring cookie. Set the cookie
`HttpOnly` (fail closed on a bad config value), `SameSite=Lax` (allow-list), `Secure` on https,
`Max-Age` from the TTL, where `ttl<=0` means the configured default (ADR-0027). Log-loud-and-degrade
on a backend failure. Prove the port with the fixture: entropy, adoption+outage, hashed file name,
lazy persistence, `all()` filtering, HttpOnly-fail-closed, destroy-cookie, stored-false, regenerate,
and ttl=0=default.

## Audit closure checklist

- [x] Boundary and public surface complete (mint/adopt/get-set/all/save/regenerate/destroy/flash/gc).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (fixation, traversal, outage,
  cookie hardening).
- [x] Wire/storage and provider contracts complete (cookie, stored record, provider interface).
- [x] Existing-language contradictions recorded (SS-01..08, EN-01, DOC-01, FX-01).
- [x] Owner ambiguities recorded (6 proposed; entropy, set-persistence, `all()`-filtering, HttpOnly,
  and destroy-cookie are the key calls; ADR-0027 for Node is owed, not re-decided).
- [x] Proposed shared cases and mutation witnesses complete (real-storage, no-double fixture).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
