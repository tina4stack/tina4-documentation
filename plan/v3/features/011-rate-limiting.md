# Feature 011: Rate limiting

## Identity and status

- Matrix identity: 11 - declarative HTTP rate limiting
- Audit state: decision-ready; implementation is deliberately deferred
- Release boundary: v3 / 3.14.0; parity-breaking corrections are permitted
- Dependencies: Feature 1 dotenv, Feature 2 logging, Feature 6 dispatch,
  Feature 7 middleware, Feature 8 health/readiness and Feature 10 CORS
- Dependants: authentication, static/framework routes, Swagger, proxies,
  multi-worker deployments and response caching
- Existing decision: ADR-0019
- Required follow-up decision: ADR-0049, superseding the changed clauses of
  ADR-0019 rather than silently rewriting it
- Current shared executable fixture: none
- Required shared fixture: `plan/v3/fixtures/rate_limit_contract.json` version 1
- Re-audit date: 2026-08-10

Feature 11 is **not complete**. The old audit repaired the untrusted forwarded-
address bypass and its focused suites remain green, but normal application
wiring is four different products. Node rate-limits every application by
default, Python enables it only when an env value is present, and PHP and Ruby
do not put it in the default request path at all. Node also exhausts the
framework health endpoint, so a busy application can make its orchestrator
restart a healthy container.

The deeper implementation problem is duplication. Each port has multiple
limiter stores behind similarly named service, function and middleware APIs.
They can be stacked without sharing a bucket, disagree on headers and cleanup,
and let tests prove a limiter that the application never calls. Invalid env
values produce fallback, immediate denial, a runtime exception and `NaN`
respectively. A malformed address supplied through a trusted proxy becomes the
bucket key in all four ports.

This audit changes no framework source. It replaces the combined Feature
11/12/79 document's rate-limit section with one clean-room contract, executable
parity plan and implementation formula for the four current ports and any
future Tina4 language. The combined document remains historical evidence for
Features 12 and 79.

## Decisions proposed for owner review

The audit recommends the following decisions as one coherent contract:

1. Rate limiting is disabled by default. A positive `TINA4_RATE_LIMIT` enables
   it; absent or native integer `0` disables it. This aligns three current ports
   and prevents an invisible default from taking down health probes.
2. The algorithm is an atomic sliding-window log, keyed globally by canonical
   client IP. Rejected attempts do not extend the window.
3. One process has exactly one rate-limit policy and one bucket-store owner.
   Public middleware and service APIs delegate to it; they never create another
   store.
4. Valid CORS preflight and the canonical/compatibility health and readiness
   paths bypass the limiter and receive no rate-limit headers. Every other HTTP
   request counts before route matching and authentication.
5. Trusted-proxy configuration and every forwarded address are validated.
   Invalid startup configuration fails outright. A malformed request forwarding
   chain is ignored as a whole and the socket peer is used.
6. `X-RateLimit-Reset` is an absolute Unix timestamp in seconds. `Retry-After`
   is the ceiling of the remaining duration, with a minimum of one on 429.
7. The 429 body and rate-limit headers are framework-owned wire data. The final
   response stage applies them, including CORS and `Cache-Control: no-store`.
8. `TINA4_RATE_LIMIT_URL` selects storage by URI scheme, following ADR-0024.
   `memory://` is the default for single-process use. A shared deployment must
   use an atomic shared provider such as Redis; Tina4 must not claim a global
   quota while silently multiplying it by worker count.
9. A deterministic shared data fixture is the oracle. Every language supplies
   a thin runner plus real startup/socket tests; copied language expectations
   are not parity evidence.

If approved, ADR-0049 should supersede ADR-0019's skip-and-log rule for malformed
trusted-proxy entries, formalize the default/wiring and wire response, and make
the storage and lifecycle rules normative.

## Why this feature exists

An engineer should be able to declare a request limit in `.env` and receive the
same protection, response and operational behavior in every Tina4 language.
They should not need to convert env values, choose among three limiter classes,
manually preserve CORS on errors, exempt Kubernetes probes or discover that
four workers changed a quota of 100 into 400.

Rate limiting is overload and abuse control, not authentication or a complete
denial-of-service defense. An IP key is deliberately available before auth and
therefore protects login, 404 and failed-auth paths, but NAT can group users and
attackers can distribute traffic. Tina4 must make the common safe policy
immediate while describing those limits honestly.

This follows Tina4's core principles: useful defaults without surprise, native
typed configuration, fail-loud invalid declarations, one predictable framework
path, low application ceremony, production-safe behavior and executable parity
instead of four similar-looking implementations.

## Boundary

Feature 11 owns:

- typed rate-limit and trusted-proxy configuration with startup validation;
- one immutable policy resolved after Feature 1 loads environment data;
- request classification and bypasses;
- canonical client-IP resolution for the limiter key;
- the sliding-window algorithm, exact boundary behavior and atomic consume;
- memory and shared-store contracts, cleanup and bounded state;
- allowed-response rate headers and the exact 429 response;
- placement in the request/final-response lifecycle;
- startup diagnostics, access-log behavior and bounded metrics;
- public limiter API semantics;
- shared executable data and thin runners for every language.

It delegates:

- `.env` syntax, precedence and native conversion to Feature 1;
- log sinks, rotation and Docker stdout to Feature 2;
- canonical request/header representation and route matching to Feature 6;
- guaranteed final unwinding to Feature 7;
- health/readiness path aliases to Feature 8;
- valid CORS-preflight classification and final CORS headers to Feature 10;
- response JSON serialization and HEAD body suppression to Feature 12;
- provider connection primitives to their owning storage features.

Per-route, authenticated-user, API-key and named-policy limits are outside the
3.14.0 scope. A future feature may compose them through the same decision and
store interfaces; it must not add a second global bucket implementation.

## Standards authority

RFC 6585 section 4 defines 429 Too Many Requests. The representation SHOULD
explain the condition, MAY include `Retry-After`, and a 429 response MUST NOT be
stored by a cache. Tina4 therefore emits a small JSON explanation,
`Retry-After` and explicit `Cache-Control: no-store`. See
[RFC 6585 section 4](https://www.rfc-editor.org/rfc/rfc6585.html#section-4).

`X-RateLimit-Limit`, `X-RateLimit-Remaining` and `X-RateLimit-Reset` are widely
used compatibility headers, not an IETF standard. The HTTPAPI working group's
current RateLimit fields are still an Internet-Draft and have changed shape
over time. Tina4 3.14 keeps its existing X-prefixed surface rather than claiming
conformance to an unfinished standard. A later feature may add standardized
fields without changing the bucket decision. See the
[HTTPAPI RateLimit Fields draft](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/).

RFC 9110 governs `Retry-After` and field serialization. This contract uses the
delay-seconds form so clients do not need clock synchronization.

## Audited implementation evidence

Audited local staging heads were Python `29feeab`, PHP `c75c7b0e`, Ruby
`ea3aa88` and Node `813b50b`. Each is one approved Feature 1 fixture-runner
commit ahead of the public lab head and contains no Feature 11 implementation
change. The serialized Linux lab cloned public `v3` heads Python `12cc44b`, PHP
`46f9642`, Ruby `25ac783` and Node `96a5050` and ran as root through
`/root/tina4-lab/with-lab-lock.sh`.

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Main implementation | `core/rate_limiter.py` | `Middleware/RateLimiter.php` | `lib/tina4/rate_limiter.rb` | `core/src/rateLimiter.ts` |
| Additional independent bucket | middleware plus `_shared()` service | static hook plus middleware class | middleware class | class plus middleware class |
| Default application wiring | only when env key exists | none | none | unconditional |
| Default limit/window in implementation | 100 / 60 | 100 / 60 | 100 / 60 | 100 / 60 |
| Clock | monotonic | wall | wall | wall |
| Successful reset | duration | epoch | moving epoch | epoch |
| Automatic cleanup | main path only | no | main path only | function path only |
| Invalid `banana` / `oops` | silently 100 / 60 | 0 / 0, denies | 0 / 0, crashes | `NaN` / `NaN`, allows |
| Malformed trusted XFF candidate | used as key | used as key | used as key | used as key |
| Shared fixture/runner | none | none | none | none |

Existing focused lab suites all passed:

| Python | PHP | Ruby | Node |
| --- | --- | --- | --- |
| 39 passed, 17 deselected | 30 tests / 63 assertions | 30 examples | 23 limiter/proxy assertions |

Those totals prove isolated current behavior, not the application contract. The
same lab then supplied `TINA4_RATE_LIMIT=banana` and
`TINA4_RATE_WINDOW=oops`; the four outcomes are shown above, including Ruby's
`NoMethodError` and Node's JSON `null` values produced from `NaN`. With the
socket peer trusted and `X-Forwarded-For: 198.51.100.2,not-an-ip`, all four
resolved the literal `not-an-ip` as the client key.

A real PHP `App` reported no global rate-limit middleware. Ruby's real dispatch
request-stage list contained no limiter. Finally, a real Node server with limit
2 returned `200, 200, 429, 429` for four requests to `/__health`. This is not a
unit-test inference: the requests crossed a TCP socket on the lab.

The organization issue sweep covered all issues, not only open issues, in
`tina4-python`, `tina4-php`, `tina4-ruby`, `tina4-nodejs`, `tina4-js`, `tina4`,
`tina4-documentation` and `tina4-book`. No issue currently tracks these
Feature 11 re-audit defects.

## Defect register

| ID | Severity | Ports | Finding |
| --- | --- | --- | --- |
| H11-01 | release blocker | all | Default application behavior is four-way: Node always limits, Python conditionally wires by env presence, and PHP/Ruby never wire the limiter. |
| H11-02 | release blocker | Node/Python | Health is behind the limiter when enabled. Node's real lab endpoint reached 429 after two requests, allowing ordinary traffic/probes to trigger container restarts. Python has the same ordering when enabled. |
| H11-03 | release blocker | all | Invalid limit/window configuration does not fail startup and yields four incompatible outcomes: fallback, denial, exception and `NaN`. |
| H11-04 | security | all | A malformed XFF/X-Real-IP value from a trusted peer becomes the bucket key. An attacker behind a permissive proxy can regain self-selected buckets or starve a chosen invalid-string bucket. |
| H11-05 | architecture blocker | all | Each port owns multiple independent stores behind public limiter APIs. Stacking or calling them creates separate quotas, semantics and cleanup lifecycles. |
| H11-06 | parity defect | all | Reset semantics disagree. Python returns a duration, three return epoch; Ruby moves successful reset forward on every request instead of using the oldest accepted request. |
| H11-07 | correctness | all | Wall-clock algorithms, floor rounding and inconsistent exact-cutoff handling make retry/reset behavior sensitive to clock jumps and language timing. |
| H11-08 | protocol/parity | all | 429 JSON shapes differ, successful headers are not byte-identical, and no common path explicitly guarantees the RFC-required non-store behavior. |
| H11-09 | lifecycle | all | Early limiter returns can bypass ordinary finalization, logging, CORS and HEAD rules; some ports manually duplicate CORS to compensate. Header ownership also differs. |
| H11-10 | resource leak | PHP/Ruby/Node | One or more duplicate stores have no automatic expiration sweep. High-cardinality client keys and empty arrays can remain for process lifetime. |
| H11-11 | production blocker | all | Storage is process-local, so N workers multiply the advertised quota by N. There is no atomic shared-provider contract or startup guard against the false global claim. |
| H11-12 | test architecture | all | Copied focused suites instantiate or opt into a convenient limiter and hide boot wiring, health exhaustion, invalid config and duplicate stores. No shared data oracle exists. |
| H11-13 | documentation | central/all | The master material advertises a default of 60 while implementations use 100/60, and the old audit calls per-process multiplication documented rather than resolving it for a stable release. |
| H11-14 | configuration | all | ADR-0019 says malformed trusted-proxy entries are skipped and logged, contradicting Feature 1's approved fail-outright rule for a declaration the engineer expects to work. |
| H11-15 | observability | all | No shared bounded logging/metrics policy exists; duplicate paths can log/count differently, and client IP must never become an unbounded metric label. |

## Canonical configuration

Resolve one immutable `RateLimitPolicy` after Feature 1 has loaded OS env,
`.env.local` and `.env`, and before a listener accepts traffic. Never parse or
reread the policy per request.

| Variable | Native value | Default | Rule |
| --- | --- | --- | --- |
| `TINA4_RATE_LIMIT` | integer | `0` | `0` disables; positive safe integer enables; negative, fractional, boolean or string-after-Feature-1 conversion failure is invalid. |
| `TINA4_RATE_WINDOW` | number seconds | `60` | Finite value greater than zero; fractional seconds are valid for precise windows. It is validated even when a non-empty value accompanies disabled limiting. |
| `TINA4_RATE_LIMIT_URL` | string URL | `memory://` | Scheme selects the provider. Credentials may come from Feature 1's standard URL/username/password handling. Unknown/unavailable providers fail startup. |
| `TINA4_TRUSTED_PROXIES` | list of strings | `[]` | Exact IPv4/IPv6 addresses or CIDRs. Native list or Feature 1 comma-string OS form; invalid/empty/mixed entries fail startup. |

Example single-process development policy:

```ini
TINA4_RATE_LIMIT=100
TINA4_RATE_WINDOW=60
TINA4_RATE_LIMIT_URL=memory://
TINA4_TRUSTED_PROXIES=[]
```

Example shared deployment policy:

```ini
TINA4_RATE_LIMIT=100
TINA4_RATE_WINDOW=60
TINA4_RATE_LIMIT_URL=redis://redis:6379/0?prefix=my-app
TINA4_TRUSTED_PROXIES=["10.42.0.0/16", "fd00:42::/64"]
```

OS env still arrives as strings; Feature 1 converts declared variables to their
native types before this boundary. Native integers/floats/lists are used
directly. Invalid values identify the exact variable and correction and stop
startup. Secrets in provider URLs are redacted.

`memory://` is valid only when effective worker/process count is one. If Tina4
starts multiple workers while limiting is enabled with memory storage, startup
fails with a message requiring a shared URL or one worker. This is preferable
to silently promising a quota that is multiplied by topology.

## Client identity

The limiter key is `ip:<canonical-address>`. It is deliberately not route,
user-agent, path, token or authenticated-user specific in Feature 11.

1. Parse and canonicalize the raw socket peer. If it is unavailable or invalid,
   use one stable transport-local sentinel, not request header text.
2. If the peer is not in the immutable trusted-proxy set, ignore every
   forwarding header and use the peer.
3. If the peer is trusted and XFF is present, parse every comma-list member as
   exactly one IP address. Empty, duplicate-field ambiguity, ports, hostnames,
   zone IDs or any malformed member invalidate the whole XFF value; use peer.
4. For a fully valid XFF chain, scan right-to-left and return the first address
   not covered by the trusted set. If all hops are trusted, use the leftmost
   valid address.
5. If XFF is absent, a single valid X-Real-IP may be used. Invalid or duplicate
   X-Real-IP falls back to peer.
6. Canonicalize IPv4-mapped IPv6 and equivalent IPv6 spellings before matching
   and keying so one client cannot acquire aliases for the same address.

Malformed request forwarding data does not fail the request: the transport
identity remains safe. It produces a bounded/sampled diagnostic without copying
the attacker-controlled chain into an unbounded ledger.

## Request classification and placement

```text
if limiter disabled:
    continue without rate headers
elif canonical health or readiness path:
    continue without consuming or adding rate headers
elif Feature 10 says valid CORS preflight:
    continue without consuming or adding rate headers
else:
    atomically consume one request for canonical client key
    attach immutable decision to dispatch context
    continue when allowed, otherwise select canonical 429
    always run the final response unwind
```

The Feature 8 canonical paths and their approved compatibility aliases bypass
before route matching. Applications cannot obtain the bypass merely by defining
a look-alike route. Bare/malformed OPTIONS is an ordinary request and counts.
Swagger, dev routes, static files, 404, 405, failed auth, redirects, HEAD and
application routes all count. WebSocket upgrade HTTP handshakes count once;
messages after upgrade do not.

Counting before route/auth prevents attackers from moving expensive work onto
error paths and makes the global IP policy useful for brute-force pressure. The
decision is stored on Feature 6's dispatch context. Feature 7's final unwind,
not an early middleware return, owns the wire headers and CORS composition.

## Sliding-window and store contract

The logical operation is one atomic `consume`:

```text
consume(key, limit, window, monotonic_now, epoch_now):
    cutoff = monotonic_now - window
    remove timestamps <= cutoff

    if count < limit:
        append monotonic_now
        allowed = true
    else:
        allowed = false

    oldest = first retained timestamp
    remaining_duration = max(0, oldest + window - monotonic_now)
    reset_epoch = ceil(epoch_now + remaining_duration)

    return allowed, limit, max(0, limit - count_after),
           reset_epoch, ceil(remaining_duration)
```

A timestamp exactly at `now - window` is expired. A rejected attempt is not
appended and therefore cannot keep a client blocked indefinitely. Remaining is
the capacity after the current attempt. On an allowed first request, reset is
the expiration of that oldest accepted request, not `now + window` recalculated
on later requests.

The process-local algorithm uses a monotonic clock for expiry and samples epoch
time only to serialize reset. A wall-clock correction cannot create capacity or
extend denial. The store operation is atomic across threads/tasks in memory and
across workers in a shared provider. A Redis provider may use a script or
transaction, but its result must match the fixture rather than expose Redis
details.

The provider interface is minimal:

- `consume(key, policy, clock) -> RateLimitDecision` mutates atomically;
- `peek(key, policy, clock) -> RateLimitDecision` never consumes;
- `reset(key)` deletes one bucket and returns whether it existed;
- `close()` releases timers/connections idempotently through Feature 9;
- expired keys disappear without request traffic and empty buckets are deleted.

Do not keep an overloaded public `check()` whose mutating behavior differs by
port. Compatibility shims may call `consume`, but one coordinator owns the
store. A custom provider is registered against this interface, not implemented
by copying a sibling language's Redis code.

## Canonical response

When allowed, the final response contains:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 99
X-RateLimit-Reset: 1786363000
```

When denied, the exact framework response is:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json; charset=utf-8
Cache-Control: no-store
Retry-After: 17
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1786363000

{"error":"Too Many Requests","status":429,"retry_after":17}
```

All numeric fields are base-10 integers with no whitespace or decimals.
`Retry-After` is delay seconds, `ceil(remaining_duration)`, minimum 1 on 429.
`X-RateLimit-Reset` is absolute Unix seconds and equals the epoch at which the
oldest accepted entry expires. The JSON value equals the header value.

Rate-limit fields are reserved framework headers while the policy is enabled;
application code cannot overwrite or remove them. Existing unrelated response
headers survive. Feature 10 adds final CORS headers to an allowed Origin even
on 429. Feature 12 suppresses the body for HEAD while preserving status and
headers. Health/readiness, valid preflight and disabled policy emit no rate
fields.

## Logging, metrics and resource bounds

At startup, log one structured, redacted policy event containing enabled state,
limit, window, provider scheme, trusted-proxy entry count and effective worker
count. Do not log provider credentials.

Every denial appears in the ordinary access log as status 429. Do not add an
unsampled warning per denial: Docker stdout and file logs must remain bounded by
Feature 2's sink/rotation policy. Malformed forwarding diagnostics are sampled
with a fixed-size counter/window, never a set keyed by attacker data.

Metrics may expose total allowed/denied/invalid-forwarding counts and store
latency/error totals. Client IP, path and raw header values are forbidden metric
labels because they create unbounded cardinality. Bucket storage expires idle
keys and provider outages follow an explicit fail-open/fail-closed policy in the
provider contract; no language invents its own fallback to local memory.

Recommended provider outage behavior for the global availability limiter is
fail open with one rate-limited error diagnostic and a health/readiness
degradation signal. Silently switching to memory is forbidden because it
changes quota semantics. This outage choice should be ratified in ADR-0049.

## Shared executable contract

Create `plan/v3/fixtures/rate_limit_contract.json` with:

- `schema_version`, feature number and clock units;
- configuration valid/invalid cases and native expected values;
- trusted-proxy exact/CIDR/IPv4/IPv6/mapped-address cases;
- malformed/duplicate forwarding-header fallbacks;
- request classification including both health/readiness forms, valid
  preflight, bare OPTIONS, HEAD, 404 and failed auth;
- ordered consume events with monotonic and epoch times;
- exact-cutoff, fractional-window, rejection and clock-jump vectors;
- exact allowed/denied decision fields;
- exact 429 status, headers and compact JSON bytes;
- memory cleanup/reset vectors;
- multi-worker/shared-store atomic contention vectors;
- invalid/unavailable provider startup cases;
- a redaction and bounded-observability manifest.

Every language runner reads the same file and emits the same normalized report:

```json
{
  "feature": 11,
  "schema_version": 1,
  "language": "another-language",
  "passed": 0,
  "failed": 0,
  "cases": []
}
```

Algorithm tests use an injected clock so boundary vectors are deterministic;
this is not a mocked transport. Separate integration tests must boot the normal
application with real env loading and TCP sockets. They prove default disabled,
enabled exhaustion, health/readiness and preflight bypass, 429 CORS/finalization,
multi-client identity, worker behavior, provider outage and clean shutdown.

The parity gate compares reports and exact wire bytes. A language cannot pass by
hard-coding expected fixture output: at least one generated/adversarial sequence
is replayed through its real coordinator and store.

## Implementation formula for another language

1. Implement Feature 1 typed declarations and fail-loud validation for the four
   variables. Resolve one immutable policy after env load.
2. Reuse the language's canonical request object. Implement validated peer/XFF/
   X-Real-IP resolution and canonical IP serialization before rate limiting.
3. Define `RateLimitDecision`, `RateLimitStore` and a single process coordinator.
   Make every public helper/middleware delegate to that coordinator.
4. Implement the memory store with monotonic expiry, atomic consume, cleanup,
   reset and idempotent close. Then implement shared providers against the same
   interface when the URL scheme requires them.
5. Insert one classification/consume stage before route/auth, after only strict
   health/readiness and valid-preflight bypass recognition. Store the decision in
   dispatch context.
6. Apply framework-owned allowed headers or the canonical 429 during the final
   unwind so logging, CORS, HEAD, sessions and request IDs behave normally.
7. Add bounded startup/access diagnostics and metrics. Register store cleanup
   with graceful shutdown.
8. Run the shared fixture, then normal-boot real-socket tests, concurrent atomic
   tests and the serialized Linux/Docker lab. Do not declare parity from copied
   unit tests.
9. Document only the shared contract and language-native spelling. Do not expose
   adapter/store internals as application ceremony.

## Implementation work by current port

| Port | Required change |
| --- | --- |
| Python | Move policy creation after env load; remove env-presence gating in favor of native `0`; make the server, middleware and `_shared()` API use one coordinator; keep monotonic internals but emit epoch reset; bypass probes/preflight and finalize normally. |
| PHP | Register the coordinator in normal `App` boot when enabled; replace the instance/static/middleware stores with delegates; validate instead of integer-casting garbage; add automatic cleanup, common response and atomic provider seam. |
| Ruby | Add the stage to normal dispatch; replace service/middleware stores with one coordinator; validate before `.to_i`; use monotonic expiry; correct successful reset; remove the zero-limit crash and add cleanup/provider lifecycle. |
| Node | Stop unconditional default registration; make function/class/middleware delegate to one coordinator; validate instead of propagating `NaN`; bypass Feature 8 probes/preflight; unify response/cleanup and support the shared provider contract. |

All four must delete or deprecate duplicate state rather than merely adjusting
its tests. One source of policy, identity, time and bucket truth is the release
criterion.

## Acceptance bar

Feature 11 may move from decision-ready to final only when:

- ADR-0049 is accepted and indexed, with an ADR-0019 supersession pointer;
- the owner has settled the default, shared-store and provider-outage decisions;
- `rate_limit_contract.json` and all four thin runners pass;
- normal application boot has exactly one coordinator in every port;
- invalid config fails before listening with byte-comparable normalized errors;
- disabled and enabled defaults match across all ports;
- strict health/readiness and valid preflight never consume or receive headers;
- real 429 bytes, CORS, HEAD, logging and cache-control match;
- malformed forwarding input cannot choose a bucket;
- exact-boundary and clock-jump vectors pass deterministically;
- concurrent local/shared consumes never allow more than the configured count;
- multi-worker memory configuration fails rather than multiplying quota;
- provider outage behavior is identical and never silently changes backend;
- idle buckets/timers/connections are bounded and close through Feature 9;
- real Linux/Docker socket tests pass as root on the serialized lab;
- central docs and examples describe the ratified contract, not old defaults;
- an implementation using only this document, ADR-0049 and the fixture can add
  another Tina4 language without reading a sibling port.

## Audit conclusion

Feature 11 has a sound common core - sliding-window logs, trusted-peer gating
and familiar compatibility headers - but it is not one framework feature yet.
The green suites conceal missing application wiring, always-on Node behavior,
probe exhaustion, invalid typed configuration, attacker-selected malformed keys,
duplicate bucket owners and topology-dependent quotas.

The repair is not to choose the best existing class. It is to establish one
language-neutral policy, one validated client identity, one atomic store
operation, one dispatch decision, one final wire response and one shared
executable oracle. That formula is both the path to 3.14.0 parity and the recipe
for implementing rate limiting in another Tina4 language.
