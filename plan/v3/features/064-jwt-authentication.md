# Feature 064: JWT and request authentication

## Identity and status

- Matrix identity: 64 - JWT and request authentication
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 by reading each auth module and its route
  gate at current HEADs - Python `386cd6d` (`tina4_python/auth/__init__.py`), PHP `743b7469`
  (`Tina4/Auth.php`), Ruby `c61250c8` (`lib/tina4/auth.rb`), Node `26be920`
  (`packages/core/src/auth.ts` + `authGate.ts`). No framework code changed.
- Dependencies: the request/header surface (Feature 6 dispatch), the secret/env resolution
- Dependants: every `@secured` route, `authenticate_request`, the CSRF middleware (Feature 37), the
  dev-admin and MCP admin gates
- Existing ADRs: ADR-0021 (session id opaque + unverified credential is not an auth result);
  ADR-0012 (settle against real-world standards); the RS256-opt-in ruling (maintainer, 2026-08-01,
  locked by `auth_rs256_optin` tests in all four)
- Shared fixtures: `auth_contract.json` is required and ABSENT today - each framework carries its own
  copy of `test_auth_session_contract`, so there is no central data oracle for the JWT half
- Catalog phase: Security / authentication

## Why this feature exists

An application needs one authentication surface that mints and verifies tokens, enforces the time
claims, hashes passwords, and gates real routes the SAME way in every language - so a token minted by
the Python service verifies in the Node service, and a `@secured` route answers a caller identically
wherever it runs. This feature owns that surface. Session identity, cookies and session persistence
are Feature 65.

## Boundary

Feature 64 owns: JWT mint/verify (`get_token`/`valid_token`), the configured-algorithm enforcement,
the `exp`/`nbf`/`iat` time claims, the unverified decode (`get_payload`), token refresh, the
request-auth entry point (`authenticate_request`), the static API-key check (`validate_api_key`), the
route-gate auth decision, and the byte-compatible password hash (`hash_password`/`check_password`).
It DELEGATES header parsing to the dispatch layer, the session cookie and its persistence to Feature
65, and the CSRF token round-trip to Feature 37 (which calls `valid_token`). It is distinct from
Feature 65: a session id is an opaque lookup token; a JWT is a signed claims envelope.

## Existing implementation evidence

Measured from source at the HEADs above. Cited file:line in the defect register and owner decisions.

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| HMAC algorithms | HS256/384/512 | same | same | same |
| RS256 present | yes (opt-in) | yes (opt-in) | yes (different model, see RA-*) | yes (opt-in) |
| `alg: none` | rejected | rejected | rejected | rejected |
| Algorithm pinned server-side | yes | yes | yes | yes |
| `exp` boundary | reject at `now >= exp`, int clock | same | same | same |
| Malformed `exp`/`nbf` (present, non-numeric) | rejected | rejected | rejected | rejected |
| `nbf` enforced + leeway | yes, 60s | yes, 60s | yes, 60s | yes, 60s |
| `expires_in = 0` | NO exp -> never expires | never expires | `exp = iat` -> BORN EXPIRED | never expires |
| Basic auth | absent (removed, ADR-0021) | absent | absent | absent |
| `authenticate_request` | JWT -> API key -> null | same | same | same |
| Route gate accepts a raw API key | YES | NO (JWT only) | YES | NO (JWT only) |
| API-key compare | `hmac.compare_digest` | `hash_equals` | `OpenSSL.fixed_length_secure_compare` | `timingSafeEqual` |
| Password hash | `pbkdf2_sha256$260000$salt$hex`, 32-byte key | same | same | same |

The uniform rows are the settled contract. The three non-uniform rows - RS256 model, `expires_in=0`,
and route-gate API key - are the owner decisions below.

## Public surface contract

Language-neutral surface, with the per-language spelling (method casing follows each language; the
JSON claim names and the hash format string are DATA and are identical across all four):

- `get_token(payload, expires_in=60, secret=None, algorithm=None) -> token` - mint a signed JWT.
  `expires_in` is in MINUTES. (`getToken` in PHP/Node; `get_token` Python/Ruby.)
- `valid_token(token) -> payload | null` - verify signature and time claims; return the decoded
  payload or null. (`validToken` PHP/Node.)
- `get_payload(token) -> payload | null` - decode WITHOUT verifying; for reading a claim after
  `valid_token` has already verified the same token. (`getPayload` PHP/Node.)
- `refresh_token(token, expires_in=60) -> token | null` - re-mint from a still-valid token.
- `authenticate_request(headers, secret=None, algorithm=None) -> result | null` - the request-auth
  entry point: a verified Bearer JWT returns its payload; a verified Bearer API key returns
  `{"_auth": "api_key"}`; anything else returns null. NEVER returns truthy for an unverified
  credential (ADR-0021). (`authenticateRequest` PHP/Node.)
- `validate_api_key(provided, expected=None) -> bool` - constant-time compare against
  `TINA4_API_KEY`; false when the key is unset (fail closed).
- `hash_password(password, salt=None, iterations=260000) -> "pbkdf2_sha256$..."` and
  `check_password(password, hash) -> bool` - PBKDF2-HMAC-SHA256, timing-safe verify.

The route gate (per language: `core/server.py` `_check_auth`, `Tina4/Router.php` `enforceRouteAuth`,
`lib/tina4/rack_app.rb` `enforce_route_auth`, `packages/core/src/authGate.ts` `enforceRouteAuth`)
protects a non-public route: writes are secured by default, `@noauth` opens a route, `@secured`
protects one, and the same gate runs for the in-process TestClient so tests exercise the live path.

## Inputs and outputs

- Mint input: a claims dict, a TTL in minutes, an optional secret and algorithm. Output: a
  `header.payload.signature` JWT, base64url, with `iat` always stamped and `exp` stamped only when
  the TTL is > 0.
- Verify input: a token string. Output: the decoded payload on success, null on any failure (bad
  signature, wrong `alg`, expired, not-yet-valid, malformed time claim).
- Request-auth input: the request headers. Output: a verified JWT payload, `{"_auth": "api_key"}`,
  or null.
- Password hash output: `pbkdf2_sha256$<iterations>$<hex-salt>$<hex-derived-key>` - the salt is
  16 bytes (32 hex chars), the derived key 32 bytes (64 hex chars), so any language cross-verifies
  any other language's hash.

## Lifecycle and operation graph

1. MINT: `get_token` stamps `iat = now`, stamps `exp = iat + expires_in*60` only when `expires_in >
   0`, signs the `header.payload` with the pinned algorithm, returns the JWT.
2. VERIFY: `valid_token` decodes the header, requires `header.alg == the server-pinned algorithm`
   (rejecting `none` and any substitution), verifies the signature with the pinned algorithm, then
   checks `exp` (`now >= exp` rejects) and `nbf` (`now + 60 < nbf` rejects), rejecting a present but
   non-numeric time claim. Returns the payload or null.
3. REQUEST-AUTH: `authenticate_request` reads `Authorization: Bearer <x>`; if `valid_token(x)` it
   returns the payload; else if `validate_api_key(x)` it returns `{"_auth": "api_key"}`; else null.
4. ROUTE GATE: on a protected route the gate extracts the token (header, and in some frameworks body
   or session), verifies it, and answers 401 on failure. Whether it ALSO accepts a raw API key is
   the 2-2 split (AK-01).
5. PASSWORD: `hash_password` derives a PBKDF2 key over a random salt; `check_password` recomputes
   with the stored iteration count and salt and compares constant-time.

## Configuration and precedence

Environment variables the auth modules read (canonical set present in all four):

- `TINA4_SECRET` - the HMAC signing/verification secret (or the PEM key material for RS256). Blank
  by default; a blank secret warns loudly and is never a built-in value. In dev-and-not-CI-and-not-
  production it is minted once and persisted to `.env.local`.
- `TINA4_JWT_ALGORITHM` - the signing/verify algorithm, default `HS256`. An explicit `algorithm`
  argument beats the env (ADR-0041).
- `TINA4_API_KEY` - the static API key; unset means `validate_api_key` returns false (fail closed).
- `TINA4_DEBUG`, `CI`, `TINA4_ENV` - gate the dev-secret minting (dev-only, never in CI or
  production).

Precedence and drift to settle:
- Python additionally reads `TINA4_TOKEN_EXPIRES_IN` (and legacy `TINA4_TOKEN_LIMIT`, default 60) for
  the default TTL; PHP, Ruby and Node use the method default of 60 minutes and read NO TTL env var.
  That is a config-surface parity gap (EN-01).
- `TINA4_JWT_ALGORITHM=RS256` selects RS256 in Python, PHP and Node, but RAISES in Ruby, whose
  algorithm is chosen by on-disk key presence instead (RA-01).

## Failures, side effects and security

- ALG SUBSTITUTION is closed in all four: the header `alg` must equal the server-pinned algorithm
  before any signature work, so `none` and an RS256->HS256 downgrade are both rejected. This is the
  single most important JWT footgun and it is handled uniformly.
- UNVERIFIED CREDENTIAL is never an auth result (ADR-0021): the Python Basic branch that returned a
  truthy result for an unchecked base64 string is gone, and no framework has a Basic path.
- TIMING: every credential comparison in every framework is constant-time and length-guarded - the
  JWT HMAC signature, the API key, the password hash, and the MCP admin token. No plain `==`/`===`
  survives on any key path (grep-confirmed per language).
- FAIL-CLOSED: an unset `TINA4_API_KEY` disables API-key auth; a blank `TINA4_SECRET` warns rather
  than substituting a guessable value - EXCEPT the two divergences below.
- SILENT RSA ON A BLANK SECRET (Ruby, RA-03): with a blank `TINA4_SECRET` and no keys on disk,
  Ruby's `get_token` GENERATES an RSA keypair and RS256-signs, instead of failing loud like the
  other three. A blank secret should never silently change the signing model.
- HARDCODED CSRF FALLBACK SECRET (PHP, SEC-01): `Tina4/Middleware/CsrfMiddleware.php:76` and `:118`
  fall back to `'tina4-default-secret'` when `TINA4_SECRET` is unset, then call
  `Auth::validToken($token, $secret)`. A deployment that enables the CSRF middleware without setting
  a secret validates form tokens against a PUBLICLY KNOWN key. This is Feature 37's code, surfaced
  here because it consumes this feature's verifier; it must fail closed, not fall back.
- BORN-EXPIRED TOKEN (Ruby, EX-01): `expires_in: 0` mints a token that is already expired in Ruby,
  while the other three read 0 as non-expiring - a cross-language interop break.

## Wire and persistence contract

- Token wire format: `base64url(header).base64url(payload).base64url(signature)`, header
  `{"alg": <pinned>, "typ": "JWT"}`, claims include `iat` (always) and `exp` (when TTL > 0), plus
  any caller claims. A token minted by one framework verifies in another when both share the secret
  and algorithm - the wire format is identical.
- Password hash persistence: `pbkdf2_sha256$<iterations>$<hex-salt>$<hex-key>`, stored as one
  string, self-describing (algorithm, iterations and salt travel with the hash), so any language
  verifies any language's stored hash. Measured byte-compatible across all four.
- There is no server-side token store; a JWT is stateless. Revocation is by expiry (or an
  application allow/deny list, out of scope here).

## Providers and substitutability

The algorithm is a provider: HMAC (the zero-dependency default) and RS256 (opt-in). HMAC uses each
language's stdlib (Python `hmac`/`hashlib`, PHP `hash_hmac`, Ruby `OpenSSL::HMAC`, Node
`node:crypto`). RS256 uses stdlib asymmetric crypto where the language has it (PHP openssl, Ruby
OpenSSL, Node `node:crypto`) and the optional `cryptography` package in Python - never a hard
dependency, and (per the 2026-08-01 ruling) checked lazily at point of use with a loud, actionable
error when absent. The substitution contract: a caller selects the algorithm by configuration, and
the same token verifies under the same configuration in any framework. RA-01..03 record where Ruby's
provider selection does not yet match that contract.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| AK-01 | Route gate accepts a raw Bearer API key in Python (`core/server.py:1596`) and Ruby (`rack_app.rb:1047`), but is JWT-only in PHP (`Router.php:1639`) and Node (`authGate.ts:51-68`). A 2-2 split: the same static key opens every `@secured` route in two frameworks and none in the other two. | Decide one route-gate contract for all four (owner decision 1) and gate it. |
| EX-01 | `expires_in = 0` is non-expiring in Python (`auth/__init__.py:435`), PHP (`Auth.php:359`) and Node (`auth.ts:394`), but BORN-EXPIRED in Ruby (`auth.rb:299`), which stamps `exp = iat`. Negative values likewise differ. | Decide the 0/negative semantics for all four (owner decision 2) and gate it; Ruby changes regardless. |
| RA-01 | `TINA4_JWT_ALGORITHM=RS256` selects RS256 in Python/PHP/Node but RAISES in Ruby (`auth.rb:165-170`), whose algorithm is chosen by on-disk key presence (`use_hmac?`, `auth.rb:121-129`). Same config, different outcome. | Converge Ruby onto the config-driven model: `TINA4_JWT_ALGORITHM` selects the algorithm in all four. |
| RA-02 | Ruby auto-activates RS256 when `keys/private.pem` + `public.pem` exist on disk; the other three never switch algorithm from disk state. | Remove disk-key auto-activation; RS256 is opt-in by configuration only. |
| RA-03 | Ruby SILENTLY generates an RSA keypair and RS256-signs when `TINA4_SECRET` is blank and no keys exist (`auth.rb:306-308`, `:556-571`); the other three warn on a blank secret and stay HMAC. | A blank secret fails loud in all four; never a silent algorithm switch. Security-relevant. |
| SEC-01 | PHP `CsrfMiddleware` falls back to a hardcoded `'tina4-default-secret'` (`CsrfMiddleware.php:76`, `:118`) when `TINA4_SECRET` is unset, then verifies with it - accepting tokens signed with a publicly known key. Feature 37's code, consuming this verifier. | Remove the hardcoded fallback; a blank secret rejects (fail closed). Register with Feature 37. |
| EN-01 | Python reads `TINA4_TOKEN_EXPIRES_IN`/`TINA4_TOKEN_LIMIT` for the default TTL; PHP/Ruby/Node use a hardcoded 60-minute default and read no TTL env var. | Decide one TTL env var and add it to all four (or drop it from Python) so the config surface matches. |
| DOC-01 | Python `validate_api_key` docstring (`auth/__init__.py:664`) claims a fallback to `API_KEY`; the code reads only `TINA4_API_KEY`. The `API_KEY`->`TINA4_API_KEY` normalisation is CLI-layer only. | Fix the docstring to match the code. |
| FX-01 | No central `auth_contract.json` exists; each framework carries its own `test_auth_session_contract` copy, so the four can drift. | Add `auth_contract.json` as the single data oracle and wire four runners to it. |

## Owner decisions

Proposed for owner ratification. The uniform behaviour above is already settled by ADR-0021 and the
2026-08-01 RS256-opt-in ruling; these are the open calls.

1. THE ROUTE-GATE API-KEY CONTRACT (AK-01). Pick one for all four:
   - (a) JWT-only gate (PHP/Node today). A `@secured` route accepts only a verified JWT, so it always
     carries a real user identity; a static API key authenticates only through an explicit
     `authenticate_request` call an app makes itself. RECOMMENDED - it matches the mainstream (a
     single shared key should not silently open every user-protected route), keeps the key's power
     narrow, and is the tighter default. Python and Ruby converge onto it.
   - (b) JWT-or-API-key gate (Python/Ruby today). The route gate delegates to the full
     `authenticate_request` logic, so `@secured` accepts a verified JWT or the static API key. This
     is one code path (gate == request-auth) and follows the Python master, but it broadens a single
     static credential to every protected route. If chosen, document that an API-key-authenticated
     request has no user identity (`request.user = {"_auth": "api_key"}`).
   The tension is real: (b) is less code and Python-master-aligned; (a) is more secure and closer to
   real frameworks (ADR-0012 authority order puts the standard above internal precedent), which is
   why it is recommended. Settle at build time.

2. THE `expires_in = 0` SEMANTICS (EX-01). Ruby's born-expired token is a defect either way; pick the
   target:
   - (a) 0 = non-expiring (Python/PHP/Node today, and the documented "0 = no expiry"). Least change;
     Ruby alone moves.
   - (b) 0 = use the configured default TTL, mirroring ADR-0027 (a session `write()` ttl of zero
     means "use the configured default", not "never expires"). RECOMMENDED for consistency with the
     already-ratified session decision and because it removes the silent never-expiring-token
     footgun; a long-lived token then needs an explicit large TTL. This changes three frameworks'
     documented behaviour, so it needs the owner's explicit sign-off (a behaviour change, per the
     compare-real-world rule). Negative TTLs reject in both options.

3. THE RS256 ACTIVATION MODEL (RA-01..03). Converge Ruby onto the config-driven, secure model the
   other three and the 2026-08-01 ruling already implement: `TINA4_JWT_ALGORITHM` selects the
   algorithm (default HS256); RS256 is opt-in by that configuration and must WORK, not raise; no
   on-disk key presence ever switches the algorithm; a blank secret fails loud and never silently
   mints RSA-signed tokens. This is a Ruby breaking change and the recommendation is to take it -
   RA-03 is a security issue and the ruling is already ratified; Ruby simply does not conform yet.

4. THE CSRF FALLBACK SECRET (SEC-01). Remove the hardcoded `'tina4-default-secret'` in PHP's CSRF
   middleware; a blank `TINA4_SECRET` must reject, not validate against a known key. Track the fix
   under Feature 37; gate that a blank-secret CSRF path fails closed in all four.

5. THE CENTRAL FIXTURE (FX-01). Adopt `auth_contract.json` as the one data oracle for this feature and
   retire the per-framework copies of `test_auth_session_contract`'s JWT half.

## Proposed conformance fixture

Add `plan/v3/fixtures/auth_contract.json` with stable ids, driving four runners that mint and verify
against the REAL crypto in each language (no doubles - a "library absent" state is produced by a real
interpreter/runtime, as the existing `auth_rs256_optin` tests already do):

- alg-none-rejected: a token with header `alg: "none"` (and `"None"`, `"NONE"`) is rejected.
- alg-substitution-rejected: under an HMAC configuration, a token whose header claims RS256 is
  rejected before any signature work.
- exp-boundary: a token with `exp == now` is rejected (`now >= exp`); `exp == now + 1` is accepted.
- exp-nbf-malformed: a present but non-numeric `exp` or `nbf` (string, bool, null) rejects the token.
- nbf-leeway: a token with `nbf == now + 30` is accepted (60s leeway); `nbf == now + 120` is
  rejected.
- expires-in-zero: the ratified 0-semantics (owner decision 2) - identical in all four.
- authenticate-request: a verified Bearer JWT returns its payload; a verified Bearer API key returns
  `{"_auth": "api_key"}`; a Basic header and a bad token return null.
- route-gate: the ratified route-gate contract (owner decision 1) - a `@secured` route answers 401
  without a valid credential and 200 with one, identically in all four, exercised over a real socket.
- api-key-timing: `validate_api_key` returns false for an unset key and for a wrong key, and true
  for the right key, via the constant-time path.
- password-cross-verify: a hash minted in one language verifies in every other language (the fixture
  carries a known `pbkdf2_sha256$...` string and each runner confirms `check_password` accepts it).

## Integration map

- The dispatch layer (Feature 6) hands the headers to `authenticate_request` and the route gate.
- Feature 37 (CSRF) calls `valid_token` to verify the form token; SEC-01 lives there.
- Feature 65 (sessions) is the sibling: the session cookie is opaque (ADR-0021), distinct from a JWT.
- The dev-admin and MCP admin gates reuse the same constant-time comparisons.
- Central fixture, four runners, the CI matrix, and the auth docs (`docs/*/` auth pages) update
  together; the docs must state the ratified 0-semantics and route-gate contract.

## Breaking changes and migration

- Owner decision 1(a) makes Python and Ruby stop accepting a raw API key at the route gate: a
  deployment relying on a static key to open `@secured` routes must switch those callers to a JWT or
  call `authenticate_request` explicitly. `Breaking:` note + migration line.
- Owner decision 2(b) changes `expires_in = 0` from non-expiring to default-TTL in three frameworks:
  a caller that relied on 0 to mean "never expires" must pass an explicit large TTL. `Breaking:`.
- Owner decision 3 changes Ruby's algorithm selection: a Ruby deployment that relied on on-disk keys
  auto-selecting RS256, or on a blank secret minting RSA tokens, must set `TINA4_JWT_ALGORITHM=RS256`
  and provide the secret/keys explicitly. `Breaking:` for Ruby, and a security fix.
- SEC-01 makes a blank-secret CSRF path reject: a deployment using CSRF middleware without
  `TINA4_SECRET` must set one. `Breaking:` and a security fix.

## Implementation backlog

1. Add `auth_contract.json` (FX-01) and wire four runners against real crypto.
2. Ratify owner decisions 1-3; gate the chosen route-gate contract (AK-01), the `expires_in=0`
   semantics (EX-01), and the config-driven RS256 model (RA-01..03) in all four.
3. Fix Ruby: `TINA4_JWT_ALGORITHM` selects the algorithm, no disk-key auto-activation, blank secret
   fails loud (RA-01..03); apply the ratified 0-semantics (EX-01).
4. Fix PHP CSRF blank-secret fallback (SEC-01) under Feature 37; gate fail-closed.
5. Reconcile the TTL env var across the four (EN-01) and fix the Python docstring (DOC-01).
6. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement JWT auth as: mint `header.payload.signature` with `iat` always and `exp` only when the TTL
(minutes) is > 0, signing with a server-pinned algorithm (`TINA4_JWT_ALGORITHM`, default HS256; RS256
opt-in by that config, never from disk state, never on a blank secret). Verify by requiring the
header `alg` to equal the pinned algorithm (rejecting `none` and any substitution), verifying the
signature, then rejecting `now >= exp` and `now + 60 < nbf` and any present-but-non-numeric time
claim. Expose `authenticate_request` (verified Bearer JWT -> payload, verified Bearer API key ->
`{"_auth": "api_key"}`, else null) and a route gate that follows the ratified route-gate contract.
Compare every credential constant-time. Hash passwords as `pbkdf2_sha256$260000$<hex-salt>$<hex-key>`
(16-byte salt, 32-byte key) and verify constant-time with the stored iteration count. Prove the port
with the fixture: alg-none, alg-substitution, the exp boundary, malformed time claims, nbf leeway,
the ratified 0-semantics, the route gate over a real socket, and a cross-language password verify.

## Audit closure checklist

- [x] Boundary and public surface complete (mint/verify/refresh/request-auth/api-key/password + gate).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (alg pin, timing, fail-closed).
- [x] Wire/storage and provider contracts complete (token format, cross-language hash, algorithm
  provider).
- [x] Existing-language contradictions recorded (AK-01, EX-01, RA-01..03, SEC-01, EN-01, DOC-01,
  FX-01).
- [x] Owner ambiguities recorded (5 proposed; the route-gate contract, the 0-semantics, and the Ruby
  RS256 model are the key calls).
- [x] Proposed shared cases and mutation witnesses complete (real-crypto, no-double fixture).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
