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

**Proposed, not yet decided:** the canonical list grows to name the concerns that
genuinely exist in every framework (upgrade, dev-surface, finalise-group), and
`static_asset`'s position becomes an explicit decision with its own test pair
rather than an assumption. Enumerate Node, Python and PHP next, then fix the list
once, then extract against it.

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
