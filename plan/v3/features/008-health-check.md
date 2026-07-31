# Feature 8: The health check endpoint

Audited 2026-07-31. Part of `98-feature-audit.md`. Measured, fixed, and shipped
on `feature/audit-008` in all four framework repos.

This is a wire contract. A Kubernetes probe, a load balancer, or an uptime
monitor reads it, so the path, the JSON shape and the status code matter more
than anything inside the handler.

## Files

| | handler | registration |
| --- | --- | --- |
| python | `tina4-python/tina4_python/core/server.py` (`_health_handler`) | same file, module level |
| php | `tina4-php/Tina4/App.php` (`getHealthData`) | same file (`registerHealthCheck`) |
| ruby | `tina4-ruby/lib/tina4/health.rb` (`handle`) | same file (`register!`) |
| node | `tina4-nodejs/packages/core/src/health.ts` (`buildHandler`) | same file (`createHealthRoutes`) |

## Measurements

Real servers, real HTTP over loopback, no mocks. macOS 26.5 (darwin arm64),
Python 3.13, PHP 8.5.7, Ruby 4.0.2, Node 24.9.0, all four at 3.13.94.

State BEFORE this audit:

| | default path | `/health` | `/__health` | degraded | probes a dependency |
| --- | --- | --- | --- | --- | --- |
| python | `/__health` | 200 | 200 | **503** | no |
| php | `/health` | 200 | **404** | never | no |
| ruby | `/__health` | 200 | 200 | never | no |
| node | `/__health` | 200 | 200 | never | no |

The bodies, exactly as they came off the wire:

```
python  {"status":"ok","uptime_seconds":0,"version":"3.13.94","framework":"tina4py","errors":0}
php     {"status":"ok","version":"3.13.94","uptime":0,"framework":"tina4-php"}
ruby    {"status":"ok","version":"3.13.94","uptime":0.86,"framework":"tina4-ruby"}
node    {"status":"ok","version":"3.13.94","uptime":0.08,"framework":"tina4-nodejs"}
```

**No framework probes any dependency.** Not the database, not the cache, not the
queue, not the network. Every one of these endpoints reports process state only.
That was confirmed in the source of all four and on the wire: pointing the app at
a dead database changes nothing in the response.

## What differed

**1. Python could report failure. The other three could not.** Python returned
503 when a `.broken` sentinel existed. PHP, Ruby and Node have no failure path at
all; they always answer 200 with `"status":"ok"`. They satisfied "never falsely
restart" by being blind, not by design.

**2. Python's 503 was the worst bug in the feature.** `_write_broken()` is called
from the REQUEST path, so any unhandled exception in any route wrote
`data/.broken/<timestamp>_<ErrorType>.broken`, and the handler returned 503 while
one existed. Nothing cleared the directory at boot. Measured end to end:

```
GET /health                        -> 200
GET /boom  (a route that raises)   -> 500   and writes data/.broken/*.broken
GET /health                        -> 503
.broken files on disk              -> ["2026-07-31T180350_ValueError.broken"]
...process restarted...
GET /health                        -> 503   still
```

Under a Kubernetes `livenessProbe` that is a CrashLoopBackOff caused by one bad
request. It is worse than a dependency outage, because a dependency comes back
and a file on disk does not. And it is the wrong signal in the first place: a
liveness failure means RESTART, and a restart cannot repair a route file that
fails to import. It will fail to import again.

**3. PHP answered neither documented path reliably.** `/__health` returned 404 on
a default install, though `docs/php/33-environment-variables.md` documents
`/__health` as the default in all four languages. Worse, PHP registered the
configured path ONLY, so setting the env var deleted the old path:

```
TINA4_HEALTH_PATH=/healthz
  /healthz -> 200
  /health  -> 404      (Python, Ruby and Node all keep /health here)
```

An operator adding a Kubernetes-friendly path silently removed the path their
load balancer was already using.

**4. Ruby's registration could be suppressed entirely.** `Health.register!`
guarded itself with `find_route("/health", "GET")`, but the signature is
`find_route(METHOD, PATH)`. The arguments were swapped. Usually that matched
nothing and the guard did nothing, but an ANY route matches any path, so an
ordinary catch-all made the guard fire and health was never registered:

```
Tina4::Router.any("/{slug}") { ... }   # a CMS catch-all
Tina4::Health.register!
routes         -> ["ANY /{slug}"]      # health absent entirely
GET /__health  -> {"page":"cms catch-all"}
```

**5. Three smaller wire divergences.** Python emitted `uptime_seconds` as an int
where the other three emit `uptime` as a float to 2 decimal places. Python named
itself `tina4py`; the others use the hyphenated package name. Only PHP sent
`Cache-Control: no-store`.

**6. The docs described a contract no framework implemented.** All four language
docs claim "returns 503 on broken files" and a `/__health` default. Only Python
did the first; PHP did not do the second. `docs/python/index.md` documents
`{"status": "ok", "uptime": 123.4}`, which Python did not emit.

## The decision, and whose authority it rests on

Per ADR-0012 the authority order is standard, then the platforms' own behaviour,
then add-on libraries, then internal precedent. For a health endpoint the
governing authority is the deployment target, and Docker plus Kubernetes is the
default target for Tina4.

**A failing health check returns a non-2xx status.** Nothing reads the body. A
`kubectl` httpGet probe and `curl -f` inside a Docker `HEALTHCHECK` both act on
the status code alone, so 200 with `"status":"unhealthy"` in the payload is
invisible to the thing meant to act on it. No Tina4 framework did this, so
nothing had to be removed. It is recorded so nothing introduces it.

**Liveness and readiness are different questions and must not share an
endpoint.** A liveness failure restarts the container. A readiness failure
withdraws traffic and restarts nothing. Wiring a dependency check into liveness
turns one database outage into a fleet-wide restart, and the restart does not fix
the database. That is the decisive split, and it settles Python's 503:

- A recorded route error is not a liveness failure. A restart cannot fix it.
- It is not a readiness failure either. One broken route should not withdraw all
  traffic from an app whose other routes serve fine.
- So it belongs in the body as a diagnostic and nowhere near a status code.

**Liveness is process-only, and the response itself is the signal.** `/__health`
answers 200 whenever it runs. The only way it fails is that the process cannot
answer, which is exactly the condition a restart repairs.

## What was fixed

| Fix | Frameworks | Breaking |
| --- | --- | --- |
| `/health` no longer 503s on a route error | python | yes |
| stale `.broken` sentinels cleared at boot | python | no |
| `uptime_seconds` int becomes `uptime` float | python | yes |
| `framework` becomes `tina4-python` | python | yes |
| `/__health` registered | php | no, additive |
| `/health` always kept as an alias | php | no, additive |
| `register!` no longer suppressed by a catch-all | ruby | no |
| `errors` / `latest_error` dropped from the body | python | yes |
| `_start_time` seeded at import | python | no |

All four now answer both `/__health` and `/health`, so one probe definition works
against any Tina4 app. Python, Ruby and Node already did this; PHP was the gap.

The body is now exactly four keys in all four frameworks: `status`, `version`,
`uptime`, `framework`. Python's `errors` and `latest_error` went with the 503.
Once they stopped driving the status code they were pure diagnostics, and
diagnostics do not belong on a probe path that Kubernetes never reads. Removing
one key from one framework is also less code than pulling an error count out of
three different internal trackers and inventing a fourth wire field.

The `.broken` machinery stays. It has real consumers beyond health: the dev
dashboard reads it in all four frameworks, and Python's MCP tools read it too. It
was checked before being touched, and it is not dead code. Error diagnostics live
there now.

One latent bug surfaced while measuring `uptime`: Python's `_start_time` defaulted
to `0`, so any read before `run()` stamped it reported seconds since 1970 rather
than seconds since boot. It is now seeded at import.

Tests, every one proven red against the unfixed code first:

- `tina4-python/tests/test_health_liveness.py`, 6 cases, 4 confirmed red
- `tina4-php/tests/HealthCharacterisationTest.php`, 10 cases, 2 confirmed red
- `tina4-ruby/spec/health_registration_spec.rb`, 5 cases, 2 confirmed red

## What was deliberately left

**Readiness is specified, not built.** A readiness endpoint that probes only the
dependencies an app actually configured, per backend, tested against real
services in four languages, is a feature rather than an audit fix. It is
specified in ADR-0014 and scheduled separately.

**`Cache-Control: no-store` is still PHP-only.** A cached health response lets a
load balancer keep routing to a dead instance. PHP sends the header globally;
Python, Ruby and Node send none. Worth closing, not closed here.

**No `HEALTHCHECK` in any Dockerfile.** Not one of the four repo Dockerfiles, and
none of the generated ones, carries a `HEALTHCHECK` instruction. This was left
undone rather than half done: the Docker daemon was unavailable on the audit
machine, so the instruction could not be built and run. The risk that makes
verification necessary is concrete: several of these images are Alpine or
distroless, and a `HEALTHCHECK` calling `curl` in an image without `curl` fails
every probe. Anyone adding it must build each image and watch the container reach
`healthy`. Note for the docs when it lands: plain `docker run` does not restart a
container on healthcheck failure. Only Swarm and Kubernetes act on it.

**Route precedence was not touched.** A catch-all ANY route shadows a specific
GET at dispatch, because `find_route` tries the ANY index before the method's own
bucket (`tina4-ruby/lib/tina4/router.rb:449`) and returns the first match. So an
app with a catch-all serves that catch-all on the health path even though the
health route is now correctly registered. This is a framework-wide route contract
owned by feature 6, not by health, and changing it affects every route in the
framework. Measured in Ruby only; the other three were not checked.

## Migration

The Python health body changed shape. Old and new, side by side:

```
old  {"status":"ok"|"error","uptime_seconds":<int>,"version":"...",
      "framework":"tina4py","errors":<int>,
      "latest_error":{...}}                          503 when errors > 0
new  {"status":"ok","version":"...","uptime":<float>,
      "framework":"tina4-python"}                    always 200
```

A probe asserting 503-on-`.broken` must stop asserting it. There is nothing to
probe for yet; dependency readiness arrives with ADR-0014. A consumer reading
`uptime_seconds` reads `uptime` instead and gets a float. A consumer matching
`framework == "tina4py"` matches `"tina4-python"`. A consumer reading `errors` or
`latest_error` reads them from the dev dashboard instead; `data/.broken` is still
written and the dashboard still surfaces it.

Both renames move Python onto the shape its three siblings already used and the
shape the published docs already described. Python was the outlier against its
own documentation.
