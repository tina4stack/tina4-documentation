# Feature 6: Router (pattern matching, params) + the request dispatch pipeline

Audited 2026-07-28. Part of `98-feature-audit.md`. **Planning only.**

## Files

| | route table + matching | dispatch pipeline |
| --- | --- | --- |
| python | `tina4-python/tina4_python/core/router.py` | `tina4-python/tina4_python/core/server.py` (`app`) |
| php | `tina4-php/Tina4/Router.php` | same file (`Router::dispatchInner`) |
| ruby | `tina4-ruby/lib/tina4/router.rb` | `tina4-ruby/lib/tina4/rack_app.rb` (`call`) |
| node | `tina4-nodejs/packages/core/src/router.ts` | `tina4-nodejs/packages/core/src/server.ts` (`dispatch`) |

Two tables below, because the two concerns live in one file in PHP and in two
files everywhere else. Comparing `Router.php` against `router.py` alone would
flatter Python by measuring half the work.

## Measurements

Route table and matching only:

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 614 | 64 | 138 | 2.16 | Router.add (15) | 11.2 | 1 error, 3 warn |
| php | 1002 | 43 | 263 | 6.12 | Router.dispatchInner (72) | 2.6 | 3 error, 4 warn |
| ruby | 413 | 50 | 120 | 2.4 | methods_allowed_for_path (13) | 14.2 | 1 error, 2 warn |
| node | 552 | 72 | 134 | 1.86 | Router.(anonymous) (15) | 11.0 | 1 error, 3 warn |

The dispatch pipeline, measured where it actually lives:

| | LOC | fns | CC total | CC avg | **worst fn** | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 2265 | 89 | 492 | 5.53 | **`app` (37)** | 0.0 | 6 error, 8 warn |
| php | 1002 | 43 | 263 | 6.12 | **`dispatchInner` (72)** | 2.6 | 3 error, 4 warn |
| ruby | 931 | 32 | 187 | 5.84 | **`call` (51)** | 4.5 | 2 error, 5 warn |
| node | 1197 | 67 | 300 | 4.48 | **`dispatch` (61)** | 0.6 | 3 error, 4 warn |

Read the LOC column in that second table with care: Python's `server.py` also
holds background tasks, auto-discovery, the health handler, the landing page, the
gallery and the WebSocket handlers, so its 2265 is not 2265 lines of dispatch.
The comparable number is the worst-function column, and that column is the
finding.

## What differs

**The route table is in good shape in three of four.** Ruby is leanest (413 LOC)
and most maintainable (MI 14.2); Node has the lowest complexity per function
(1.86); Python is close behind on both. All three keep matching, casting and
registration in small functions.

**PHP's router is the outlier, and the reason is structural.** It carries the
dispatch pipeline in the same class, in one function.
`Router::dispatchInner` runs from line 736 to line 1158: **423 lines, 64 branch
keywords, cyclomatic complexity 72**, in a single private static method. Read from
its own comment markers, it holds at least eight distinct responsibilities:

1. trailing-slash 301 redirect (`TINA4_TRAILING_SLASH_REDIRECT`)
2. global middleware, with a separate CORS pass that must run first
3. short-circuit on a middleware-set non-default status
4. RFC 9110 405-vs-404 conformance, plus the OPTIONS 204 variant
5. static file serving, including conditional-request 304 handling
6. template auto-routing (`/hello` to `hello.twig`)
7. exposing matched-route metadata on the request before middleware
8. auth enforcement (write-secure-by-default, dev-admin exemption)

...then route middleware, handler invocation and response finalisation.

**But PHP is not uniquely guilty, and that is the real finding.** Every framework
has a god-function on the dispatch path:

| framework | function | CC | file MI |
| --- | --- | --- | --- |
| python | `app` | 37 | 0.0 |
| ruby | `call` | 51 | 4.5 |
| node | `dispatch` | 61 | 0.6 |
| php | `dispatchInner` | 72 | 2.6 |

Four independent implementations converged on the same shape. That is not four
mistakes; it is one missing abstraction. The request pipeline has roughly eight
ordered stages and nobody ever named them, so each framework grew a single
function that does all eight inline, and each grew it in a different order with
different early-exits. The behavioural drift the audit keeps finding downstream
(405 versus 404, whether CORS headers survive a 401, whether a HEAD on a template
path behaves like GET) lives inside these four functions, and it is undiscoverable
because no stage has a name to compare.

A CC of 72 also means the function cannot be covered. Branch coverage of 64
decision points needs far more paths than any suite has, so the tests that exist
assert end-to-end outcomes and the stage interactions go untested.

## Verdict: SYNTHESISE

Decided on **SOLID (single responsibility), with correctness as the motive.**

No framework wins. Ruby has the best route table (leanest, most maintainable) and
Node the lowest complexity per function, so the **table** pattern comes from Ruby
with Node's parameter-casting shape. The **pipeline** comes from none of them: all
four adopt a named-stage pipeline that does not exist anywhere yet.

This is not a refactor for taste. It is the enabling change for every downstream
parity verdict in this audit, because a stage that has a name can be compared
across four frameworks and a stage that is a line 900 of a 423-line function
cannot.

## Pattern

**One named stage per responsibility, in one fixed order, in all four frameworks.**
Each stage takes `(request, response, context)` and returns either a response
(short-circuit) or nothing (continue). The order is the contract:

```
 1. normalise_path        trailing-slash redirect, decode, collapse
 2. global_middleware     CORS first, then registered global before-hooks
 3. match_route           table lookup -> matched route or null
 4. method_not_allowed    405 + Allow, or the OPTIONS 204 variant (RFC 9110)
 5. static_asset          file + conditional-request 304
 6. template_route        auto-routing to a template file
 7. authorise             write-secure-by-default, ->secure()/->noAuth() overrides
 8. route_middleware      per-route before-hooks
 9. invoke_handler        the user's function
10. finalise              after-hooks, headers, dev-toolbar injection
```

Rules that make it a contract rather than a suggestion:

- **Stages 4, 5 and 6 only run when stage 3 found nothing.** That ordering is why
  a 405 beats a 404 and why a template path can still answer a HEAD.
- **Stage 2 runs before stage 3** so CORS headers are present on a short-circuited
  401 or 403. Browsers report a CORS error otherwise, and this is the one piece of
  PHP's ordering that is provably correct and must be preserved.
- **Stage 7 runs after stage 3** and reads the matched route's metadata, so
  `noAuth` is visible to middleware. PHP's own comment records that this
  assignment was once missing and the `@noauth` bypass was dead code on a real
  dispatch.
- **Each stage is independently callable and independently testable.** The target
  is no stage above CC 10, and the pipeline runner itself a loop.
- **The stage list is data, not control flow.** One ordered list per framework,
  identical order, so a drift is a diff of a list rather than a reading of four
  functions.

Route table pattern (from Ruby, with Node's casting):

- `add(method, path, handler, **options)` replaces a same-`(method, path)` entry
  in place rather than appending, so a hot-reload's fresh handler wins.
- Path compilation returns a matcher plus a parameter-type map; casting is one
  small function per type (`int`, `float`, `path`), not a branch chain.
- `methods_allowed_for_path` is a table scan that returns the method set, and it
  is what stage 4 consumes. It already exists in Ruby, PHP and Python; it is the
  single input the 405 stage needs.

## Methodology

Per framework, in this order. Do not start framework N+1 before N is green.

1. **Freeze the behaviour first.** Before touching a line, write the
   characterisation tests (below) against the CURRENT dispatch function and get
   them GREEN. They are the safety net: the refactor must not change a single
   observable outcome. This step is not optional and not reorderable.
2. **Name the stages, extract nothing.** Add the ordered stage list as data plus
   a runner, with every stage still delegating into the existing function body.
   Verify the suite is still green. The pipeline is now visible with no behaviour
   moved.
3. **Extract one stage at a time, lowest risk first** (`normalise_path`, then
   `static_asset`, then `template_route`, then `method_not_allowed`, then
   `authorise`, then the middleware stages). Run the full suite after each
   extraction. One commit per stage, so a bisect lands on one stage.
4. **Compare the four stage lists.** Any stage present in one framework and
   absent in another, or ordered differently, is a parity finding: file it, decide
   it against the pattern above, do not "fix" it silently inside the refactor.
5. **Re-measure.** `feature-audit.py` must show every dispatch function under CC
   10 and the file MI materially improved. Record the before and after numbers in
   this file.
6. **Then, and only then**, fix any behavioural drift step 4 surfaced, each with
   its own positive/negative test pair.

Order across frameworks: **Ruby first** (leanest pipeline, 187 total CC, so the
smallest blast radius and the fastest signal that the pattern holds), then Node,
then Python, then PHP last (highest complexity, most to lose, most to gain from
three prior passes).

## Tests to write

All four frameworks, identical names, real HTTP through the framework's own test
client (no mocks). Two groups.

**Group A: characterisation, written FIRST and green BEFORE any change.** These
pin today's behaviour so the refactor is provably behaviour-preserving.

| test | asserts |
| --- | --- |
| `dispatch_get_known_route_returns_handler_body` | the happy path is untouched |
| `dispatch_unknown_path_returns_404` | 404 still reached after static + template miss |
| `dispatch_known_path_wrong_method_returns_405_with_allow` | 405 and the `Allow` header, not 404 |
| `dispatch_options_on_known_path_returns_204_with_allow` | RFC 9110 OPTIONS shape, empty body |
| `dispatch_trailing_slash_redirects_301_preserving_query` | redirect keeps the query string |
| `dispatch_static_asset_returns_304_on_matching_validator` | conditional request answered cheaply |
| `dispatch_template_path_renders_for_get_and_head` | HEAD behaves like GET on a template route |
| `dispatch_cors_headers_present_on_401` | CORS survives an auth short-circuit |
| `dispatch_noauth_write_route_is_not_blocked_by_csrf` | the matched-route metadata is visible to middleware |
| `dispatch_middleware_runs_in_registration_order` | ordering contract holds |

**Group B: the pipeline contract, positive and negative pairs.** These are new
behaviour (the named stages) and must FAIL before the change.

| pair | positive | negative |
| --- | --- | --- |
| stage list | `pipeline_declares_the_ten_stages_in_order` - the list is data and matches the canonical order | `pipeline_has_no_unnamed_stage` - no stage function is anonymous or inlined |
| complexity | `every_stage_is_under_complexity_ten` - asserted from `tina4 metrics --json`, so the gate cannot rot | `no_dispatch_function_exceeds_complexity_ten` - the god-function cannot come back |
| isolation | `each_stage_is_callable_on_its_own` - a stage can be invoked with a request and a response alone | `a_stage_does_not_reach_into_a_later_stage` - no stage calls another stage directly |
| short-circuit | `a_stage_returning_a_response_stops_the_pipeline` | `a_stage_returning_nothing_does_not_stop_the_pipeline` |
| parity | `stage_order_is_identical_across_frameworks` - the ordered list is a committed fixture, one shared answer key | `no_framework_adds_a_stage_the_others_lack` |

The complexity pair is the one that keeps this fixed. A refactor with no gate
regrows; a `tina4 metrics --fail-on` assertion in the suite means the next person
to inline a stage gets a red test rather than a slightly worse number nobody
reads. The stage-order fixture follows the pattern that worked for the Frond
expression corpus: same bytes, one answer key, all four frameworks.

## FINDING (2026-07-31): the canonical ten do not describe Ruby

Step 1's characterisation suite is green (`tina4-ruby c7f3921`), and writing it
required reading `RackApp#call` line by line. That read invalidates part of the
pattern above, so it is recorded BEFORE any extraction rather than discovered
half way through one.

Ruby's dispatch has THIRTEEN concerns in this order:

| # | Ruby, as it actually runs | in the canonical ten? |
| --- | --- | --- |
| 1 | request-scoped query-cache reset | no |
| 2 | CORS preflight fast-path | partly - stage 2, but preflight ONLY |
| 3 | WebSocket upgrade | **no** |
| 4 | dev dashboard routes (`/__dev`) | **no** |
| 5 | feedback widget routes (`/__feedback`) | **no** |
| 6 | static file + swagger (skipped for `/api/`) | stage 5, but EARLIER |
| 7 | route matching | stage 3 |
| 8 | HEAD content strip (RFC 9110) | no |
| 9 | dev inspector capture | no |
| 10 | request log line | no |
| 11 | dev overlay injection | no |
| 12 | feedback widget injection | no |
| 13 | session save + cookie | stage 10, finalise |

Three things follow, and none of them are cosmetic:

1. **`static_asset` runs BEFORE `match_route` in Ruby**, not after it. The
   canonical order says stages 4, 5 and 6 run only when stage 3 found nothing.
   Ruby checks the filesystem first and skips that check entirely for `/api/`.
   Reordering it is a BEHAVIOUR change (a route and a file at the same path swap
   precedence), so it cannot ride along inside the extraction.
2. **Five concerns have no canonical name**: websocket upgrade, dev routes,
   feedback routes, the dev inspector/logging/overlay group, and session
   persistence. A ten-stage list forces them into `finalise` or leaves them
   inline - which is the god-function again, wearing a list.
3. **There is no `normalise_path` stage at all.** The trailing-slash behaviour
   the characterisation test pins is not a distinct step here.

The pattern was written from reading four implementations; this is the first one
read closely enough to enumerate. The other three must be enumerated the same way
BEFORE the canonical list is fixed, because a shared stage-order fixture (the
plan's own parity test) is worth nothing if the list was derived from one
framework's guess.

### All four enumerated (2026-07-31)

Node, Python and PHP read the same way. The result is that the canonical ten
describe NONE of them, and the four do not describe each other either.

| concern | ruby | node | python | php |
| --- | --- | --- | --- | --- |
| request-cache reset | 1 | 1 | 6 | - |
| trailing-slash redirect | - | - | 3 | **1** |
| CORS | 2 (preflight only) | - | 1 (preflight only) | **2 (global mw, FIRST)** |
| rate limiting | - | - | 2 | - |
| global middleware (before) | - | 4 | - | 2 |
| WebSocket upgrade | 3 | outside dispatch | outside dispatch | in routes |
| dev routes (`/__dev`) | 4 | 8 | 4 | 9 |
| feedback routes | 5 | - | injection only | 10 |
| swagger | via static | via static | 5 | - |
| session | 13 (save, LAST) | **3 (start, EARLY)** | - | - |
| body parse | - | 5 | in `app` | - |
| **static asset** | **6, BEFORE match** | **9, BEFORE match** | **fallback, AFTER match** | **none - SAPI serves it** |
| match route | 7 | 10 | 7 | 5 |
| matched-route metadata for auth | - | - | 7a | **3** |
| authorise | inside match | in middleware | inside match | **4** |
| route middleware | inside match | 4 | inside match | 6 |
| invoke handler | inside match | 10 | 7 | 7 |
| template fallback | - | 11 | fallback | 1325/1617 |
| RFC 9110 405 / OPTIONS | in else-branch | 12 | 7b | - |
| 404 | in else-branch | 13 | fallback | - |
| HEAD strip | 8 (late) | **2 (early, wraps write/end)** | 8 (late) | - |
| dev toolbar / inspector | 9-11 | 6-7 | - | 9 |
| feedback injection | 12 | - | in `app` | 10 |
| 500 handling | rescue | 14 | - | - |

**Five findings, each of which changes the work:**

1. **`static_asset` has no agreed position.** Ruby and Node check the filesystem
   BEFORE matching a route; Python checks it AFTER, in its fallback; PHP has no
   static stage at all because `php -S` and nginx serve files before `index.php`
   ever runs (a runtime gift, category 1 - correct, not a gap). So the canonical
   "stage 5, only when stage 3 found nothing" matches exactly ONE framework.
   Whichever order wins is a BEHAVIOUR change for two frameworks: a route and a
   file at the same path swap precedence.

2. **Only PHP runs CORS as global middleware before matching.** That is the
   ordering the pattern calls "provably correct", and it is why PHP alone emits
   CORS on a short-circuited 401. Ruby and Python handle preflight only; Node
   does not do CORS in dispatch at all. This is the same gap the Ruby
   characterisation suite pinned - it is three frameworks wide, not one.

3. **`authorise` is a real stage only in PHP.** Everywhere else it is buried
   inside the route-matching block, which is why PHP is also the only framework
   that had to write down "expose the matched route's metadata BEFORE auth".

4. **HEAD is handled at opposite ends.** Node wraps `write`/`end` EARLY so every
   later path drops its body; Ruby and Python strip content LATE. Same outcome,
   opposite mechanism - a stage list has to pick one or admit two.

5. **PHP's `dispatchInner` is 1029 lines (650 of code), not the 423 this plan
   records.** The measurement is stale. It is the single largest function in the
   family and it is the last one scheduled, which remains right.

### Owner call: honour PHP - and what that does and does not mean (2026-07-31)

Owner decision: PHP is honoured on the dispatch ordering. Measuring what that
actually costs turned up a coupling that a naive port would have broken.

**PHP's CORS is NOT automatic.** The CORS-first pass runs inside
`if (!empty($globalMiddleware))`, and `CorsMiddleware` is opt-in via
`Middleware::use(...)`. So PHP's advantage is STRUCTURAL, not behavioural: it has
a global-middleware stage BEFORE matching, with CORS ordered first inside it.
Adopting it does not mean "always emit CORS".

**Where each framework runs global middleware today:**

| | global middleware runs | CORS on a short-circuited 401 |
| --- | --- | --- |
| php | **BEFORE match**, CORS first | yes, when registered |
| ruby | AFTER match | no |
| python | AFTER match | no |
| node | AFTER match | no |

**A naive port BREAKS something specific and nameable.** The other three run
global middleware after matching for a REASON, and Python's own comment states
it: "(e.g. CsrfMiddleware) can read handler metadata such as `_noauth`".
`core/middleware.py:301` reads `request._handler` and `handler._noauth` to skip
CSRF on a route marked `@noauth`. Move that pass before matching and the metadata
is not there yet: a `@noauth` POST gets wrongly blocked with 403.

That is not hypothetical - it is the exact bug PHP itself already fixed once. Its
comment records that `$request->handler` stayed null and "that bypass was DEAD
CODE on a real dispatch". Ruby's characterisation case
`dispatch_noauth_write_route_is_not_blocked_by_csrf` covers the same behaviour
and passes today.

**Why PHP gets away with it:** PHP's CsrfMiddleware is attached as ROUTE
middleware, which runs after matching and after `$request->handler = $route`. The
other three register it GLOBALLY. So PHP's ordering is safe for PHP only because
of a placement difference nobody wrote down.

**The resolution, which honours PHP without inheriting the coupling:** split the
global-middleware stage by DEPENDENCY rather than moving it wholesale.

| pass | runs | contains | why |
| --- | --- | --- | --- |
| `global_middleware_pre` | BEFORE match | CORS, and anything needing no route metadata | must survive a short-circuited 401/403 |
| `global_middleware_post` | AFTER match, after metadata is exposed | CSRF, and anything reading `noAuth`/`secured` | needs the matched route |

That is PHP's CORS-first insight generalised, and it is behaviour-preserving for
the other three: everything that runs after matching today keeps running after
matching. Only CORS moves, and only when it is registered.

**Answer to "does it break anything": not this way. It would have, done
wholesale** - and the test that catches it already exists.

### Revised approach (supersedes the "ten stages" pattern above)

The ten-stage list was derived from reading, before any framework was enumerated.
It cannot be the shared fixture: a parity test whose answer key came from a guess
just freezes the guess.

So the sequence changes:

1. The canonical list is DERIVED from the union above, not invented. It must name
   every concern that exists in more than one framework, and admit the ones that
   are genuinely single-framework (SAPI static, feedback routes) as optional
   members rather than pretending they do not exist.
2. `static_asset`'s position, the CORS ordering, and the HEAD mechanism are three
   OWNER DECISIONS, because each is a behaviour change in at least two
   frameworks. They are not refactor details.
3. Only then does extraction start, and it starts with Ruby, whose behaviour is
   already frozen (`tina4-ruby c7f3921`).

Nothing has been extracted. Freezing Ruby cost one commit and bought the evidence
that the plan's own target was wrong - which is exactly what step 1 is for.

## Risks

- **This is the largest refactor in the audit and it touches every request.** The
  characterisation suite in step 1 is the entire safety argument. If it is thin,
  stop and thicken it before extracting anything.
- **PHP has the most to gain and the most to break.** Doing it last means three
  frameworks' worth of learned pattern before the 423-line function is opened.
- **Do not bundle behavioural fixes into the extraction.** Every drift step 4
  finds gets its own commit and its own test pair, after the refactor is green.

## Parked

Not implemented. Awaiting the owner's go-ahead on the verdict and on the
Ruby-first ordering.

---

## DECIDED: global middleware vs the auth gate

**Status:** DECIDED 2026-07-31 - option 1, aligned in all four.
**Found:** 2026-07-31, while porting the pre/post middleware split.

### The drift

Does a global middleware run before or after the framework's auth gate? Measured
by registering an unflagged (post-match) middleware that stamps a header, then
hitting a secured write route with no token:

| Framework | Result | Position |
| --- | --- | --- |
| Python | `POST /secured -> 401 stamp=ABSENT` | after the gate |
| Ruby | `POST /secured -> 401 stamp=ABSENT` | after the gate |
| Node | `POST /secured -> 401 stamp=present` | before the gate |
| PHP | `POST /secured -> 401 stamp=present` | before the gate |

Two-two, and pre-existing - the split did not cause it. It was found only because
the split's test "a pre-match middleware's output survives a 401" PASSED in Node
and PHP with the flag removed: there, everything survives a 401, so the assertion
could not fail and proved nothing.

### Why it matters

A global middleware that only runs after the gate cannot:

- throttle a brute-force login (a rate limiter never sees the failed attempts),
- log a rejected request (every 401 is missing from the access log),
- add response headers to a 401 (the CORS case the split already fixes for the
  pre-match group).

### What the rest of the industry does

Unanimously: user middleware runs BEFORE auth, and enforcement is late and
route-scoped. Django (`CsrfViewMiddleware` before `AuthenticationMiddleware`,
`login_required` as a view decorator), Laravel (`auth` is route middleware, after
the global and `web` group passes), Rails (`protect_from_forgery` before
`authenticate_user!`), ASP.NET Core (`UseAuthorization` last before the
endpoint), Express (`morgan`/`cors`/`rateLimit` `app.use`d before
`passport.authenticate`). See ADR-0012.

That makes Node and PHP correct and **Python and Ruby the drift** - the reverse
of what "Python is master" gives.

### Options

1. **Align Python and Ruby to Node/PHP** (run global middleware before the gate).
   Matches every mainstream framework and fixes the rate-limit / access-log
   holes. Behaviour change in two frameworks: global middleware starts running
   on requests it previously never saw, so a middleware written assuming an
   authenticated request must now check. Recommended.
2. **Align Node and PHP to Python/Ruby** (gate first). Fewer requests execute
   user code, but it keeps the operational bugs above and puts Tina4 alone
   against the field.
3. **Leave the drift.** Rejected - it is exactly the class of difference this
   audit exists to remove, and it silently breaks the split's own test.

### If option 1 is chosen

- Python: move the post-match global pass ahead of `_check_auth` in
  `handle()`, keeping the route's own middleware after the gate.
- Ruby: the same move in `RackApp#call`.
- Lock it in all four with the pair already used in PHP: a post-match middleware
  DOES run on a matched route, and does NOT run when no route matched (the real
  discriminator between the groups - not the 401, which both groups survive by
  design).
- Breaking-change note in the changelog per the contract-change rule.

### Outcome (2026-07-31)

Option 1 taken. The order is now identical in all four:

```
pre-match globals -> match -> post-match globals -> auth gate -> route middleware -> handler
```

Python and Ruby moved their post-match globals ahead of the gate. Two further
divergences surfaced while doing it and were fixed in the same pass:

- **Node ran the route's OWN middleware BEFORE the gate**, so middleware
  attached to a secured route processed requests that were about to be
  rejected. Moved after the gate, matching the other three and the mainstream
  convention (Laravel orders `->middleware(['auth', ...])` this way, Django
  puts `@login_required` outermost).
- **Python's pre-match pass re-ran the post-match set.** `_run_before_middleware`
  resolves through `_effective_middleware`, which PREPENDS the post-match
  globals - so passing the pre-match list to it ran every post-match middleware
  twice, once before matching and once after. A counter or a rate-limit bucket
  would have double-counted every request. Fixed with an explicit
  `include_globals` switch; locked by `test_a_pre_match_global_does_not_run_twice`,
  proven red against the bug.

Lock-in tests, same case names in all four:

| Case | Proves |
| --- | --- |
| `post match middleware runs on a 401` | the globals are ahead of the gate (the behaviour change itself) |
| `post match middleware does not run when no route matched` | the real pre/post discriminator - NOT the 401, which both groups survive by design |
| `pre match middleware does not open a secured route` | the split did not weaken the gate |

Each was proven to go red against the pre-change code.

**Breaking, Python and Ruby only:** a global middleware now runs on requests it
previously never saw. One written assuming an authenticated request must check
for itself. Nothing changes for Node or PHP, which already behaved this way.

---

## RESOLVED: the preflight Allow gap (2026-07-31)

Recorded earlier as "a real preflight returns 204 without `Allow` in Ruby and
Node". Measuring all four before fixing showed it was wider:

- **Python had the same gap** - three frameworks, not two.
- **PHP had a worse variant**: `CorsMiddleware::beforeCors` short-circuited on
  ANY OPTIONS with no `Origin` check, so registering it dropped `Allow` from
  the BARE OPTIONS too, swallowing the RFC 9110 path. Node had the identical
  bug and had already been fixed the same way.
- **PHP read the `Origin` from `$_SERVER`**, so the header was invisible to
  anything not under a web SAPI (the in-process TestClient, the CLI, a
  hand-built Request). Now reads the Request first, `$_SERVER` as fallback.
- **`Router::methodsAllowedForPath` was private in PHP** and public in the
  other three. Now public.

Fixed in all four; see ADR-0013 for the decision and why it deviates from every
mainstream CORS library. Conformance suites with identical case names:

```
tina4-ruby/spec/options_allow_conformance_spec.rb
tina4-python/tests/test_options_allow_conformance.py
tina4-php/tests/OptionsAllowConformanceTest.php
tina4-nodejs/test/optionsAllowConformance.test.ts
```

Each was proven red against the unfixed code before being accepted. The PHP
proof initially reported a false OK because a shell-escaping error meant the
revert never applied - the second attempt asserts the target text is present
before removing it, so a no-op edit fails loudly instead of passing.

### Still open

`CorsMiddleware::isPreflight(string $method)` (PHP) returns true for any
OPTIONS regardless of `Origin`, so the name overstates the check. The
short-circuit no longer uses it and eight tests pin the current meaning, so it
was left alone. Rename to `isOptionsMethod` when the tests are next touched.
