# Feature 29: HTTP request model

## Identity and status

- Matrix identity: 29 - HTTP request model (the Request object handed to a handler)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source (correcting drift in the prior doc - the `input()`
  cell, the Node "raw Buffer" body, and the param-merge surface). Python `core/request.py:73` (`46007c1`); PHP
  `Tina4/Request.php:18` (`ab871934`); Ruby `lib/tina4/request.rb:117` (`f549923`); Node
  `packages/core/src/request.ts:35` + `types.ts:20` (`1319cf3`).
- Dependencies: the server/transport, the trusted-proxy resolver, file upload (44).
- Dependants: every route handler; auth middleware; CSRF (37).
- Existing ADRs: none dedicated.

- Catalog phase: Routing and middleware

## Why this feature exists

The Request is the handler's view of the HTTP request: method, path, query, headers, cookies, body, files,
client IP. The audit questions: is the surface the same, how do query and route params combine (a
param-pollution surface), and is client-IP trust safe. IP trust is at parity (a strength); the param model,
the `user` field, malformed-body handling, and immutability diverge.

## Existing implementation evidence

Measured, all four expose method/path/url/query/headers/cookies/body/files/remote_ip/ip/content_type + a
`param()` accessor + `bearer_token()` + a case-insensitive header map. Key measured facts:

- CLIENT-IP TRUST - PARITY (a strength, do NOT re-flag): all four keep `remote_ip` = the RAW socket peer
  (never X-Forwarded-For) AND a resolved `ip` that honours forwarding headers ONLY when the peer is a
  configured trusted proxy (`TINA4_TRUSTED_PROXIES`; empty = trust nothing = secure default), with the same
  rightmost-non-trusted-hop algorithm (Python `request.py:310`, PHP `Request.php:512`, Ruby `request.rb:313`,
  Node `trustedProxy.ts:227`).
- PARAM MODEL diverges: Python `params` = query + route merged (route wins; `request.py:177`, merged at
  dispatch `server.py:2270`); Ruby `params` = query + BODY + route merged (`request.rb:417`); PHP/Node
  `params` = route ONLY (`Router.php:1778`, `server.ts:1050`), with `query` separate. Route params are named
  `params` in py/php/node but `path_params` in Ruby.
- BODY: a malformed JSON body -> the raw string in Python/PHP/Node but `{}` in Ruby; the no-body sentinel is
  `None`/`null`/`{}`/`undefined` respectively. Parse timing: eager (py/php), lazy (ruby), async (node).
- `user`: PHP/Ruby/Node expose a mutable `request.user` (for auth middleware to stash the payload); PYTHON HAS
  NONE, and `__slots__` (`request.py:73`) blocks a handler from setting it.
- IMMUTABILITY: PHP `readonly` on 13 properties (the reference); Ruby `attr_reader`; Python and Node fully
  mutable.
- `input()` exists ONLY in PHP; Ruby needs Rack for multipart (a dependency); the other three parse multipart
  zero-dep.

## Public surface contract

A handler reads a stable Request surface (method/path/query/headers/cookies/body/files/ip/param()). The
contract SHOULD pin the param model, the route-param name, malformed-body handling, a `user` field, and IP
trust - IP trust is pinned; the rest diverge.

## Inputs and outputs

- Input: the raw HTTP request. Output: the Request object (surface above).

## Lifecycle and operation graph

1. Transport builds the Request (method/path/headers/body). 2. The router attaches route params. 3. The
handler reads via attributes + `param()`. 4. `ip` is resolved via the trusted-proxy chain.

## Configuration and precedence

- `TINA4_TRUSTED_PROXIES` gates X-Forwarded-For trust. No other env. `param()` precedence: route-then-query
  (php/node), merged (py/ruby).

## Failures, side effects and security

- SECURITY: IP trust is safe by default (trust-nothing). The param-pollution surface is the risk: in Python
  and Ruby, `request.params[k]` can return a CLIENT-supplied query (Py+Ruby) or BODY (Ruby) value that shadows
  or is shadowed by a route value - so a handler trusting `params["id"]` as a route param can be fed a query
  string. PHP/Node keep them separate. Python's missing `user` field means auth middleware cannot stash the
  authenticated user on the request. See the register.

## Wire and persistence contract

The Request is in-memory per request. No wire/persistence. The surface (attribute names + semantics) is the
contract - not yet uniform.

## Providers and substitutability

A future runtime must expose the same surface, pin the param model + names, keep IP-trust safe, and provide a
`user` field.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| REQ-PARAM-POLLUTION | The param model diverges and two languages fold CLIENT input into `params`: Python `params` = query+route merged (`request.py:177`); Ruby `params` = query+BODY+route merged (`request.rb:417`); PHP/Node `params` = route ONLY. So `request.params[k]` can return a client query/body value in Py/Ruby (a param-pollution surface: a route `id` can be shadowed by `?id=`), but not in PHP/Node. | Pin ONE model - keep query and route params SEPARATE (the PHP/Node model) so `params` is route-only and `query` is client-only; or document the merge + precedence explicitly. Highest-value (security surface). |
| REQ-PY-NO-USER | Python's Request has NO `user` attribute, and `__slots__` (`request.py:73`) BLOCKS a handler/middleware from setting `request.user` - so Python auth middleware cannot stash the authenticated payload on the request (PHP `Request.php:89`, Ruby `request.rb:119`, Node `types.ts:66` all have `user`). A real parity + ergonomics gap. | Add a mutable `user` field to Python's Request (add it to `__slots__`). |
| REQ-BODY-DIVERGE | A malformed JSON body -> the RAW STRING in Python/PHP/Node but `{}` (empty hash) in Ruby (`request.rb:293`) - a handler that decoded a bad body sees a string in three languages and an empty hash in Ruby. The no-body sentinel also differs (`None`/`null`/`{}`/`undefined`). | Pin the malformed-body result (raise, or a consistent sentinel) and the empty-body sentinel across the four. |
| REQ-ROUTE-PARAM-NAME | Route params are named `params` (py/php/node) but `path_params` (ruby); and the merged view is `params` (py/ruby) vs route-only `params` (php/node). A surface-name divergence a cross-language app trips on. | Agree ONE name for route params and one for the merged/query view across the four. |
| REQ-IMMUTABILITY-DIVERGE | Immutability diverges: PHP `readonly` on 13 properties (the reference); Ruby `attr_reader`; Python and Node FULLY MUTABLE (a handler can reassign `request.method`/`headers`/`body`). A mutated request mid-pipeline is a footgun. | Decide the immutability posture (readonly the core fields) and apply it consistently. |
| REQ-HEADER-DASH-DIVERGE | The `header()` helper's dash rule differs: Python maps `-`->`_` (`request.py:217`), Ruby maps `_`->`-` (`request.rb:286`), PHP/Node case-fold only. All maps are case-insensitive, but `request.header("x_custom")` resolves differently. | Reconcile the dash-normalization rule in `header()` across the four. |
| REQ-RUBY-RACK-DEP | Ruby's multipart parsing requires Rack (`request.rb:385` `Rack::Request#POST`); the other three parse multipart zero-dep. A dependency divergence (against the zero-dep principle). | Note it; decide whether Ruby hand-rolls multipart (zero-dep) like the others. |

## Owner decisions

- REQ-DEC-01 (proposed, THE call): pin the param model (REQ-PARAM-POLLUTION) - keep route params and query
  SEPARATE (PHP/Node) so client input cannot enter `params`; unify the route-param NAME (REQ-ROUTE-PARAM-NAME)
  and the malformed/empty-body result (REQ-BODY-DIVERGE) across the four. Security + parity.
- REQ-DEC-02 (proposed): add Python's `user` field (REQ-PY-NO-USER); decide the immutability posture
  (REQ-IMMUTABILITY-DIVERGE); reconcile the header dash rule (REQ-HEADER-DASH-DIVERGE); resolve Ruby's Rack
  multipart dependency (REQ-RUBY-RACK-DEP).

## Proposed conformance fixture

A shared fixture (real requests): a route `/{id}` hit with `?id=other` - `request.params["id"]` returns the
ROUTE value, and the client value is only in `query` (catches REQ-PARAM-POLLUTION once pinned); a malformed
JSON body yields the agreed result in all four; auth middleware sets `request.user` and a handler reads it
(catches REQ-PY-NO-USER); `request.ip` honours X-Forwarded-For ONLY from a trusted proxy (the IP-trust
strength, gated).

## Integration map

- Consumers: every handler, auth middleware, CSRF (37), file upload (44). Composes: the transport, the
  trusted-proxy resolver.

## Breaking changes and migration

- Making `params` route-only (if chosen) changes `request.params` for apps relying on the merge - a
  `Breaking:` note. Adding Python's `user` and pinning malformed-body handling are additive/correctness fixes.

## Porting capsule

Expose a Request with method/path/url/query/headers(case-insensitive)/cookies/body/files/`param()`/
`bearer_token()`. Keep route params SEPARATE from query (never fold client query/body into `params` - the
Python/Ruby param-pollution surface), under one agreed name. Keep `remote_ip` = the raw socket peer and
resolve `ip` from X-Forwarded-For ONLY when the peer is a configured trusted proxy (trust-nothing default -
the shipped strength). Provide a mutable `user` field for auth middleware. Pin the malformed-body result and
the immutability posture.

## Audit closure checklist

- [x] Boundary and public surface complete (Request surface x four).
- [x] Lifecycle and producer/consumer edges complete (build -> route-params -> handler).
- [x] Configuration (trusted proxies), failure and SECURITY (param-pollution, IP-trust) rules complete.
- [x] Wire (in-memory surface) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (IP-trust parity; param/user/body/immutability diverge).
- [x] Owner ambiguities decided (REQ-DEC-01 param model, REQ-DEC-02 user/immutability/headers).
- [x] Conformance fixture (param-separation + user + IP-trust) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
