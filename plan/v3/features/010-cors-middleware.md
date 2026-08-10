# Feature 010: Declarative CORS middleware

## Identity and status

- Matrix identity: 10 - declarative Cross-Origin Resource Sharing middleware
- Audit state: decision-ready; implementation is deliberately deferred
- Release boundary: v3 / 3.14.0; parity-breaking corrections are permitted
- Dependencies: Feature 1 dotenv, Feature 2 logging, Feature 6 dispatch and
  Feature 7 middleware
- Dependants: browser APIs, Swagger clients, request IDs, authentication errors,
  static/framework routes and response caching
- Existing decisions: ADR-0013 and ADR-0018
- Required follow-up decision: ADR-0048, superseding the changed clauses of
  ADR-0018 rather than silently rewriting it
- Current shared executable fixture: none
- Required shared fixture: `plan/v3/fixtures/cors_contract.json` version 1
- Re-audit date: 2026-08-10

Feature 10 is **not complete**. The original audit fixed four real defects and
its focused suites remain green, but this re-audit tested the application boot
path and the configuration boundary that those suites bypass. PHP does not
enable CORS in a normal application. Python freezes the policy before `.env` is
loaded. All four accept invalid policy values, omit exposed response headers,
emit protocol headers on requests with no `Origin`, and retain an attacker-
controlled warning ledger that can grow and write without bound. Their default
wire bytes and preflight predicates also disagree.

This audit changes no framework source. It replaces the repair narrative with
the clean-room contract, executable parity plan and implementation formula for
the four current ports and any future Tina4 language.

## Why this feature exists

An engineer should be able to state which browser origins may call a Tina4
application in `.env`, then use the same browser code against every Tina4
language. The framework must translate that declaration into correct browser-
visible headers on successful and unsuccessful responses without requiring an
engineer to understand middleware order, manually answer OPTIONS, convert env
values or install a language-specific package.

CORS is not authentication, authorization or a server-side firewall. A script
can forge `Origin` or omit it. Tina4 continues to serve non-browser clients and
protects data with its auth/CSRF contracts; Feature 10 only controls whether a
conforming browser exposes a response to cross-origin JavaScript.

That boundary is important to Tina4's principles: make the common browser case
declarative and immediate, fail configuration that cannot work, and do not hide
the real 401/403/404/500 behind a generic browser CORS error.

## Boundary

Feature 10 owns:

- typed CORS configuration and startup validation;
- one immutable policy resolved after Feature 1 has loaded environment data;
- exact origin matching, wildcard and opaque `null` origin handling;
- actual-request and preflight response headers;
- the exact CORS-preflight predicate and OPTIONS short-circuit;
- `Vary` merging and cache-safe match/miss behavior;
- credentials, exposed headers, allowed methods/headers and max-age;
- final response placement across application and framework responses;
- bounded, non-attacker-amplified diagnostics;
- a shared fixture and thin runner for every language.

It delegates:

- resource method discovery and `Allow` to Feature 6;
- middleware unwinding and response finalization to Feature 7;
- authentication, CSRF and rate limiting to their own policies;
- response header storage/serialization to the response feature;
- `.env` syntax, precedence and native values to Feature 1;
- log rotation and sinks to Feature 2.

WebSocket origin policy is not HTTP CORS and stays with the WebSocket feature.
Private Network Access is not added implicitly; it requires its own reviewed
policy if Tina4 chooses to support it later.

## Standards authority

The WHATWG Fetch Standard defines a CORS request as one carrying `Origin`, and
a CORS-preflight request as an OPTIONS CORS request that also carries
`Access-Control-Request-Method`. It defines the response header grammars,
credentials checks and `Access-Control-Expose-Headers`; a non-preflight CORS
response may use any status, while a successful preflight uses an OK status.
See the current [Fetch CORS protocol](https://fetch.spec.whatwg.org/#http-cors-protocol),
[CORS check](https://fetch.spec.whatwg.org/#cors-check) and
[CORS-preflight fetch](https://fetch.spec.whatwg.org/#cors-preflight-fetch).

Fetch also makes two frequently missed points executable: a serialized origin
has no trailing slash, and `Access-Control-Allow-Credentials` accepts the
case-sensitive value `true`. Tina4 must emit protocol values, not merely
plausible strings.

RFC 9110 section 12.5.5 governs `Vary`: it names request fields that influenced
response selection. Tina4's allow-list reads `Origin`, including on a miss, so
the response varies by `Origin`. The configured allow-method/header lists are
static and do not echo the request, so `Access-Control-Request-Method` and
`Access-Control-Request-Headers` do not belong in `Vary`. See
[RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#section-12.5.5).

ADR-0013 remains in force: Tina4's preflight also carries `Allow`, derived from
the live router. `Allow` describes the resource; `Access-Control-Allow-Methods`
describes cross-origin policy. They are intentionally not interchangeable.

## Audited implementation evidence

Audited source heads were Python `29feeab`, PHP `c75c7b0e`, Ruby `ea3aa88` and
Node `813b50b`, all on staging `v3`. Each local head adds only the approved
Feature 1 fixture runner over the lab's public `v3` source. Python's unrelated
`uv.lock` change and the documentation repo's unrelated Feature 7/8 edits were
preserved and excluded.

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Policy | `core/middleware.py` | `Middleware/CorsMiddleware.php` | `lib/tina4/cors.rb` | `core/src/middleware.ts` |
| Default application wiring | response/preflight stages | **none** | request/always stages | `middleware.use(cors())` |
| Policy resolved after `.env` | **no** | yes when constructed | yes when first used | yes at server build |
| Real preflight predicate | OPTIONS + Origin + ACRM | OPTIONS + Origin | OPTIONS + Origin **or** ACRM | OPTIONS + Origin |
| Expose-Headers support | no | no | no | no |
| Actual response gets Max-Age | yes | yes | yes | no |
| No-Origin request gets ACAO with `*` | yes | yes | yes | yes |
| Invalid `MAX_AGE=banana` | emits `banana` | emits `0` | emits `banana` | stores/emits `NaN` |
| Default ACAM | no spaces; PATCH before DELETE | no spaces; PATCH before DELETE | spaces; PATCH before DELETE | spaces; **DELETE before PATCH** |
| Denial diagnostic state | unbounded set | unbounded array | unbounded hash | unbounded set |
| Shared fixture/runner | none | none | none | none |

The serialized Linux lab ran as root through
`/root/tina4-lab/with-lab-lock.sh`. The existing focused suites all passed:

| Python | PHP | Ruby | Node |
| --- | --- | --- | --- |
| 40 passed | 44 tests / 76 assertions | 28 examples | 20 parity/OPTIONS/socket assertions |

Those green totals prove only the old repair. The adversarial run then booted a
real PHP `App` with CORS env set and printed `globals [] pre-match []`. The same
run supplied `TINA4_CORS_MAX_AGE=banana` and obtained the four values in the
matrix, and drove the no-Origin path with wildcard configuration; every
language emitted ACAO plus negotiation headers. Node's focused suite used real
`startServer` sockets; Python used real ASGI scopes, PHP real router dispatch
and Ruby the real Rack object Puma calls.

The organization issue sweep covered all issues-not only open issues-in
`tina4-python`, `tina4-php`, `tina4-ruby`, `tina4-nodejs`, `tina4-js`, `tina4`,
`tina4-documentation` and `tina4-book`. PHP issues 105, 106 and 109 record the
old multi-origin, auth-short-circuit and missing-preflight defects and are
closed. No open issue tracks the re-audit defects. The Node search hit issue 36
only because its test launcher uses a file named `preflight.cjs`; it is not a
CORS issue.

## Defect register

| ID | Severity | Ports | Finding |
| --- | --- | --- | --- |
| H10-01 | release blocker | PHP | A normal `App` never registers `CorsMiddleware`; every `TINA4_CORS_*` setting is a no-op unless application code opts in. |
| H10-02 | release blocker | Python | The module-level `_cors` snapshots process env before `start_server()` loads `.env`; the default path and the class hook can therefore apply different policies. |
| H10-03 | contract gap | all | `Access-Control-Expose-Headers` and its config do not exist, so browser code cannot read Tina4's response `X-Request-ID`. |
| H10-04 | release blocker | all | Policy values are not validated at startup. Invalid max-age silently becomes four different wire values; invalid origins, methods and field names likewise survive until request time. |
| H10-05 | contract defect | all | Wildcard origins plus credentials warn and silently drop credentials. The engineer asked for credentials and receives a policy that cannot do it; Feature 1's fail-outright principle requires startup failure. |
| H10-06 | parity defect | all | Wildcard policy stamps ACAO/ACAM/ACAH on requests with no `Origin`. Python/PHP/Ruby also put preflight-only Max-Age on every actual response; Node does not. |
| H10-07 | parity defect | all | Default ACAM bytes differ in whitespace and method order, so identical config is not identical on the wire. |
| H10-08 | protocol defect | PHP/Ruby/Node | Only Python implements the Fetch preflight predicate. Ruby's comment says AND while its code uses OR; PHP/Node omit ACRM. Ordinary OPTIONS can be swallowed as preflight. |
| H10-09 | operational/security | all | Each denied attacker-chosen origin creates a permanent ledger entry and a warning. Distinct origins defeat "warn once", allowing unbounded memory and stdout/file growth-the exact Docker/disk failure Feature 2 forbids. |
| H10-10 | security/parity | PHP/Node | CORS is applied before the route only. A handler/later middleware can overwrite policy headers, while Python/Ruby finalization wins; one declarative policy has different authority by language. |
| H10-11 | protocol/parity | Ruby/all | Ruby strips a trailing slash from a request Origin while the other ports compare raw strings. No port validates/normalizes configured serialized origins. |
| H10-12 | cache edge | all | `Vary` merge tests cover ordinary fields but not an existing `Vary: *`; appending `Origin` to `*` is meaningless and produces divergent/non-canonical output. |
| H10-13 | test architecture | all | Four copied suites rebuild/opt in to the policy and therefore hide H10-01/02. There is no shared data oracle; Node's two-form equivalence assertion uses a response double inside a suite labelled no-mock. |
| H10-14 | documentation | central | `MASTER-SPEC` and architecture examples still advertise unprefixed `CORS_*`, wildcard/credentials-on defaults and "headers on every response", contradicting ADR-0018 and shipped code. |

## Canonical configuration

Resolve one immutable `CorsPolicy` **after** Feature 1 has loaded and validated
OS env, `.env.local` and `.env`, but before any listener accepts traffic.
Middleware must never reread or reinterpret env per request.

| Variable | Native value | Default | Rule |
| --- | --- | --- | --- |
| `TINA4_CORS_ORIGINS` | list of strings | `[]` | Serialized origins, literal `null`, or the singleton `*`. Empty means CORS off/deny by browser. |
| `TINA4_CORS_METHODS` | list of strings | `GET, POST, PUT, PATCH, DELETE, OPTIONS` | Non-empty unique uppercase HTTP method tokens, emitted in this order. |
| `TINA4_CORS_HEADERS` | list of strings | `Content-Type, Authorization, X-Request-ID` | Unique valid HTTP field names, compared case-insensitively. |
| `TINA4_CORS_EXPOSE_HEADERS` | list of strings | `X-Request-ID` | Response field names browser code may read; wildcard is not accepted. |
| `TINA4_CORS_CREDENTIALS` | boolean | `false` | Native Feature 1 boolean only. |
| `TINA4_CORS_MAX_AGE` | integer seconds | `86400` | Finite non-negative safe integer, serialized as base-10 digits on preflight only. |

Feature 1 may return a native list/tuple from `.env`, for example:

```ini
TINA4_CORS_ORIGINS=["https://app.example.com", "https://admin.example.com"]
TINA4_CORS_METHODS=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
TINA4_CORS_HEADERS=["Content-Type", "Authorization", "X-Request-ID"]
TINA4_CORS_EXPOSE_HEADERS=["X-Request-ID"]
TINA4_CORS_CREDENTIALS=false
TINA4_CORS_MAX_AGE=86400
```

At the CORS configuration boundary, a comma-separated OS string remains
accepted because an OS environment cannot carry a native array. A native list
is used directly; an object, number or mixed list is invalid. Trim list values,
drop no empty element silently, deduplicate origins case-sensitively after
normalization and field names case-insensitively while preserving first order.

Configured origins are parsed and serialized at startup:

- HTTP(S) origin = lowercase scheme/host plus non-default port when present;
- no userinfo, path beyond `/`, query, fragment, wildcard host or trailing slash
  in the stored/emitted serialization;
- the exact string `null` opts into opaque origins;
- `*` is valid only as the sole origin;
- `*` with credentials is invalid and fails startup;
- duplicate normalized origins collapse in first-declared order.

Unknown or legacy unprefixed `CORS_*` settings fail through the Feature 1
legacy/unknown-key gate. Invalid config reports the variable, offending value
and correction without exposing secrets. There is no warning-and-fallback path.

## Request classification

Read headers case-insensitively from the framework's canonical request object.

```text
cors_request = exactly one non-empty Origin field is present
preflight    = method == OPTIONS
               AND cors_request
               AND one non-empty Access-Control-Request-Method field is present
```

An OPTIONS carrying only Origin or only ACRM is ordinary/malformed OPTIONS and
does not enter the CORS fast path. A syntactically invalid ACRM or
Access-Control-Request-Headers list receives 400 without policy headers. Bare
OPTIONS continues to Feature 6. Duplicate singleton Origin/ACRM fields fail
closed as 400; a comma-joined Origin is never split or reflected.

The requested method and requested header names do not change Tina4's static
policy output. The browser compares them against ACAM/ACAH. This preserves the
approved 204-on-policy-miss behavior and is why ACRM/ACRH do not enter `Vary`.

## Exact response contract

### No Origin

Run the request normally and emit **no CORS fields and no CORS-added Vary**,
even when policy is `*`. Server-to-server clients remain unaffected.

### Actual CORS request

Run routing, auth and application middleware normally. At final response
unwind, the CORS policy is the exclusive owner of all `Access-Control-*`
fields: remove stale/application values, then apply the resolved policy.

| Outcome | Headers added by Feature 10 |
| --- | --- |
| CORS disabled | none |
| wildcard allowed | `Access-Control-Allow-Origin: *`; optional canonical Expose-Headers |
| allow-list match | reflected normalized Origin, `Vary: Origin`, optional credentials `true`, optional Expose-Headers |
| allow-list miss | `Vary: Origin` only |

ACAM, ACAH and Max-Age are preflight response fields and do not appear on an
actual response. The route's original status/body-including 200, redirect,
304, 401, 403, 404, 405, 429 and 500-does not change. This is what lets browser
code see the real failure instead of an invented CORS failure.

### CORS preflight

A syntactically valid preflight short-circuits before auth, CSRF, rate limiting,
session creation and the route handler. It receives 204 with an empty body.

For an allowed origin, emit:

- `Access-Control-Allow-Origin`;
- `Access-Control-Allow-Credentials: true` only for an explicit allow-list when
  credentials are configured;
- the canonical `Access-Control-Allow-Methods` list;
- the canonical `Access-Control-Allow-Headers` list;
- `Access-Control-Max-Age` as decimal digits;
- `Vary: Origin` for an allow-list, not for constant wildcard;
- `Allow` from the live router, per ADR-0013.

Expose-Headers is for the actual response and is omitted on preflight. A denied
or disabled policy keeps status 204 and `Allow`, omits every Access-Control
field and adds `Vary: Origin` only when an explicit allow-list made Origin part
of selection. An unknown path keeps the existing empty `Allow` behavior.

### Vary merge

Parse existing comma-separated Vary tokens case-insensitively, preserve their
first spelling/order and append `Origin` once when required. Never clobber
`Accept-Encoding`. If existing Vary contains `*`, preserve canonical `*` alone;
adding a field cannot narrow or improve an unlimited variance.

## Diagnostics

Expected request-time policy misses do not log at warning level. `Origin` is
attacker-controlled and distinct values are unbounded. Tina4 may emit a
structured debug event through Feature 2's bounded sampling, but it must not
retain origin strings forever or write one warning per distinct input.

Configuration errors fail once at startup. Startup may log one informational
event containing only policy shape-disabled/wildcard/allow-list count,
credentials flag and max-age-not the full origin list. Metrics, if added later,
use bounded labels such as `allowed|denied|disabled`, never the origin value.

## Public surface

The required public behavior is declarative: an application sets env and CORS
works automatically. Ports may expose an idiomatic `CorsPolicy` constructor for
embedding/tests, but the server uses the same policy object and evaluator. A
class middleware and function middleware may be thin adapters; neither may own
a second copy of matching or header rules.

There is no implicit per-route override in Feature 10. If a future feature adds
one, it must compose through the same policy type, declare cache behavior and
extend the shared fixture first.

## Future-language implementation formula

Implement a new Tina4 language in this order:

1. Add the six canonical keys to Feature 1's env manifest and generated
   `.env.example`; return native types without engineer conversion.
2. Implement a pure `resolve_cors_policy(config)` that normalizes and validates
   once, failing startup on every invalid value/combination.
3. Implement one pure evaluator from `(policy, method, request headers,
   existing Vary, resource methods, response kind)` to a decision/header map.
4. Load env, resolve the immutable policy, then construct the application
   pipeline-never construct policy at module import.
5. Install a pre-match classifier for valid preflight and a final response
   stage for actual CORS requests. The final stage runs for every dispatch
   outcome and owns all Access-Control response fields.
6. Derive `Allow` from the live router; never copy ACAM into it.
7. Serialize headers through the normal response primitive and preserve the
   original actual-response status/body.
8. Add a thin fixture runner that reads the central JSON and emits the standard
   report. It must boot the normal application path and use real sockets or the
   production server's real protocol adapter-no policy replacement or response
   double.
9. Run positive, negative, malformed, error-path and mutation cases locally,
   then run the same runner as root in the serialized Linux lab.
10. Update public docs only after the central checker is green for every
    language.

Mechanisms can be idiomatic; the resolved policy, report and wire bytes cannot.

## Shared fixture and runner

Create `cors_contract.json` with schema/version metadata, canonical defaults
and table-driven cases. Each case contains policy input, request method/headers,
resource methods, starting response status/headers and expected status/body/
headers or expected startup error.

Required case groups:

- disabled policy with Origin and with no Origin;
- wildcard actual/preflight, and no-Origin under wildcard;
- allow-list match, miss, two origins and opaque `null`;
- credentials on explicit origin and wildcard+credentials startup failure;
- Expose-Headers on actual, omitted on preflight, canonical request ID default;
- exact default ACAM/ACAH/Max-Age bytes;
- actual 200/redirect/304/401/403/404/405/429/500 preservation;
- preflight before auth/CSRF/rate/session/handler side effects;
- bare OPTIONS, Origin-only OPTIONS, ACRM-only OPTIONS and valid preflight;
- malformed/duplicate Origin, ACRM and ACRH;
- valid normalization and invalid origin/path/userinfo/query/fragment/wildcard;
- invalid/mixed/empty methods and field names;
- max-age unset, zero, fractional, negative, overflow and non-number;
- Vary absent, existing token, duplicate casing and existing wildcard;
- route attempts to forge ACAO/ACAC and final policy ownership;
- denial diagnostics remain bounded after many distinct origins;
- `.env` loading timing and OS-over-`.env` precedence;
- mutation witnesses for default wiring, preflight predicate, credential guard,
  miss-side Vary, finalizer placement and Expose-Headers.

Every runner returns:

```json
{
  "feature": 10,
  "fixture_version": 1,
  "language": "another-language",
  "framework_version": "3.14.0",
  "passed": 0,
  "failed": 0,
  "cases": [
    {"id": "cors.allowlist.actual.match", "passed": true, "detail": ""}
  ]
}
```

Case IDs, values and expected wire headers live only in the central fixture.
Language runners contain adapter code, not copied expectations. The central
checker rejects missing/extra/duplicate cases, wrong fixture versions, skips,
non-zero failures and byte differences after HTTP's defined case-insensitive
field-name comparison.

## Required implementation work

| Port | Minimum work before parity |
| --- | --- |
| Python | Resolve/rebuild policy after env load; add typed validation, Expose-Headers and exact response split; remove unbounded denial warnings. |
| PHP | Auto-register the one policy in normal `App` boot; add a final response stage so routes cannot override it; implement the exact preflight predicate and remaining common work. |
| Ruby | Change preflight OR to AND; remove trailing-slash mutation; split actual/preflight fields; implement remaining common work. |
| Node | Require ACRM for preflight; move policy ownership to final response unwind; align canonical method order/bytes; implement remaining common work. |
| Central | Publish ADR-0048, create fixture/checker, wire all four runners, update env manifest/examples and repair stale public specs. |

ADR-0048 must preserve ADR-0018's deny-by-default, 204-on-denial and
allow-list `Vary` decisions, while superseding its silent wildcard-credentials
fallback and per-distinct-origin warning clauses. ADR-0013 remains unchanged.

## Completion bar

Feature 10 is complete only when:

- H10-01 through H10-14 are closed in all affected ports;
- ADR-0048 is accepted and ADR-0018 points to it as superseding only the
  changed clauses;
- `cors_contract.json` version 1 and all four thin runners pass centrally;
- every declared mutation witness is proven red;
- the serialized root lab passes real normal-boot and adversarial HTTP cases;
- no runner opts in to or rebuilds policy in a way an application does not;
- public docs and generated `.env.example` state the canonical `TINA4_` names,
  native list examples, secure defaults and Expose-Headers behavior;
- the parity matrix is updated from executable runner reports, not prose.

Until then, the existing green CORS suites are regression evidence for the old
repairs, not proof that Feature 10 is complete.
