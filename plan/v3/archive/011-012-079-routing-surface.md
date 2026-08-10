# Historical bundle: Features 11, 12, 79 and 64

> Archived when the feature inventory moved to one numbered file per feature.
> Current packets: `../features/011-rate-limiting.md`,
> `../features/012-response-types.md`, `../features/064-routes-cli.md` and
> `../features/079-route-groups.md`.

Audited 2026-08-01 on macOS 26.5.2 (Darwin 25.5.0), Python 3.14.5, PHP 8.5.7,
Ruby 4.0.2, Node 24.9.0. Part of `98-feature-audit.md`. Feature 6 (router and
dispatch) is closed and was not reopened.

Scope: **11** rate limiter, **12** response types, **79** route groups, **64**
the `tina4 routes` CLI. Decisions in ADR-0019.

## Files

| | rate limiter (11) | response types (12) | route groups (79) |
| --- | --- | --- | --- |
| python | `tina4-python/tina4_python/core/rate_limiter.py` | `tina4-python/tina4_python/core/response.py` | `tina4-python/tina4_python/core/router.py` |
| php | `tina4-php/Tina4/Middleware/RateLimiter.php` | `tina4-php/Tina4/Response.php` | `tina4-php/Tina4/Router.php` |
| ruby | `tina4-ruby/lib/tina4/rate_limiter.rb` | `tina4-ruby/lib/tina4/response.rb` | `tina4-ruby/lib/tina4/router.rb` |
| node | `tina4-nodejs/packages/core/src/rateLimiter.ts` | `tina4-nodejs/packages/core/src/response.ts` | `tina4-nodejs/packages/core/src/router.ts` |

The client key is resolved in the request object, not the limiter:
`tina4-python/tina4_python/core/request.py`, `tina4-php/Tina4/Request.php`,
`tina4-ruby/lib/tina4/request.rb`, `tina4-nodejs/packages/core/src/request.ts`.

## Headline: two security findings, both measured, both fixed

Everything below was measured through a real dispatch path or a real HTTP
server. Nothing here is read off the source alone. Where a claim started as a
source reading and was later measured, the measurement is what is recorded.

### 1. The rate limiter was bypassable, and worse, weaponisable

All four keyed on `X-Forwarded-For` with no trusted-proxy allow-list. Python,
through `TestClient` into `core.server.app`, `TINA4_RATE_LIMIT=3`:

| client behaviour | statuses over 6 requests | verdict |
| --- | --- | --- |
| fixed `X-Forwarded-For` | 200 200 200 429 429 429 | limiter works |
| rotating `X-Forwarded-For` | 200 200 200 200 200 200 | **full bypass** |
| forged victim address | victim gets 429 | **starvation** |

The starvation case is the reason this outranks an ordinary evasion. The key
was not merely self-selected, it was selectable for someone else, so one client
could exhaust a third party's quota.

### 2. Group middleware silently un-secured every write route inside it (Python)

Same handler, same method, no token, only difference is the group:

```
POST /probe/plain      (no group)              -> 401   correctly gated
POST /probe/grp/thing  (group with middleware) -> 200   gate gone
route table: /probe/plain auth_required=True, /probe/grp/thing auth_required=False
```

The middleware was a do-nothing audit hook. `Router.add` carried
`elif has_middleware: auth_required = False`, and group middleware lands in that
same list. So an app adding request logging to its `/api` group to IMPROVE
observability made every write endpoint in it public, with no warning and
nothing in `tina4 routes` to show it.

PHP, Ruby and Node were all already correct, and
`tina4-nodejs/packages/core/src/router.ts` annotates its version "parity with
PY-10-02" - naming Python as the framework that had the bug. Python was the
sole outlier.

## Difference table

### Feature 11, rate limiter

| | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| algorithm | sliding window log | sliding window log | sliding window log | sliding window log |
| clock | `time.monotonic` | `microtime` (wall) | `Time.now` (wall) | `Date.now` (wall) |
| client key BEFORE | XFF, unguarded | XFF then X-Real-IP | XFF then X-Real-IP | XFF, unguarded |
| client key AFTER | socket peer + allow-list | socket peer + allow-list | socket peer + allow-list | socket peer + allow-list |
| enabled by default | no, `TINA4_RATE_LIMIT` gates it | no, opt-in | no, opt-in | **YES, unconditional** |
| `X-RateLimit-Limit` | yes | yes | yes | yes |
| `X-RateLimit-Remaining` | yes | yes | yes | yes |
| `X-RateLimit-Reset` | yes, **duration** | **was absent**, now epoch | yes, epoch | yes, epoch |
| `Retry-After` on 429 | yes | yes | yes | yes |
| headers on a 200 | yes | yes | yes | yes |
| storage | per-process memory | per-process memory | per-process memory | per-process memory |

Three notes the table cannot carry.

**Node is the only framework that rate-limits by default.**
`tina4-nodejs/packages/core/src/server.ts` registers `rateLimiter()` as built-in
middleware with no env gate, so every Node app is limited to 100 requests per 60
seconds per client out of the box. Python gates on `TINA4_RATE_LIMIT` being set;
PHP and Ruby are entirely opt-in. This interacts directly with the fix: a Node
app behind an unconfigured proxy now buckets all traffic under the proxy address
AND is limited by default. That combination is the sharpest edge of the breaking
change and it is why the migration note matters most for Node.

**`X-RateLimit-Reset` means two different things.** Python emits a duration in
seconds; Ruby, Node and now PHP emit an absolute Unix timestamp. Three of four
agree, and the absolute form is the de-facto reading used by most public APIs.
Recommendation: align Python on the epoch. **Not done here** - it is a
Python-visible wire change that deserves its own decision rather than riding
along inside a security fix.

**Storage is per-process and unshared in all four.** N workers means N times the
effective limit. Documented behaviour, not a defect, but it belongs in the docs.

### Feature 12, response types

Content types and default statuses, measured.

| helper | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| `json` | `application/json` | `application/json` | `application/json; charset=utf-8` | `application/json` |
| `html` | `text/html; charset=utf-8` | `text/html; charset=UTF-8` | `text/html; charset=utf-8` | `text/html; charset=utf-8` |
| `text` | `text/plain; charset=utf-8` | `text/plain; charset=UTF-8` | `text/plain; charset=utf-8` | `text/plain; charset=utf-8` |
| `xml` | `application/xml; charset=utf-8` | `application/xml; charset=UTF-8` | `application/xml; charset=utf-8` | `application/xml; charset=utf-8` |
| `redirect` default | 302 | 302 | 302 | 302 |
| explicit status survives `json` BEFORE | yes | **no, reset to 200** | **no, reset to 200** | yes |
| explicit status survives `json` AFTER | yes | yes | yes | yes |

Three divergences remain open and are NOT fixed here:

1. **Ruby alone appends `charset=utf-8` to `application/json`.** The other three
   send it bare. JSON is always UTF-8 by RFC 8259, so the parameter is
   redundant but harmless. One of the four should move; three-of-four says Ruby.
2. **PHP alone uppercases `charset=UTF-8`.** Case-insensitive per RFC 9110, so
   this is cosmetic, but it is a visible wire difference and cheap to align.
3. **PHP's `json()` pretty-prints and its `__invoke` does not**, so the same
   data produces different bytes depending on which entry point a handler used.
   No other framework pretty-prints.

Auto-serialisation of an ORM model, a list of models and a `DatabaseResult`
works in all four. Python, PHP and Node duck-type on `to_dict`/`toDict`; Ruby
uses hard class checks against `Tina4::ORM` and `Tina4::DatabaseResult`, so a
model nested inside a Hash is not converted in Ruby where it is in Python and
PHP.

**Unserialisable values are handled four different ways**, and none of them is
loud:

| input | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| a set | stringified | n/a | stringified | **silently `{}`** |
| plain object, no `toDict` | stringified | **empty 200 body** | stringified | own enumerable props |
| circular reference | raises, 500 | **empty 200 body** | raises, 500 | throws, 500 |

PHP's is the worst of the four: `json_encode` returns `false`, the property is
typed `string`, the file has no `declare(strict_types=1)`, so `false` coerces to
`""`. The client gets `200`, `Content-Type: application/json`, and a zero-byte
body, with no log and no exception. `json_last_error()` is never checked. This
is silent data loss and it is recorded here as the next thing to fix in feature
12.

`response.file()` was found path-traversable in all four and is being fixed
separately, on `v3`, by the maintainer. Repro is recorded in that work, not here.

### Feature 79, route groups

| | python BEFORE | python AFTER | php | ruby | node |
| --- | --- | --- | --- | --- | --- |
| group middleware reaches children | yes | yes | yes | yes | yes |
| group middleware runs ONCE | **no, twice** | yes | yes | yes | yes |
| nested prefix composes | **no, dropped** | yes | yes | yes | yes |
| nested middleware composes | yes | yes | yes | yes | yes |
| middleware can open a write route | **YES** | no | no | no | no |
| group-level auth flag | none | none | none | `auth_handler:`, **inert** | none |

Two findings that survive this pass:

**Ruby's `auth_handler:` is dead.** `Tina4::Router.group(prefix, auth_handler:)`
stores it on the `Route` and propagates it into nested groups, but nothing in
the dispatch path ever calls it. `enforce_route_auth` reads `route.auth_required`,
which is set purely from the HTTP method. The only consumer is the dev-admin
badge, which shows `secure: !route.auth_handler.nil?`. So
`Tina4.group("/admin", auth: my_auth)` changes a badge and gates nothing. It is
a false sense of protection rather than a hole - the method default still
secures writes - but the parameter must either be wired or removed. Not done
here.

**Path joining is inconsistent and only PHP is right.** `group("/api")` plus
`get("users")` yields `/apiusers` in Python, Ruby and Node; `group("api")`
yields a route with no leading slash in Python and Node; `group("/api/")` yields
`/api//users` in Node. PHP normalises all four cases correctly
(`Router::addRoute` trims and collapses). PHP is the shape to port. Not done
here, because it is a behaviour change in three frameworks and unrelated to the
security work.

### Feature 64, `tina4 routes`

The Rust CLI does not implement it; `tina4 routes` is an external subcommand
forwarded to each framework CLI.

| | source of data | boots the app | shows order | `--json` |
| --- | --- | --- | --- | --- |
| python | `Router.get_routes()` after importing `app` | partly | yes | no |
| php | **`Router::list()`, which does not exist** | yes | no, grouped by method | no |
| ruby | `Tina4::Router.routes` after `initialize!` | yes | yes | no |
| node | filesystem scan of `src/routes` | **no** | **no, sorted by path** | no |

**PHP's `tina4php routes` is a hard fatal.** `tina4-php/bin/tina4php` calls
`\Tina4\Router::list()`. The real methods are `getRoutes()` and `listRoutes()`,
and there is no `__callStatic`, so the command raises
`Call to undefined method`. It cannot ever have worked.

**Nobody tests it.** There is no behavioural test for the `routes` command in
ANY of the four - the only coverage is a name-presence check in the command
manifest (`tina4-python/tests/test_cli_commands_manifest.py`,
`tina4-php/tests/CommandsManifestTest.php`). That is the root cause: a command
whose only test asserts its name is in a list is a command that can be fatally
broken indefinitely without anyone noticing.

Python also misses every auto-discovered `src/routes` file, because `_routes`
imports `app.py` only and discovery sits behind the `__main__` guard. Node never
boots the app at all, so it shows no programmatic routes. None of the four
prints middleware. Node actively SORTS by path, destroying the registration
order that decides which route wins.

**On the ADR-0015 follow-on.** ADR-0015 scheduled two visibility items: a
startup warning when a catch-all shadows a later route, and showing resolution
order in `tina4 routes`. Judged: it FITS, and the second half is nearly free
because Node's sort is a one-line deletion and Ruby and Python already emit
registration order. But it should not ride inside this change. The command has
to be repaired first (PHP fatal, Python discovery, Node not booting), and that
repair needs the behavioural tests that do not exist yet. Doing the visibility
work on top of a command that fatals in one framework and shows the wrong data
in two others would be building on sand. Recorded as the next piece of work,
scoped, not half-done here.

## What changed

| change | frameworks | breaking |
| --- | --- | --- |
| client key is the socket peer; `TINA4_TRUSTED_PROXIES` allow-list | all four | yes |
| rightmost non-trusted hop wins in the chain | all four | yes |
| `remote_ip` / `remoteIp` exposed | ruby, node | no, additive |
| middleware no longer disables the auth gate | python | yes |
| nested group prefix composes | python | yes |
| group middleware runs once | python | yes |
| `RateLimiter::apply()` no longer reads keys that do not exist | php | no, it was broken |
| `RateLimiter::apply()` no longer calls a method that does not exist | php | no, it was fatal |
| `X-RateLimit-Reset` emitted | php | no, additive |
| `json`/`html`/`text`/`xml` preserve an explicit status | php, ruby | yes |
| rate limiter re-reads its env after `.env` loads | python | no, it was broken |

`TINA4_TRUSTED_PROXIES` is the only new environment variable.

## Tests

Identical case names across the four, real requests, no doubles.

```
tina4-python/tests/test_trusted_proxy.py        14 cases
tina4-php/tests/TrustedProxyTest.php            14 cases
tina4-ruby/spec/trusted_proxy_spec.rb           14 examples
tina4-nodejs/test/trustedProxy.test.ts          15 assertions
tina4-python/tests/test_route_groups.py          7 cases
```

Shared names:

```
rate limit ignores forwarded for from an untrusted peer
rate limit honours forwarded for from a trusted proxy
rate limit forged forwarded for cannot starve another client
trusted proxy matches an exact address
trusted proxy matches a cidr range
trusted proxy matches an ipv6 address and range
trusted proxy matches an ipv4 mapped ipv6 peer
trusted proxy is empty by default
trusted proxy ignores a malformed entry
client ip takes the rightmost untrusted hop
client ip skips hops that are themselves trusted proxies
client ip is the peer when the peer is not trusted
client ip falls back to x real ip behind a trusted proxy
client ip ignores x real ip from an untrusted peer
```

Node carries one extra, `client ip reads a repeated forwarded for header`,
because only Node can receive a repeated header as an array and its limiter's
old inline derivation dropped the whole chain when it did.

Every gate was proven able to fail, surgically:

| probe | red | green |
| --- | --- | --- |
| python, restore the unconditional header read | 3 named | 11 |
| ruby, restore the unconditional header read | 4 named | 10 |
| php, restore the unconditional header read | 4 named | 10 |
| node, restore the unconditional header read | 4 named | 11 |
| python, restore the auth-disabling branch | 2 named | 5 |
| python, restore the double-merge of group middleware | 2 named | 5 |

Each probe asserts its anchor text is present before editing, so a no-op edit
fails loudly instead of reporting a false pass. That guard fired for real once
during this work and prevented a partial patch from being written.

## One changed assertion, and why

`tina4-nodejs/test/request.test.ts` asserted `X-Forwarded-For extracts first IP`
(`reqXFF.ip === "10.0.0.1"` from `"10.0.0.1, 10.0.0.2"`). That case pinned the
vulnerable behaviour on both counts: the header was believed with no proxy
declared, and the LEFTMOST hop won. It is replaced by a pair that pins the new
contract - the header is ignored from an untrusted peer, and behind a declared
trusted proxy the RIGHTMOST hop (`10.0.0.2`) wins - plus a case asserting
`remoteIp` is always the raw peer. No other existing assertion in any of the
four changed.

## Honest gaps

Not done, and not started:

- Python's `X-RateLimit-Reset` still means a duration where the other three mean
  an epoch.
- Ruby's inert `auth_handler:` on `Router.group`.
- Path-join normalisation in Python, Ruby and Node (PHP is the correct shape).
- PHP's silent empty 200 body when `json_encode` fails.
- `application/json` charset and `charset=UTF-8` casing.
- The whole of feature 64: PHP's fatal, Python's missing discovery, Node not
  booting, no `--json`, no behavioural tests anywhere, and the ADR-0015
  resolution-order follow-on that depends on all of it.
- The group regression tests exist in Python only. The other three behave
  correctly today, but the lock-in is missing there, which is exactly the
  condition that let this bug live in Python.
