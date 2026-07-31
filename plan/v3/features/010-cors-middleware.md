# Feature 10: The declarative CORS middleware

Audited 2026-07-31. Part of `98-feature-audit.md`.

Scope: origin matching, credentials handling, the preflight response, the
`Access-Control-Allow-*` headers, `Vary`, `Max-Age`, exposed headers, and the
configuration surface. ADR-0012 (CORS runs as pre-match global middleware) and
ADR-0013 (a preflight also carries `Allow`) were settled before this audit and
are out of scope.

## Files

| | policy | wiring |
| --- | --- | --- |
| python | `tina4-python/tina4_python/core/middleware.py` (`CorsMiddleware`) | `tina4-python/tina4_python/core/server.py` (`_stage_apply_cors`, `_stage_cors_preflight`) |
| php | `tina4-php/Tina4/Middleware/CorsMiddleware.php` | opt-in via `Middleware::use` |
| ruby | `tina4-ruby/lib/tina4/cors.rb` | `tina4-ruby/lib/tina4/dispatch_pipeline.rb` (`cors_preflight`, `apply_cors`) |
| node | `tina4-nodejs/packages/core/src/middleware.ts` | `tina4-nodejs/packages/core/src/server.ts` (`middleware.use(cors())`) |

## How it was measured

Every number below came from driving a real request through the real dispatch
path. Ruby went through `Tina4::RackApp#call` with a real Rack env, the same
object Puma calls. PHP went through `Router::dispatch`. Python went through
`tina4_python.core.server.handle` with a real ASGI scope. Node started a real
HTTP server and made real `http.request` calls. Nothing was stubbed.

Reading the source would have found three of the four defects. It would have
missed the one that mattered most.

## What differed

| Behaviour | Python | PHP | Ruby | Node `cors()` | Node `CorsMiddleware` |
| --- | --- | --- | --- | --- | --- |
| Default `TINA4_CORS_ORIGINS` | `*` | `*` | `*` | `*` | `*` |
| How it is wired | always-on | opt-in | preflight only | always-on | opt-in |
| ACAO on a normal response | yes | yes | **never** | yes | yes |
| `TINA4_CORS_CREDENTIALS` honoured | yes | yes | yes | **ignored** | yes |
| `ACAO: *` with `ACAC: true` | guarded | guarded | **emitted** | n/a | guarded |
| `Vary: Origin` on a match | **no** | yes | **no** | yes | yes |
| `Vary: Origin` on a miss | **no** | yes | **no** | **no** | **no** |
| `Max-Age` on a non-preflight | yes | yes | n/a | no | no |
| `Access-Control-Expose-Headers` | **absent** | **absent** | **absent** | **absent** | **absent** |

PHP was the only implementation close to correct. It became the reference shape,
and the other three moved to it.

## Finding 1: Ruby could not do CORS at all

`Tina4::CorsMiddleware.apply_headers` was dead code. Nothing in the dispatch
path called it. Only `preflight_response` was wired.

Measured on a route registered for GET:

```
PREFLIGHT  -> 204, access-control-allow-origin: *
SIMPLE GET -> 200, no CORS headers at all
```

The browser asks permission. Ruby says yes. The browser sends the real request
and gets nothing back. The browser blocks it. Cross-origin access to a Tina4
Ruby app did not work in any configuration, and the preflight's success made the
failure look like a client bug.

The fix wires `apply_cors` into `ALWAYS_STAGES`, beside the HEAD strip. That
placement is deliberate: `ALWAYS_STAGES` runs on every response, including a
short-circuited 401 and the early-returning swagger and static branches. A
browser shown a 401 without CORS headers reports a CORS error, and the real
status never reaches the developer debugging it (ADR-0012).

Ruby's own characterisation suite had already pinned this gap and demanded the
fix arrive deliberately, with its own test pair, rather than as a side effect of
the pipeline refactor. It did. The assertion flipped from `false` to `true` and
names the conformance suite that now guards it.

## Finding 2: Ruby emitted the pair the Fetch Standard forbids

With `TINA4_CORS_CREDENTIALS=true` and `TINA4_CORS_ORIGINS` at its default:

```
status=204
  access-control-allow-credentials: true
  access-control-allow-origin: *
```

Two sites caused it, both live. `preflight_response` wrote the credentials
header straight from config with no wildcard guard. `apply_headers` did the
same. A third copy in `CorsClassMiddleware` repeated the mistake.

The Fetch Standard's CORS check treats `*` as a literal origin string once the
request's credentials mode is `include`. The comparison against the request
origin fails and the browser discards the response. Python, PHP and Node all
guarded this. Ruby did not.

Be precise about the severity. A compliant browser rejects the pair, so this is
not a path by which another origin reads a user's session. The real damage is
quieter: an operator turns credentials on, credentialed CORS silently does not
work, and nothing in the log explains why. That is the same disease as the other
three findings.

## Finding 3: Node ran two implementations and they had drifted

`server.ts` wires `middleware.use(cors())`. That function form never read
`TINA4_CORS_CREDENTIALS`. The opt-in `CorsMiddleware` class did. Measured with
credentials on and a matching allow-list:

```
cors()          ACAO="https://good.example" ACAC=undefined
CorsMiddleware  ACAO="https://good.example" ACAC="true"
```

A documented environment variable, doing nothing, in the default pipeline.

The symptom was the missing header. The cause was the second copy. Both forms
now build one `CorsPolicy` and apply what it returns, and a conformance case
asserts the two produce byte-identical headers. Fixing only the symptom would
have left the next divergence pre-loaded.

## Finding 4: Vary was missing where it mattered

Python and Ruby never emitted `Vary: Origin`. Node emitted it on an allow-list
match but not on a miss, which is the case that matters: without it a shared
cache can store the no-ACAO response for one origin and serve it to another that
should have been allowed.

RFC 9110 s12.5.5 defines Vary as a description of "what parts of a request
message, aside from the method and target URI, might have influenced the origin
server's process for selecting the content of this response". A field name list
tells cache recipients they "MUST NOT use this response to satisfy a later
request unless the later request has the same values for the listed header
fields as the original request".

That definition set the rule and its limit. An allow-list computes the ACAO from
the request Origin, so the response varies and needs the header, on a miss as
much as on a match. A constant `*` is identical for every caller, so it must not
carry one: a Vary there splits a CDN cache per origin and returns nothing.

We nearly over-applied it. Spring's CORS processor adds
`Access-Control-Request-Method` and `-Request-Headers` to Vary, and copying that
was the obvious move. Measuring stopped it. Tina4's
`Access-Control-Allow-Methods` and `-Allow-Headers` are static configured lists.
No code path reads the request's `Access-Control-Request-*` headers when
building them. Listing those fields would tell every cache downstream something
untrue. Spring lists them because Spring's preflight echoes the request. Ours
does not.

`Vary: Origin` only.

## Finding 5: the default allowed every origin

All four shipped `TINA4_CORS_ORIGINS=*`. Django, Rails and ASP.NET all require
an explicit policy before any CORS header appears.

The default is now deny. No `Access-Control-Allow-Origin` at all when nothing is
configured, and the browser's own check does the blocking. `*` stays settable
for anyone who wants it. See ADR-0014 for the decision and the migration.

## What was fixed

- Deny by default in all four, with `*` still available explicitly.
- The wildcard and credentials never ship together, in all four.
- `Vary: Origin` on every allow-list response, match or miss, in all four. Never
  for a constant `*`. Merged into an existing `Vary` rather than clobbering it.
- Ruby's dead `apply_headers` wired into the dispatch path.
- Node's `cors()` and `CorsMiddleware` collapsed onto one `CorsPolicy`.
- Ruby's `CorsClassMiddleware` reduced to an adapter. Its independent copy of
  the rules had already drifted three ways: no wildcard guard, a `Referer`
  fallback, and an allow-list miss that returned the FIRST allowed origin,
  stamping some other site's origin onto a rejected caller's response.
- Ruby's `Referer` fallback deleted. A `Referer` is a full URL, not an origin,
  and the CORS protocol is defined on the `Origin` header alone. A plain
  same-site navigation carries a `Referer` and no `Origin`, and used to collect
  CORS headers for no reason.
- Every rejection now logs an actionable warning naming the origin, the
  environment variable, and the fix. Once per distinct reason per process.

## What was NOT done

- **`Access-Control-Expose-Headers` is still missing in all four.** It is part of
  the CORS protocol and it is a real gap. Nothing in the code or the docs
  mentions it, so nothing is currently lying to a user. Building it is a new
  feature, not a fix, and it was left out of a security pass on purpose.
- **`Max-Age` on non-preflight responses** stays in Python and PHP. The Fetch
  Standard only defines the header for a preflight, so this is noise a browser
  ignores rather than a defect. Node emits it only on a preflight, which is
  tidier. Not worth a behaviour change on its own.
- **PHP's `isPreflight(string $method)`** still returns true for any OPTIONS with
  no Origin check, so its name overstates what it tests. The real short-circuit
  does not use it and existing tests pin the current meaning. Recorded, not
  renamed. This finding is carried over from ADR-0013.

## Conformance suites

Same case names in all four. Each case was proven red against the unfixed code
before the fix landed.

```
tina4-python/tests/test_cors_policy_conformance.py
tina4-php/tests/CorsPolicyConformanceTest.php
tina4-ruby/spec/cors_policy_conformance_spec.rb
tina4-nodejs/test/corsPolicyConformance.test.ts
```

Cases: `deny by default emits no allow origin`, `deny by default still serves
non browser clients`, `explicit wildcard still allows any origin`, `preflight
status is unchanged when denied`, `wildcard never pairs with credentials`,
`allow list match reflects origin and credentials`, `allow list miss emits no
allow origin`, `allow list always varies on origin`, `constant wildcard does not
vary on origin`, `vary origin does not clobber an existing vary`.

Ruby adds `cors headers are emitted on the actual response not only the
preflight` and `wildcard never pairs with credentials on a preflight`, because
both bugs were Ruby's. Node adds `both middleware forms produce identical
headers` and `the function form honours TINA4_CORS_CREDENTIALS`, because the
two-implementation drift was Node's.

## The lesson

Four defects, one shape. A wildcard paired with credentials that no browser
accepts. A preflight that promises what the response never delivers. An
environment variable read by one code path and ignored by the other. A default
that hands out permission nobody asked for.

None of them threw. None of them logged. Every one of them looked like working
software until someone drove a real request at it and read the headers that came
back.

The fix that matters most is not any single guard. It is that all four now say
so, out loud, when they refuse.
