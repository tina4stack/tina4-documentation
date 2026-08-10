# Feature 031: Router and dispatch

## Identity and status

- Matrix identity: 31 — Router and dispatch
- Audit state: decision-ready
- Audit note: Implementation is deliberately deferred
- Dependencies: Feature 1 environment, Feature 2 logging, request/response surface
- Dependants: Feature 33 middleware, Feature 38 health, Feature 34 CORS,
  authentication, Swagger, static files, templates, WebSockets, dev reload and MCP
- Existing ADRs: ADR-0010, ADR-0011, ADR-0012, ADR-0013 and ADR-0015
- Shared fixtures: `fixtures/dispatch_contract.json`, version 1, eight
  invariants

- Release boundary: v3 / 3.14.0; parity-breaking corrections are permitted
- Re-audit date: 2026-08-10

Feature 31 is **not stable**. The original fixture checker is green, but it only
proves that named test text exists in four files. Adversarial execution found
multiple public-contract defects outside those names.

## Why this feature exists

An engineer declares an HTTP endpoint once and Tina4 deterministically turns a
request into the intended handler call or a complete protocol response, without
the engineer writing server plumbing, decoding parameters, converting declared
types, implementing HEAD/OPTIONS, or guessing which fallback won.

## Boundary

Feature 31 owns:

- route registration, grouping, discovery and inspection;
- route-pattern parsing and validation;
- request-target path normalization and parameter decoding;
- method selection, first-match precedence and duplicate replacement;
- implicit HEAD, automatic OPTIONS, 404 and 405 selection;
- the order of routing relative to system routes, middleware, auth and fallbacks;
- dispatch-stage visibility as runtime data;
- hand-off of a matched route, native parameters and route metadata.

It delegates:

- request and response object details to the routing-surface feature;
- middleware hook semantics to Feature 33;
- health payloads to Feature 38;
- CORS policy to Feature 34;
- auth token validation to authentication;
- serialization of handler return values to the response surface;
- static-file confinement, template rendering and Swagger generation to their
  own features.

WebSocket route registration reuses the pattern grammar and registry rules, but
upgrade framing and connection lifecycle are not part of HTTP dispatch.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Public surface | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Startup/CLI integration | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Stored/wire format | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing focused tests | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |
| Existing lab baseline | See retained evidence below | See retained evidence below | See retained evidence below | See retained evidence below |

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Router | `tina4_python/core/router.py` | `Tina4/Router.php` | `lib/tina4/router.rb` | `packages/core/src/router.ts` |
| Dispatch | `tina4_python/core/server.py` | `Tina4/Router.php` | `lib/tina4/dispatch_pipeline.rb` | `packages/core/src/dispatchPipeline.ts` |
| Discovery | sorted recursive Python import | `RouteDiscovery.php` | sorted recursive `load` | `routeDiscovery.ts` |
| Route inspection | CLI + MCP + registry | registry + MCP; no route CLI found | CLI + MCP + registry | CLI + MCP + registry |
| Pipeline stages are data | yes | yes | yes | yes |
| Focused local baseline | 91 passed | 88 tests / 213 assertions | 58 examples | 119 cases/assertions |
| Focused lab baseline | 91 passed | 88 tests / 213 assertions | 58 examples | 119 cases/assertions |

The lab run used root under `/root/tina4-lab/with-lab-lock.sh` on
`the lab host`. All selected suites passed. This does not close the
feature: the adversarial probes below fail outside the indexed cases.

### Request-target normalization and decoding

Routing consumes the path component only. Query parameters never participate in
matching and are preserved unchanged by redirects.

The portable algorithm is:

1. retain the raw request-target path when the server API exposes it;
2. require a leading `/` and normalize transport backslashes to rejection, not
   separators;
3. split raw path segments on literal `/`;
4. percent-decode each segment exactly once as UTF-8; `+` remains `+`;
5. reject malformed percent escapes or invalid UTF-8 with 400;
6. reject a decoded `/`, `\` or NUL inside an ordinary single-segment
   parameter; only a final `path` catch-all may contain decoded separators;
7. compare decoded literal segments and validate decoded parameter values;
8. expose decoded native parameter values to the handler.

This rule prevents encoded separators from changing route structure and avoids
Node-only double meaning such as a single `{id}` receiving `a/b` from `a%2Fb`.

#### Trailing slash

`TINA4_TRAILING_SLASH_REDIRECT` is false by default.

- false: `/items` and `/items/` select the same route without redirect;
- true: a non-root trailing-slash request redirects to the canonical
  no-trailing-slash path and preserves the exact query string. GET and HEAD use
  status 301; POST, PUT, PATCH and DELETE use 308 Permanent Redirect, which
  preserves the method and body (RFC 7538). A flat 301 would let a client drop a
  POST body and downgrade to GET;
- `/` never redirects;
- redirect selection happens before handler, route middleware and auth;
- HEAD still carries no response body on the redirect.

### Method selection and protocol outcomes

Matching first tries the exact request method in registration order.

- HEAD: use an explicit HEAD match for that path; otherwise fall back to the
  matching GET route for that path. The existence of an unrelated explicit
  HEAD route cannot disable fallback.
- OPTIONS: use an explicit OPTIONS route when one matches; otherwise return the
  automatic response.
- known path, unsupported method: 405 with `Allow`;
- unknown path, non-OPTIONS method: 404;
- unknown path, automatic OPTIONS: 204 with an empty `Allow` value, preserving
  the accepted ADR-0013 behavior.

`Allow` is emitted in this exact order when applicable:

```text
GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
```

Only present methods are included. GET implies HEAD. Every known path implies
OPTIONS. ANY contributes the canonical seven methods. The same calculation is
used for automatic OPTIONS, CORS preflight and 405; there is one producer.

HEAD invokes the selected HEAD or GET handler normally so headers match GET,
then strips content unconditionally on every response path while retaining the
equivalent Content-Length when known (ADR-0011).

## Public surface contract

Every language must expose idiomatic equivalents of these concepts:

| Concept | Required behavior |
| --- | --- |
| register | add one method + pattern + handler + metadata record |
| verbs | GET, POST, PUT, PATCH, DELETE, HEAD and OPTIONS |
| any | declare the same handler for the canonical supported method set |
| group | compose a prefix and middleware, including nested groups |
| secure/no-auth | explicit route auth override; middleware never changes auth |
| cache | explicit route cache metadata |
| match | return route + native params, or no match |
| allowed methods | stable canonical method list for a path |
| list | return the effective registry in actual resolution order |
| clear | empty HTTP and WebSocket registries for isolation/testing |
| discover/rescan | deterministically load new and changed route files |

Framework ports may add language-idiomatic aliases, but the portable pattern
grammar below must work unchanged in every language. An alias cannot alter the
meaning of the portable grammar.

## Inputs and outputs

### Canonical route record

Internally, every registered route must be inspectable as one record containing:

```text
method                 canonical uppercase method
pattern                canonical declared path
handler                callable reference and inspectable handler identity
source                  file/module and line when available
registration_index     stable effective resolution position
origin                  system | programmatic | discovered | generated
parameter_schema       ordered name/type/catch-all declarations
middleware             ordered route middleware declarations
auth                    default | required | public
cache                   enabled flag and policy metadata
swagger                 complete metadata map
template                optional template binding
```

The same records feed dispatch, `tina4 routes`, MCP route inspection, Swagger,
doctor/status tooling and shadow diagnostics. Those consumers must not rebuild
their own partial route tables by scanning source.

## Lifecycle and operation graph

### Registration, identity and precedence

Route identity is `(uppercase method, canonical pattern)`.

Registration order is resolution order and first match wins (ADR-0015). The
router does not rank specificity. Therefore a catch-all registered before a
specific application route may shadow it; inspection and warnings must make
that outcome visible.

Re-registering the same identity replaces the route **in its existing slot**.
The newest handler and metadata win, but replacement must not move the route or
change its precedence relative to overlapping patterns. This is required for
safe hot reload.

System routes are registered before application routes in a documented system
tier. A user catch-all cannot shadow health, dev-admin, feedback, Swagger or
other enabled framework endpoints. Within each tier the same first-match rule
applies. The effective combined order is visible in the canonical registry.

At registration/startup, warn when an earlier route can shadow a later route
for an overlapping method. The warning includes both identities, sources and
their effective positions. It does not silently reorder them.

#### ANY

Portable `ANY` registers the handler for the five content methods GET, POST,
PUT, PATCH and DELETE. The path still answers HEAD via GET fallback and automatic
OPTIONS; `ANY` does not register explicit HEAD or OPTIONS routes and so does not
suppress the automatic OPTIONS response. For the Allow calculation and auth,
`ANY` contributes the canonical seven methods. It does not opt an application
into TRACE, CONNECT or arbitrary extension methods. Method-derived auth remains
in force: write requests are secure by default; GET, HEAD and OPTIONS are public
by default. An explicit route auth override applies consistently to every method.
To own the OPTIONS response, declare an explicit OPTIONS route.

### Discovery and hot reload

Discovery walks only the configured application route root and processes
normalized relative paths in ascending lexical order. Filesystem enumeration
order is never a contract.

Every discovery pass must distinguish:

- new file: load and register;
- unchanged file: do nothing;
- changed safe file: remove all prior routes owned by that source, reload and
  register the file's current routes;
- deleted file: remove all routes owned by that source;
- failed file: do not leave a partial new registration set; record a visible
  broken-import diagnostic and keep the server alive where the language allows.

Replacing only identical patterns is insufficient: renamed and deleted routes
otherwise survive as ghosts. A rescan is idempotent and does not accumulate
duplicate middleware, routes, modules or WebSocket entries.

The discovery convention and imperative registration API produce the same
canonical route record. File syntax such as `[id]` is a discovery convention,
not a second public matching grammar.

### Dispatch lifecycle

Stage **names** may be idiomatic because streaming and server integration differ.
Stage order and externally visible outcomes are the shared contract. Each
runtime publishes its truthful stage lists as immutable data and gates that the
listed stages exist and are the order actually executed.

The required behavioral order is:

```text
transport request
  -> request-target validation / trailing-slash redirect
  -> enabled system endpoint selection
  -> pre-match global middleware
  -> application route match
  -> matched route metadata attached to request
  -> post-match global middleware
  -> auth gate
  -> route middleware
  -> handler
  -> route/template/static/not-found fallback selection
  -> after hooks for every global that entered
  -> response finalization
  -> unconditional HEAD stripping and policy headers
  -> logging / session / inspector integrations
  -> transport response
```

Accepted ordering rules remain:

- routes beat same-path static files (ADR-0010);
- post-match globals run before auth and route middleware runs after auth
  (ADR-0012);
- matched metadata reaches auth before the gate;
- every global middleware instance that entered gets its after hook, including
  short-circuit paths;
- successful OPTIONS, including CORS preflight, carries the router-derived
  `Allow` header (ADR-0013).

## Configuration and precedence

The audit has not yet fixed argument, environment, project-file, default, and cache timing precedence.

## Failures, side effects and security

| Condition | Required result |
| --- | --- |
| invalid route declaration | synchronous registration exception with pattern and reason |
| malformed request percent encoding / UTF-8 | 400; no handler or route middleware |
| typed value outside grammar | no match for that route; continue resolution |
| known path / wrong method | 405 + canonical `Allow` |
| unknown path | 404 |
| handler/middleware exception | framework error event/response; never converted to 404 |
| discovery import failure | visible log + broken diagnostic; no partial new route set |
| shadowed route | startup warning + visible order; no silent reordering |

Literal matching and encoded-separator rejection are security requirements: a
route must not expand merely because its literal contains regex syntax, and an
encoded slash must not bypass a one-segment authorization boundary.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

The audit has not yet proved provider substitution or recorded deliberate capability exceptions.

## Contradictions and defects

### Contradictions and defects measured on 2026-08-10

| ID | Severity | Measured contradiction | Required correction |
| --- | --- | --- | --- |
| R6-01 | P1 | PHP falls back HEAD to GET only when the entire HEAD table is empty. Registering `HEAD /b` breaks implicit `HEAD /a` for `GET /a`. | decide fallback per requested path |
| R6-02 | P1 | PHP and Node compile literal route text as regex. `/v1.0/{id}` matches `/v1x0/7`. PHP delimiter characters can also invalidate the regex. | parse tokens and escape all literals |
| R6-03 | P1 | `[\d.]+` accepts `..` and `1.2.3`; Python returns strings after failed casts, PHP/Ruby produce zero or prefixes, and Node truncates prefixes. | strict numeric grammar; successful match always native |
| R6-04 | P1 | Node decodes captured params while the other core matchers return percent text; encoded slash and invalid escapes have divergent structural/error behavior. | implement one raw-path, decode-once contract |
| R6-05 | P2 | Node removes and appends a duplicate route. Replacing an early dynamic route after a later literal route changes the winner; the other three preserve the slot. | replace in place |
| R6-06 | P2 | With redirect disabled, Python/PHP/Ruby accept `/x/`; Node does not. With it enabled, Node aliases the route rather than producing the documented 301. | implement the shared trailing-slash rule |
| R6-07 | P2 | Duplicate or empty parameter names register in Python/Node; duplicate names collapse to the last value in Python/Ruby; PHP emits a regex warning and never matches. | validate and fail registration |
| R6-08 | P2 | Relative patterns are normalized in Python/PHP/Ruby but silently do not match in Node. | require leading slash and fail registration |
| R6-09 | P2 | Node discovery uses raw `readdirSync` recursion without an explicit sort. | sort normalized relative paths |
| R6-10 | P2 | Hot reload deletion/rename ownership is incomplete outside Python; identical-pattern replacement cannot remove ghosts. | source-owned atomic replacement set |
| R6-11 | P2 | Route inspection is not one effective registry: PHP has no route CLI; Node CLI scans only discovered files and sorts away resolution order; Python CLI imports only `app.py`; Ruby reports `auth_handler`, not effective `auth_required`. | make every consumer read the canonical live manifest |
| R6-12 | P2 | Portable grammar differs: Node publicly accepts `:id` and `[id]`; Ruby accepts `*name`; Python alone accepts `{}`. | gate the canonical grammar; document aliases separately |
| R6-13 | P2 | ANY is a true wildcard/public route in Python/Ruby but an expanded method set with method auth behavior in PHP/Node. | canonical seven-method expansion and auth rule |
| R6-14 | P3 | `audit-dispatch-contract.py` normalizes source text and searches for case-name substrings; it never runs a runtime or proves the fixture was consumed. | replace index-only checking with executable fixture runners |

No framework source was changed during this audit.

## Owner decisions

No unresolved product-choice question is required to begin implementation. The
rules above follow already accepted ADRs and the established Tina4 principles:
simple declarations, native values, deterministic behavior, explicit failure
and safe defaults.

The re-audit resolves previously implicit points as follows:

- duplicate registration is latest definition in the original slot;
- strict numeric matching preserves the currently intended non-negative shapes;
- aliases may exist, but the brace grammar is the portable contract;
- trailing-slash redirect uses the already documented 301 behavior;
- ANY means the canonical safe application method set, not arbitrary TRACE or
  CONNECT;
- route visibility means the effective live manifest, not a source-code scan.

If any of those is intentionally different product policy, it requires an ADR
before implementation because it changes the future-language formula.

### Owner decisions APPROVED (finalized 2026-08-10)

This packet declared no open product choices. The re-audit review surfaced three
genuine calls hiding inside "resolved from accepted policy"; Andre settled them,
and two clean-room precision fixes are folded in.

- **A: trailing-slash redirect is method-aware.** GET/HEAD redirect with 301;
  POST/PUT/PATCH/DELETE redirect with 308 Permanent Redirect (RFC 7538), which
  preserves the method and body. The doc's flat 301-for-every-method would let a
  client drop a POST body and downgrade to GET (RFC 7231 permits the change). The
  trailing-slash section, the fixture HTTP cases and the migration notes are
  updated to match; the redirect still fires before handler, route middleware and
  auth, and HEAD still carries no body.
- **B: numeric grammar stays strict (ratified as written).** `{:int}` is
  `[0-9]+`; `{:float}` is the non-negative decimal shapes. `-5`, `-1.5`, `1e3`,
  NaN and infinity do not match and fall through. Widening later (a sign or an
  exponent) is non-breaking, so strict is the safe default; a real need is a
  one-line, backward-compatible extension via ADR.
- **C: lab-host references are redacted from the plan.** The concrete lab host is
  written as "the lab host" / "the lab" across `plan/`, matching the convention
  every feature doc already uses (repo-wide sweep, separate from the contract).

Clean-room precision fixes (answering the two poked nits):
- The numeric match column is shown fully anchored with a literal (escaped) dot,
  so a clean-room reader cannot compile `.` as regex-any.
- `ANY` is clarified: it registers the handler for the five content methods; the
  path still answers HEAD via GET fallback and automatic OPTIONS, and contributes
  all seven methods to the Allow/auth calculation. ANY does not register explicit
  HEAD/OPTIONS routes and so does not suppress automatic OPTIONS.

These close the DESIGN half of the FINAL bar for Feature 31. Remaining to reach
FINAL (unchanged): materialize fixture v2 with native/wire expectations and
mutation witnesses, and wire the four executable runners (backlog items 2, 11).

## Proposed conformance fixture

### Existing fixture assessment

`dispatch_contract.json` currently records eight valuable invariants:

1. routes beat files;
2. HEAD carries no body;
3. middleware order;
4. after-pass coverage;
5. OPTIONS carries Allow;
6. 404/405/OPTIONS status shape;
7. route metadata reaches auth;
8. pipeline order is data.

The file is an index, not executable input. `audit-dispatch-contract.py` checks
that each suite file exists and that normalized case-name text occurs somewhere
inside it. Its green `108 (case x framework) pairs checked` result must be
reported as **wiring presence**, not behavioral parity.

Version 2 must contain request/registration inputs and expected native/wire
outputs. Each runtime runner must load the JSON and execute every applicable
case. The central gate must collect runner result JSON and fail if a runtime
did not consume the current fixture hash.

### Proposed conformance fixture v2

#### Registration and grammar

- every verb and nested group registers one inspectable record;
- literal metacharacters match themselves and a near miss does not match;
- unknown type, empty name, duplicate name, relative path, query/fragment,
  interior `//` and non-final catch-all fail registration;
- same identity replacement changes handler/metadata but preserves index;
- replacement of an overlapping earlier route does not change the winner;
- ANY expands to seven methods with method-derived auth defaults.

#### Matching and native values

- untyped, int, integer, float, number, alpha, alnum, slug, UUID and path;
- mutation cases `..`, `.`, `1.2.3`, `-1`, `1e3`, NaN spelling and overflow;
- Unicode literal/parameter and literal `+`;
- percent-encoded UTF-8 decodes once;
- `%252F` does not double-decode;
- `%2F` in a scalar parameter is rejected and is permitted only by the defined
  catch-all policy;
- malformed `%`, `%ZZ` and invalid UTF-8 return 400;
- query text never affects route selection.

#### Precedence and lifecycle

- first registered overlapping route wins;
- system route beats an earlier application catch-all at live startup;
- deterministic lexical discovery produces identical order on shuffled file
  creation order;
- new, changed, renamed, deleted and broken source rescans;
- no ghost routes and no duplicate middleware after repeated rescan;
- shadow warning names both routes and exact order;
- route CLI/MCP/Swagger view the same manifest hash and effective order.

#### HTTP protocol

- explicit HEAD for `/b` does not disable implicit HEAD for `/a`;
- explicit HEAD beats GET fallback only on its own matching path;
- HEAD on route, redirect, 404, 405, static, template and error has no body;
- OPTIONS explicit override and automatic known/unknown responses;
- 405 and both OPTIONS paths share canonical Allow calculation;
- redirect off aliases trailing slash; redirect on returns 301 for GET/HEAD and
  308 for POST/PUT/PATCH/DELETE, preserves raw query, and never redirects root;
- route/static/template precedence and known-path/wrong-method fallback.

#### Middleware/auth hand-off

- pre-global -> match -> metadata -> post-global -> auth -> route middleware ->
  handler;
- short-circuit at each point still runs exactly the after hooks owed;
- middleware attachment never changes auth;
- matched params and metadata visible consistently to auth, middleware and
  handler.

#### Mutation witnesses

The fixture is considered wired only if temporary mutations are proven red:

- swap two overlapping route registrations;
- change strict float grammar back to `[\d.]+`;
- append rather than replace a duplicate;
- disable per-path HEAD fallback;
- remove literal escaping;
- skip one runtime's fixture load or report an old fixture hash.

## Integration map

| Consumer | Required integration |
| --- | --- |
| server startup | register system tier, programmatic routes, discovered routes, then validate shadows |
| middleware/auth | receive the same matched record and native params |
| Swagger | consume canonical records and complete metadata |
| CORS | use the router's one Allow calculation |
| health | reserved system route cannot be shadowed |
| static/templates | run only after no route/method response claims the path |
| WebSockets | reuse pattern validation, decoding and source ownership |
| dev reload | atomic source-owned replace/remove |
| `tina4 routes` | show actual resolution order, origin, source, auth and shadows |
| MCP route list | same records and order as CLI |
| doctor/status | report broken imports and shadow warnings |
| tests | load fixture v2 and report fixture hash/results |
| docs/scaffolders | emit only canonical portable pattern syntax |

## Breaking changes and migration

Pre-3.14 corrections are allowed. Release notes must call out:

- malformed numeric paths that previously reached a handler now do not match;
- relative, empty-name and duplicate-name declarations now fail at startup;
- regex metacharacters in literal paths stop acting as wildcards;
- Node duplicate replacement no longer changes precedence;
- Node trailing slash and encoded parameter behavior changes;
- trailing-slash redirect now uses 301 for GET/HEAD and 308 for unsafe methods,
  so a redirected POST/PUT keeps its method and body instead of being downgraded;
- Python/Ruby ANY auth/method behavior aligns with the canonical seven-method
  rule;
- route inspection output and ordering become authoritative.

Migration messages must include the invalid pattern/source and the canonical
replacement. No compatibility mode is required before 3.14.0.

## Implementation backlog

Audit-first rule: do not execute this backlog until the full feature audit is
approved for implementation.

1. Publish ADRs for the canonical grammar/decoding, route manifest and fixture
   runner protocol.
2. Materialize fixture v2 with exact native/wire expectations and mutation
   witnesses.
3. Implement a segment parser and declaration validator in all four runtimes.
4. Replace numeric regex/cast fallback behavior with strict match-before-cast.
5. Implement raw-path decode-once validation and encoded-separator rules at the
   HTTP adapter boundary.
6. Fix PHP per-path HEAD fallback and Node trailing-slash response behavior.
7. Make duplicate replacement preserve its slot everywhere.
8. Implement deterministic discovery and atomic source ownership for change,
   rename, delete and failure.
9. Normalize ANY expansion and method-derived auth.
10. Build the canonical effective route manifest and point CLI, MCP, Swagger,
    doctor and startup warnings at it.
11. Wire four executable fixture runners and make the central checker execute
    them, verify the fixture hash and aggregate exact failures.
12. Run local suites, serialized lab suites and real HTTP wire probes for every
    encoded/redirect/HEAD case.
13. Update public Tina4 documentation, scaffolders, migration notes and the
    release checklist.

## Porting capsule

A clean-room language port implements Feature 31 in this order:

1. define the canonical route record and stable registry;
2. parse and validate portable patterns without treating literals as regex;
3. register verbs/groups/ANY and replace duplicate identities in place;
4. deterministically discover sources and own registrations by source;
5. normalize and decode raw request paths exactly once;
6. match system tier then application tier, first registration wins;
7. produce native typed params or no match—never a fallback type;
8. compute exact method, HEAD fallback, OPTIONS, Allow, 404 and 405 outcomes;
9. execute the behavioral dispatch order and unconditional final policies;
10. expose the same live manifest to every inspection/generation consumer;
11. load fixture v2, execute every case and report its fixture hash;
12. prove mutation witnesses fail before claiming parity.

The port is incomplete if it only copies method names or stage names. Completion
means the same declaration, request target and registry order produce the same
native parameters, selected handler, protocol status/headers/body rule,
diagnostics and inspection order.

### Portable route-pattern grammar

#### Valid declarations

```text
/                         root
/users                    literal segments
/users/{id}               one string segment
/users/{id:int}           typed segment
/files/{path:path}        named catch-all, final segment only
/files/*                   bare catch-all, final segment only; parameter key "*"
```

Parameter names match `[A-Za-z_][A-Za-z0-9_]*` and are unique within one
pattern. A route pattern must:

- start with `/`;
- contain no query, fragment, NUL or backslash;
- contain no empty interior segment (`//`);
- place a catch-all only in the final position;
- use a known type name;
- contain no duplicate parameter name.

Invalid declarations fail synchronously at registration. They are developer
errors, not routes that quietly never match. In particular, relative paths,
`{}`, duplicate names, unknown types and a non-final catch-all must fail.

Literal text is literal. Regex metacharacters such as `.`, `+`, `(`, `)`, `[`,
`]`, `#`, `?` and `*` have no special meaning unless they form one of the
documented parameter tokens. Implementations may compile to a regex only after
escaping every literal segment.

#### Canonical parameter types

| Declaration | Match grammar | Native handler value |
| --- | --- | --- |
| omitted / `string` | one non-empty segment | string |
| `int` / `integer` | ASCII digits `[0-9]+` | native integer |
| `float` / `number` | `^[0-9]+$`, `^[0-9]+\.[0-9]+$`, or `^\.[0-9]+$` (literal dot) | native floating number |
| `alpha` | ASCII letters | string |
| `alnum` | ASCII letters or digits | string |
| `slug` | lowercase ASCII letters, digits and `-` | string |
| `uuid` | canonical 8-4-4-4-12 hexadecimal shape | string |
| `path` / `.*` | one or more remaining path characters | string |

The numeric grammar is deliberately strict and anchored to a complete segment;
every `.` in these patterns is a literal dot, never regex-any. `..`, `1.2.3`,
`.`, signs, exponents, NaN and infinity do not match the current portable
contract. A successful typed match always gives the declared native type; cast
failure cannot fall back to a string or silently become zero.

## Audit closure checklist

- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.

- [x] Boundary and public surface complete.
- [x] Lifecycle and producer/consumer edges complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire behavior and decoding contract complete.
- [x] Existing-language contradictions recorded with executable probes.
- [x] Owner ambiguities resolved from accepted policy; ADR escape hatch recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

Feature 31 is **audit-complete and decision-ready**, not implementation-complete
and not 3.14-stable. Approval records the contract; a later implementation phase
must make the executable fixture and all four runtimes conform.
