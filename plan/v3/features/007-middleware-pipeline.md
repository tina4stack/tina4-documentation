# Feature 7: The middleware pipeline (registration, ordering, short-circuiting)

Audited 2026-07-31. Part of `98-feature-audit.md`.

Scope is the pipeline MECHANISM: how middleware is registered, how hooks are
discovered and ordered, what short-circuits the handler, and how a return value
is interpreted. The pre/post-match position of global middleware relative to the
auth gate is settled by ADR-0012 and is not re-opened here.

## Files

| | orchestrator | per-route dispatch |
| --- | --- | --- |
| python | `tina4-python/tina4_python/core/middleware.py` | `tina4-python/tina4_python/core/server.py` (`_run_before_middleware`) |
| php | `tina4-php/Tina4/Middleware.php` | `tina4-php/Tina4/Router.php` (`runRouteMiddleware`) |
| ruby | `tina4-ruby/lib/tina4/middleware.rb` | `tina4-ruby/lib/tina4/router.rb` (`Route#run_middleware`) |
| node | `tina4-nodejs/packages/core/src/middleware.ts` | `tina4-nodejs/packages/core/src/router.ts` (`runRouteMiddlewares`) |

Two columns, because every framework has TWO runners: a public orchestrator
(`Middleware.run_before` and friends) and a separate per-route path inside the
dispatcher. They are not the same code and, as measured below, they did not
agree with each other even inside one framework.

## Measurements

Baseline commits: python `0addbb4`, php `5dde39dc`, ruby `731eafa`, node
`0185103`. Measured on macOS (Darwin 25.5.0) with Python 3.14.5, PHP 8.5.7,
Ruby 4.0.2.

Module size:

| | orchestrator module LOC | orchestrator class LOC |
| --- | --- | --- |
| python | 450 | 113 |
| php | 285 | 242 |
| ruby | 596 | 268 |
| node | 794 | 253 |

The module totals are not comparable (each file also carries that framework's
built-in middleware classes). The class column is the pipeline itself, and it
lands within a factor of 2.4 across four languages, which is the healthiest
spread this audit series has produced.

### Registration surface

| form | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| global class (`Middleware.use` / `Router.use`) | yes | yes | yes | yes |
| per-route class | yes | yes | yes | yes |
| group | yes | yes | yes | yes |
| function middleware (`req, res, next`) | yes | yes | yes | yes |
| string spec (`"ResponseCache:300"`) | yes | yes | NO | yes |
| block-based (`Middleware.before(pattern) { }`) | no | no | ruby only | no |

Ruby was the only framework with no string spec, and the only one with a
pattern-matched block form that the other three have no equivalent for.

### Hook discovery across an inheritance chain

A `Base` class with one hook, a `Sub` extending it with one hook, run through
each framework's real discovery function:

| | before hooks | after hooks |
| --- | --- | --- |
| python | `['before_base', 'before_sub']` | `['after_base', 'after_sub']` |
| ruby | `[:before_base, :before_sub]` | `[:after_base, :after_sub]` |
| php | `["beforeSub", "beforeBase"]` | `["afterSub", "afterBase"]` |
| node | `["beforeSub"]` | `["afterSub"]` |

Node's inherited hook is not reordered, it is GONE. `Sub.beforeBase` is a live
function and `Object.getOwnPropertyNames(Sub)` never returns it.

### Return-value interpretation

| return value | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| the `[req, res]` pair | rebind | rebind | rebind | rebind |
| a Response object | crash, 500 | short-circuit | continue | continue |
| `false` | crash, 500 | short-circuit, 403 | short-circuit | continue |
| nothing | continue | continue | continue | continue |

### Which scope runs which phase

| | global before | global after | route before | route after |
| --- | --- | --- | --- | --- |
| python | yes | yes | yes | yes |
| php | yes | yes | yes | NO |
| ruby | yes | yes | NO | NO |
| node | yes | yes | NO | NO |

## What differs

**Three of four frameworks silently discarded middleware the developer
attached to a route.** This is the headline. `route.middleware(SomeClass)` is
an explicit, deliberate act, and in Ruby it raised `NoMethodError`, in Node it
was inert, and in PHP the `after*` half was dead code. Only Python ran both
phases at both scopes.

The failure modes differ and the difference matters for migration. Ruby's
`Route#run_middleware` called `mw.call(request, response)`; a class defining
`def self.before_auth` does not respond to `.call`, so Ruby users got a 500.
Node's `runRouteMiddlewares` invoked every spec as `mw(req, res, next)` and its
type, `MiddlewareSpec = Middleware | string`, never admitted a class at all.
PHP's `runClassMiddlewareHooks` looped only names starting with `before`, and
the router's single `runAfter` call was passed the GLOBAL list. So Ruby was
broken, Node and PHP were quiet.

**An after hook that never runs is not a cosmetic loss.** It is the release
half of an acquire, the stop half of a timer, and the response half of an
access log. The same bug at global scope was measured earlier in this audit
series at zero runs in five requests.

**`false` meant four different things.** PHP rendered a 403, Ruby halted, Node
ignored it, and Python crashed. Python's crash is worth spelling out because it
looks like a framework fault to the developer who hits it:
`_run_before_middleware` did `if result is not None: request, response = result`,
so returning `false` raised `TypeError: cannot unpack non-sequence bool` and
surfaced as a 500 with no mention of middleware.

**Ruby let a 403 through.** In `run_before`, the `status_code >= 400`
short-circuit sat INSIDE the branch that checks whether the hook returned a
2-element array. Proven with a real Request and Response, not read:

    hook sets 403, returns [req, res]  ->  run_before returns false, handler skipped
    hook sets 403, returns nil         ->  run_before returns TRUE,  handler RUNS

Python, PHP and Node all check the status unconditionally. A Ruby author who
wrote the Rails-shaped middleware (set the response, return nothing) got an
authorisation check that did not stop anything.

**PHP's discovery order contradicted its own docblock.** `Middleware.php`
asserted that "get_class_methods() returns method names in declaration order
(parent methods first, then the class's own, each in source order)". On PHP
8.5.7 it returns the class's OWN methods first and inherited ones after. The
comment had been wrong the whole time, and a reader trusting it would have
concluded PHP already matched Python.

**PHP's order was never a deliberate unwind.** Worth stating plainly so nobody
later reads it as design: PHP returned derived-then-base for BOTH before and
after hooks. It was one backwards result appearing twice, not a response-phase
reversal. There is no unwind anywhere in the four.

**Python's own two runners disagreed with each other.** The dispatcher
(`_middleware_500` in `server.py`) caught a throwing hook and produced a clean
500. The public orchestrator (`Middleware.run_before`) did not catch at all.
PHP's docblock claims its `middleware500` "Mirrors Python's `_middleware_500`",
a cross-reference to a behaviour the Python orchestrator did not have. That is
the kind of false citation that gets copied onward, so it is recorded here.

## The decision and its authority

Recorded as **ADR-0014** in `plan/v3/DECISIONS.md`. Summary:

**A Response object returned from a hook short-circuits, at any status.** That
is the primary rule. The deciding argument is the redirect: a "status >= 400"
state check cannot express one, so an auth middleware that sets 302 to `/login`
and expects the handler not to run gets the handler run anyway. The hole sits
in the most common middleware anyone writes.

Per ADR-0012 the real world was checked first, and it split. Django is
return-value driven (a middleware returning an `HttpResponse` short-circuits).
Rails is response-state driven: `AbstractController::Callbacks::ClassMethods`
states "If the callback renders or redirects, the action will not run." Laravel
and Express are return/next driven. No unanimous answer, so ADR-0012's ladder
did not settle it and it was decided on the merits.

The `status >= 400` check is RETAINED, documented in the code as a legacy
compatibility path rather than the mechanism. Three of four already had it and
removing it would break error middleware that sets 403 and returns nothing.

**Before hooks run base class first, then subclass**, in all four. Python and
Ruby already did. Django and Rails agree, and it is the only order that makes a
base class a base.

**After hooks keep the same order as before hooks.** Zero of the four unwind
them across an inheritance chain, and all four use ONE discovery function whose
only argument is the prefix. A symmetric unwind would mean a second code path in
four languages to produce an ordering nothing has ever had and no test or user
depends on. Maintainability means less code.

## What was fixed

All four, with regression tests carrying identical case names so the suites read
side by side:

| case | what it pins |
| --- | --- |
| `a before hook that returns a response object short circuits` | the primary rule |
| `a before hook that returns a redirect response short circuits` | the 302 the state check cannot reach |
| `a before hook that returns false short circuits with 403` | `false` means deny, in all four |
| `a before hook that returns nothing continues to the handler` | the null case |
| `a before hook that sets 4xx and returns nothing skips the handler` | the Ruby authorisation hole |
| `route class middleware runs its before hook` | scope parity |
| `route class middleware runs its after hook` | the phase that was dead in three |
| `hook discovery includes hooks inherited from a base class` | the hooks Node dropped |
| `inherited before hooks run before the subclass own hooks` | PHP's order |
| `a throwing before hook becomes a clean 500` | resilience, orchestrator included |
| `a throwing after hook does not stop the remaining after hooks` | one broken hook never silences the rest |

Plus: Ruby gained the string-spec mechanism the other three had, PHP's false
docblock was replaced with what the code does on a named PHP version, and
Python's orchestrator gained the exception handling its own dispatcher already
had.

## What was deliberately left

**The after pass runs in REGISTRATION order across middleware classes, in all
four. This is a latent correctness bug and it is not fixed here.**

The concrete failure, which is why this is a bug and not a style preference:

> Middleware A acquires a database connection in `before` and releases it in
> `after`. Middleware B writes an audit record in `after`. Registered A then B.
> In forward after-order, A releases the connection and THEN B writes the audit
> record, using a connection that has already been released. Reversed, B writes
> and then A releases, which is correct.

Any acquire/release, open/close or start/stop pair spanning two middlewares
nests wrongly today. Measured static fact, all four iterate the class list
forward in the after pass:

    python  core/middleware.py run_after         for mw_class in middleware_classes
    python  core/server.py _run_after_middleware for _mw_cls in _effective_middleware(...)
    php     Middleware::runAfter                 foreach ($middlewareClasses as $class)
    ruby    Middleware.run_after                 middleware_classes.each
    node    MiddlewareRunner.runAfter            for (const cls of classes)

Django reverses the response phase and says so verbatim in its own docs.
Express, ASP.NET Core and Laravel unwind too. Rails reverses `after_action`
relative to definition order, via `ActiveSupport::Callbacks`; note the official
Action Controller guide is silent on this, so cite the API doc, not the guide.

It is left because it is UNIFORM. It is not a parity defect, it changes
behaviour in all four at once, and this pass is already carrying three breaking
changes. It gets its own ADR.

**One thing whoever picks it up must not miss:** since ADR-0012 split global
middleware into pre-match and post-match phases, the after pass now runs over
BOTH. A correct unwind of `[pre..., post...]` is `[post reversed..., pre
reversed...]`, not a single reversal of the concatenated list. That interaction
needs deciding as part of the same ADR.

**Also left, and reported rather than unified:** the string-spec REGISTRIES
disagree. Python knows five names (`ResponseCache`, `RateLimit`, `RateLimiter`,
`Cors`, `CORS`); PHP and Node know one (`ResponseCache`); Ruby now has the
mechanism with `ResponseCache` wired, matching PHP and Node. Adding the
mechanism is pipeline scope. Deciding which middleware get names is a feature
question, scheduled separately.

**Related:** ADR-0012, ADR-0014, and
`plan/v3/features/006-router-and-dispatch.md`.
