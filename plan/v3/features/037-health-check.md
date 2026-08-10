# Feature 037: Health and readiness endpoints

## Identity and status

- Matrix identity: 37 — Health and readiness endpoints
- Audit state: decision-ready
- Audit note: Implementation is deliberately deferred
- Dependencies: Feature 1 dotenv, Feature 30 dispatch and Feature 32 middleware
- Dependants: Docker images, generated deployment manifests and monitoring
- Existing ADRs: ADR-0016
- Shared fixtures: `fixtures/health_contract.json` version 1

- Release boundary: v3 / 3.14.0; parity-breaking corrections are permitted
- Re-audit date: 2026-08-10

Feature 37 is **not complete**. All four focused suites pass and all four ports
produce the approved four-key liveness body, but those suites only prove the
happy path. In every port application middleware can turn liveness into a 503,
and application routing can replace or shadow the endpoint. Readiness is absent,
three ports emit cacheable responses, three use wall-clock time for uptime, no
Dockerfile has a `HEALTHCHECK`, and the shared fixture checker does not execute
the contract it reports as proven.

This audit changes no framework source. It replaces the old record of repairs
with the clean-room contract and implementation formula required for this port
and for any future Tina4 language.

## Why this feature exists

An operator needs two small, dependable signals:

- **liveness:** can this Tina4 process answer HTTP at all? Failure permits a
  restart;
- **readiness:** can this instance serve its configured application workload
  now? Failure withdraws traffic but does not restart the process.

These endpoints are machine contracts, not diagnostic pages. They must keep
working when application authentication, rate limiting, middleware, routes or a
dependency are failing. An engineer must not write a probe handler, translate a
language-specific payload, install `curl` in a production image, or know Tina4
internals to deploy an application safely.

## Boundary

Feature 37 owns:

- reserved liveness and readiness paths and their aliases;
- bootstrap timing, path validation and route-conflict behavior;
- isolation from the application middleware and route pipeline;
- exact methods, status codes, headers and JSON schemas;
- the liveness uptime clock and lifecycle;
- the readiness-check registry, execution, timeout and aggregation rules;
- framework-provided checks for activated dependencies;
- Swagger descriptions for both system endpoints;
- repository and generated Dockerfile `HEALTHCHECK` instructions;
- generated Kubernetes probes;
- the executable parity fixture and four language runners.

It delegates:

- environment parsing and OS-over-dotenv precedence to Feature 1;
- ordinary route matching and HTTP method semantics to Feature 30;
- application middleware behavior to Feature 32;
- database, cache, session and queue connection mechanics to their adapters;
- diagnostic `.broken` files and error presentation to the dev/error features;
- graceful process termination to Feature 38.

The adapter features own a cheap, non-mutating dependency probe. Feature 37 owns
when those probes run and how their results become readiness.

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
| Handler and registration | `tina4_python/core/server.py` | `Tina4/App.php` | `lib/tina4/health.rb` | `packages/core/src/health.ts` |
| Default path | `/__health` | `/__health` | `/__health` | `/__health` |
| Permanent alias | `/health` | `/health` | `/health` | `/health` |
| Exact four-key body | yes | yes | yes | yes |
| Process-only when called directly | yes | yes | yes | yes |
| Immune to application middleware | **no** | **no** | **no** | **no** |
| Immune to application routing | **no** | **no** | **no** | **no** |
| Monotonic uptime source | **no** | **no** | yes | **no** |
| `Cache-Control: no-store` | **no** | yes | **no** | **no** |
| Readiness endpoint | no | no | no | no |
| Dockerfile `HEALTHCHECK` | no | no | no | no |

Audited source heads were Python `29feeab`, PHP `c75c7b0e`, Ruby `ea3aa88` and
Node `813b50b`, all on the staging `v3` branch. Their one local commit ahead of
origin only wires the approved Feature 1 fixture and does not change Feature 37.

The serialized lab baseline used root through
`/root/tina4-lab/with-lab-lock.sh`. Results against the current v3 lab clones:

| Framework | Focused result |
| --- | --- |
| Python | 7 passed |
| PHP | 10 tests, 17 assertions |
| Ruby | 11 examples |
| Node | 7 passed over real HTTP |

Those green numbers are characterization, not parity proof. Version 1 of the
fixture names selected test files and case-title strings; its checker searches
normalized source text. It runs none of the four implementations and covers
only 15 case/language pairs instead of applying every portable invariant to all
four languages.

### Liveness contract

#### Paths and methods

- `TINA4_HEALTH_PATH` selects the primary path; default `/__health`.
- `/health` is always present as a permanent compatibility alias.
- A custom primary path replaces the default `/__health`; it does not remove
  `/health`.
- `GET` and `HEAD` are supported. `HEAD` has the same status and headers as
  `GET` and no body.
- `OPTIONS` follows the Feature 30 automatic method contract.
- Other methods receive the canonical 405 and can never fall through to an
  application route.

#### Status and body

Liveness returns 200 whenever the server's system dispatcher can answer. It
does not inspect a database, cache, queue, filesystem sentinel, route import,
outbound network or recent application errors. A process too deadlocked or
broken to dispatch HTTP produces no successful response, which is the failure
signal the orchestrator needs.

The GET body has exactly these four keys:

```json
{
  "status": "ok",
  "version": "3.14.0",
  "uptime": 12.34,
  "framework": "tina4-python"
}
```

Rules:

- `status` is exactly `"ok"`;
- `version` is the runtime's public Tina4 version and must match the packaged
  artifact/release tag;
- `uptime` is a JSON number of elapsed seconds, non-negative and rounded to two
  decimal places;
- uptime comes from a monotonic clock and never decreases for one server
  instance, even if the system clock changes;
- creating or re-registering routes never resets uptime;
- `framework` is exactly `tina4-python`, `tina4-php`, `tina4-ruby` or
  `tina4-nodejs`; another port uses its canonical published package ID;
- no diagnostic or dependency keys are added.

JSON has one number type, so the old fixture's requirement that uptime be a
“float” is not portable. `0`, `0.0` and `0.00` are semantically the same JSON
number. The portable requirement is a non-negative number rounded to hundredths.

#### Headers

Both successful methods send:

- `Content-Type: application/json` for GET;
- `Cache-Control: no-store`;
- no `ETag` or `Last-Modified` validator.

A liveness response is instance- and time-specific. Caching or revalidating it
can return an old healthy answer for the wrong moment. HEAD retains the GET
representation headers, including content length when the transport normally
provides it, while suppressing the body.

### Readiness contract

#### Paths and status

- `TINA4_READINESS_PATH` selects the primary path; default `/__ready`.
- `/ready` is always present as a permanent compatibility alias.
- The same validation, reservation, methods, middleware isolation and cache
  headers as liveness apply.
- No registered checks means ready: 200 with an empty `checks` object.
- Every required check passing returns 200.
- Any thrown, malformed, failed or timed-out check returns 503.
- A readiness failure never changes liveness and never writes `.broken`.

The GET body has exactly five top-level keys:

```json
{
  "status": "error",
  "version": "3.14.0",
  "uptime": 12.34,
  "framework": "tina4-python",
  "checks": {
    "database": {"status": "error", "latency_ms": 5000}
  }
}
```

`status` is `"ok"` or `"error"`. The first four fields reuse the liveness
rules. `checks` is an object sorted by canonical check name. Every value has
exactly `status` and non-negative integer `latency_ms`; no exception text,
connection string, host, credential, query or stack trace is exposed.

#### Registry and execution

Each port exposes idiomatic equivalents of:

```text
Readiness.register(name, check)
Readiness.unregister(name)
Readiness.list()
Readiness.clear_application_checks()
```

Names are non-empty lowercase identifiers matching `[a-z][a-z0-9_-]*`.
Duplicate names fail registration; they do not silently replace a check. The
list surface exposes name and owner, not secrets. Framework-owned adapter checks
survive an application-check clear, though `unregister` may target one to downgrade
an optional dependency.

A dependency is "required" when it is ACTIVATED - its connection is configured and
the framework wired it - not merely when its driver package is installed. Every
activated database, cache, session store or queue registers one framework-owned
check under its canonical name, so a configured dependency gates readiness by
default. An application downgrades a genuinely optional dependency (for example a
performance cache it can serve without) by calling `Readiness.unregister` on that
canonical name after boot; its outage then no longer withdraws traffic.
Applications may also register other required checks explicitly.

Checks are side-effect-free and use the live adapter's cheapest native probe:
no schema changes, writes, dequeue, publish, reconnect loop or outbound retry
storm. All checks start concurrently and are collected in sorted-name order.
`TINA4_READINESS_TIMEOUT` is a native Feature 1 number of seconds, defaults to
`5`, must be greater than zero, and is one hard deadline for the whole request.
The deadline is enforced by bounding each framework adapter probe's own driver
connect/statement timeout by the readiness timeout, so the blocking call returns
at the deadline in synchronous runtimes too, not only where the runtime can cancel
an awaitable. An application-registered check must bound itself the same way,
because the framework cannot interrupt arbitrary blocking code in a sync runtime.
Work still running at the deadline is reported as error. Consecutive requests do
not share a result cache.

## Public surface contract

The audit has not yet extracted a language-neutral public surface and its idiomatic spellings.

## Inputs and outputs

The audit has not yet fixed all native types, defaults, nullability, ordering, and serialized shapes.

## Lifecycle and operation graph

The audit has not yet traced every producer, discovery, execution, inspection, retry, rollback, and deletion path.

## Configuration and precedence

### Path configuration

Both configured paths use the Feature 30 exact literal system-path validator:

- absolute and beginning with one `/`;
- no parameter, wildcard, query, fragment or backslash syntax;
- no control characters, whitespace-only segments or traversal segments;
- not `/`, and not equal to another reserved system path;
- no silent trimming, leading-slash insertion or other repair.

An unset or empty variable selects its default. A non-empty invalid value fails
startup outright with the variable name and value location. Resolution occurs
after dotenv, so an OS value wins and a `.env` value is not lost to an early
module-import snapshot. The effective path is fixed for that server instance;
changing the process environment later does not mutate a live routing table.

## Failures, side effects and security

The audit has not yet closed every failure boundary, side effect, cleanup rule, and security concern.

## Wire and persistence contract

The audit has not yet fixed every wire format, stored shape, encoding, identifier, timestamp, and compatibility rule.

## Providers and substitutability

The audit has not yet proved provider substitution or recorded deliberate capability exceptions.

## Contradictions and defects

### Contradictions and defects measured on 2026-08-10

| ID | Severity | Measured contradiction | Required correction |
| --- | --- | --- | --- |
| H8-01 | P1 | A dependency-style global middleware made `/health` return 503 in all four ports. Liveness therefore depends on application middleware despite ADR-0016's process-only rule. | dispatch reserved system routes before the application middleware pipeline |
| H8-02 | P1 | Python, PHP and Ruby allowed a later exact app route to replace `/health`; Node served a previously registered `/{slug}` catch-all body on `/health`. | reserve exact system paths, reject literal conflicts and give system routes an unshadowable dispatch tier |
| H8-03 | P1 | Readiness is absent in all four ports. Existing deployment plans/manifests point both readiness and liveness at `/health`, so a dependency outage cannot withdraw traffic without abusing liveness. | implement the readiness registry/endpoint and generate distinct probes |
| H8-04 | P2 | Python uses `time.time`, PHP `microtime(true)` and Node `Date.now`; all are wall clocks that can jump. Node also resets its module start time whenever health routes are created. Only Ruby uses `CLOCK_MONOTONIC`. | capture one monotonic server start point and calculate nondecreasing elapsed time |
| H8-05 | P2 | Only PHP sends `Cache-Control: no-store`. Python, Ruby and Node omit it; Python also emitted an ETag for the dynamic body. | canonical no-store/no-validator response finalization for GET and HEAD |
| H8-06 | P2 | Python resolves `TINA4_HEALTH_PATH` at module import. Its package imports the server before CLI dotenv loading, so a `.env` path can arrive too late; the other ports resolve during setup. | resolve after Feature 1 and snapshot during server bootstrap |
| H8-07 | P2 | Invalid-path behavior differs: Node trims and inserts `/`, PHP/Ruby insert `/`, and Python accepts the raw value. | use one strict literal-path validator and fail startup instead of repairing input |
| H8-08 | P2 | `health_contract.json` v1 applies most invariants to only one or two ports. `audit-health-contract.py` searches case-title text and prints OK without executing behavior. | replace with executable data, four consumers and a central result validator |
| H8-09 | P2 | No repository or generated Dockerfile has a `HEALTHCHECK`, although the lab Docker daemon is available for real image verification. | add runtime-native checks and gate healthy/unhealthy transitions on built images |
| H8-10 | P2 | Deployment and console plans still describe Python's removed `.broken`-driven 503 and use `/health` for readiness. | update deployment, environment and error-handling documentation from the approved contract |
| H8-11 | P3 | Existing suites prove advancing uptime by sleeping and do not test clock rollback, middleware isolation, reserved paths, headers, HEAD, env timing, readiness, fixture consumption or images. | add deterministic clock seams and the full parity matrix below |

No framework source was changed during this audit.

## Owner decisions

### Owner decisions APPROVED (finalized 2026-08-10)

Feature 37 carried its decisions in the prose rather than a decisions section. The
review surfaced four; Andre settled them.

- **A: ADR-0016 is SUPERSEDED by a new ADR-0046, not amended in place.** The
  system-route-tier, monotonic-uptime, readiness-body, strict-path and no-store
  header clauses move into ADR-0046 (per the supersede-don't-silently-change
  convention, matching ADR-0014 -> ADR-0045). ADR-0016's liveness/readiness split
  stays correct and gets a Superseded-by pointer.
- **B: the readiness timeout is enforced by bounding each probe's driver timeout,
  not by runtime cancellation.** Each framework adapter check sets its driver
  connect/statement timeout to `TINA4_READINESS_TIMEOUT` (reusing the shipped
  connect-timeout work), so the blocking call itself returns at the deadline in
  synchronous PHP and Ruby as well as async Node/Python. App-registered checks are
  contractually required to be self-bounding, because the framework cannot interrupt
  arbitrary blocking code in a sync runtime.
- **C: `/health` and `/ready` stay strict and unshadowable (ratified).** An app that
  declares an exact reserved path fails startup and moves its route. This is what
  lets the generated Dockerfile HEALTHCHECK and k8s probes hardcode the permanent
  `/health`; there is no opt-out, by design.
- **D: a dependency is "required" when it is ACTIVATED (connection configured), not
  merely package-installed.** Every activated adapter auto-registers a readiness
  check (fail-safe: configured deps gate readiness). An app downgrades a genuinely
  optional dependency (e.g. a performance cache) via the existing
  `Readiness.unregister` so its outage does not withdraw traffic.

FINAL bar unchanged: publish ADR-0046, materialize `health_contract.json` v2, wire
the four runners, and pass the real-image + real-dependency lab matrix.

## Proposed conformance fixture

### Executable parity fixture version 2

`health_contract.json` becomes runtime-neutral input and expected output, not a
catalogue of English case names. It contains:

- fixture version and canonical SHA-256;
- framework IDs and coordinated release version input;
- default, alias, custom and invalid path cases;
- exact liveness and readiness schemas;
- fake monotonic-clock sequences, including wall-clock rollback;
- route-error, `.broken`, middleware short-circuit, auth, rate-limit, exact
  conflict and catch-all cases;
- readiness pass, failure, throw, malformed result, timeout, duplicate name,
  empty registry and concurrent timing cases;
- GET, HEAD, OPTIONS, 405, cache header and validator expectations;
- Docker liveness and Kubernetes path expectations.

Each language runner consumes the same file and emits one JSON report containing
at least:

```json
{
  "feature": 8,
  "fixture_version": 2,
  "fixture_sha256": "...",
  "framework": "tina4-python",
  "consumed_case_ids": ["..."],
  "failures": []
}
```

The central checker executes all four runners, rejects a stale hash, requires
the exact case-ID set from every language, validates the report schema and exits
non-zero on any failure. Text presence in a test file proves nothing.

Mutation witnesses must demonstrate that the suite fails when:

- health is moved behind application middleware;
- a catch-all or exact app route owns a reserved path;
- `no-store` is removed or an ETag is added;
- a wall clock replaces the monotonic clock or registration resets uptime;
- readiness maps a failed check to 200 or liveness to 503;
- dependency checks run serially;
- a runner reports an old fixture hash;
- a Docker probe merely connects but accepts 404.

### Required test matrix

All behavioral cases run through real dispatch; wire cases additionally use a
real loopback socket. Dependency cases use real lab services as well as a
deterministic check seam for timeout/throw ordering.

| Area | Required proof in every language |
| --- | --- |
| Bootstrap | dotenv path is visible; OS wins; late env mutation does not alter routes; invalid/colliding values fail startup |
| Reservation | exact app conflict fails; parameterized catch-all cannot shadow; re-registration and reload cannot replace system routes |
| Isolation | blocking pre/post middleware, auth, CSRF, sessions, cache and rate limiter never execute on system routes |
| Liveness | both paths 200; route throw/import error/dead configured dependency/`.broken` do not change it; exact body |
| Uptime | deterministic monotonic values, rollback witness, non-negative hundredths and no reset on route registration |
| Transport | GET/HEAD/OPTIONS/405, JSON content type, no-store, no validators, HEAD without body |
| Readiness | empty/pass 200; fail/throw/malformed/timeout 503; exact sorted redacted body; liveness remains 200 |
| Dependencies | each activated adapter's non-mutating check against a real available and unavailable lab service |
| Concurrency | two slow checks complete within one timeout window rather than their summed duration |
| Swagger | paths, aliases, schemas, 503 and no security requirement match the runtime contract |
| Images | build each repo/generated image, observe healthy, prove wrong status becomes unhealthy, confirm version/tag match |
| Fixture | four reports use the current hash and exact complete case-ID set |

The current 35 focused tests/examples remain useful characterization and should
be migrated into the runners rather than discarded.

## Integration map

### Platform authority

ADR-0016's liveness/readiness split remains correct. Kubernetes defines
liveness failure as a reason to restart a container and readiness failure as a
reason to remove a Pod from Service endpoints. It also warns that incorrect
liveness probes can cause cascading failures. A startup probe can suppress both
until initialization succeeds. See the current
[Kubernetes probe documentation](https://kubernetes.io/docs/concepts/workloads/pods/probes/).

Docker assigns health from the probe command's exit status: `0` is healthy,
`1` is unhealthy and `2` is reserved. It supplies interval, timeout,
start-period and retry controls, and only the final `HEALTHCHECK` instruction in
a Dockerfile applies. See the current
[Dockerfile reference](https://docs.docker.com/reference/dockerfile/#healthcheck).

Neither platform requires a particular JSON body. Tina4 therefore owns that
small wire schema and keeps it identical in every language.

### Bootstrap and system-route ownership

Health routes are reserved **system routes**, not ordinary application routes.
Bootstrap order is:

1. initialize framework constants and load Feature 1 dotenv;
2. resolve the effective paths using OS-over-dotenv precedence;
3. validate every path and reserve it in the system-route table;
4. discover application routes and reject an exact reserved-path declaration;
5. initialize activated dependency adapters and their readiness checks;
6. start accepting traffic;
7. capture the monotonic server-instance start point exactly once.

The system-route table is dispatched before application route matching and
before all user/global/group/route middleware. Authentication, sessions, CSRF,
rate limiting, response caching and dependency middleware never run for these
paths. Framework-owned transport behavior may still add request IDs, security
headers and request logs provided it cannot short-circuit or change the probe
status.

An application declaring an exact `GET`, `HEAD`, `OPTIONS` or catch-all-method
route on a reserved literal path fails startup with the path and source. A
parameterized application catch-all is allowed, but the exact system route wins.
System registration is idempotent and cannot be replaced by later route or
hot-reload registration.

This is intentionally stronger than ordinary Feature 30 specificity. A probe
must never receive an application's CMS catch-all body while still returning
200.

### Swagger contract

Both primary system endpoints and their permanent aliases are described under
the `System` tag even when Swagger serving is disabled by default. Their
descriptions state the operational meaning, status codes, exact response schema
and that no authentication is required. Readiness documents 503. Generated
clients may omit system operations, but the OpenAPI document must not invent a
different body or mark the routes secure.

### Docker and Kubernetes contract

Every repository Dockerfile and every generated Dockerfile includes exactly one
runtime-native liveness `HEALTHCHECK`. It targets `/health`, not a configurable
path, because that alias is permanent. It checks for an HTTP success status and
exits 1 otherwise. It uses a runtime standard library already present in the
image rather than assuming `curl` or `wget` exists.

The common policy is:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 CMD <runtime-native GET /health or exit 1>
```

The command must have a hard client timeout below the Docker timeout and must
not treat a received 404/503 as success. Each image is built and run on the lab;
CI waits until `docker inspect` reports `healthy`, then proves an intentionally
wrong probe reports `unhealthy`. The existing image gate that verifies `/health`
over the published port and matches the served version to the tag remains.

Generated Kubernetes manifests use:

- `startupProbe` on `/health` with a budget suitable for application startup;
- `livenessProbe` on `/health`;
- `readinessProbe` on `/ready`.

They never point readiness at liveness. Generated values expose probe timing,
not alternate body schemas. Deployment documentation explains that liveness
restarts, readiness withdraws traffic, and Docker health status alone does not
promise an automatic restart policy.

## Breaking changes and migration

### Migration to 3.14.0

- Application routes that explicitly claim a reserved health/readiness path now
  fail startup. Move the application route.
- Invalid configured paths no longer receive a leading slash or whitespace
  repair. Correct the environment value.
- Health endpoints bypass all application middleware. Move probe-specific
  telemetry to framework transport instrumentation.
- Uptime remains seconds under `uptime`, but becomes monotonic and is defined per
  server instance.
- Python/PHP/Node clock behavior and Python dotenv timing change internally
  without changing the approved happy-path body.
- Python/Ruby/Node add `Cache-Control: no-store`; Python drops its ETag on these
  endpoints.
- `/__ready` and `/ready` are additive. Generated Kubernetes readiness changes
  from `/health` to `/ready`.
- Images gain a Docker health status. Deployment tooling must not assume that an
  `unhealthy` status alone selects a restart policy.

## Implementation backlog

The audit has not yet produced a dependency-ordered backlog for all current languages and future ports.

## Porting capsule

### Implementation formula for another language

1. Implement Feature 1 loading and Feature 30 literal-path validation first.
2. Create a system-route registry that is dispatched before application routes
   and Feature 32 middleware.
3. Resolve, validate and reserve liveness/readiness primary paths plus permanent
   aliases after dotenv and before route discovery.
4. Capture one monotonic start point for the server instance and implement the
   exact four-key liveness representation.
5. Implement response finalization for GET/HEAD with no-store and no validators.
6. Implement the readiness registry, concurrent deadline-bound executor and
   exact five-key representation.
7. Give activated dependency adapters side-effect-free probes and register them
   under canonical names.
8. Add Swagger metadata, a runtime-native Docker `HEALTHCHECK` and separate
   Kubernetes startup/liveness/readiness probes.
9. Consume fixture version 2, emit the standard report and pass every case plus
   mutation witnesses locally.
10. Build and run the real image and real dependency matrix on the serialized
    lab before marking the feature proven.

A future language is complete only when its runner can be added to the central
checker without changing the fixture or expected behavior. Language syntax and
runtime primitives may differ; the observable contract may not.

## Audit closure checklist

- [ ] Boundary and public surface complete.
- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Configuration, failure, side-effect and security rules complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [ ] Proposed shared cases and mutation witnesses complete.
- [ ] Integration map and breaking migrations complete.
- [ ] Implementation backlog dependency-ordered.
- [ ] Porting capsule is clean-room sufficient.

### Completion gate

Feature 37 is complete only when:

- H8-01 through H8-11 are closed in all four current ports;
- ADR-0046 is published, superseding ADR-0016's system-route, uptime,
  readiness-body, path and header clauses (ADR-0016 keeps a Superseded-by pointer);
- fixture version 2 and the four runners pass from the central checker;
- every mutation witness is proven red;
- real lab dependency failure changes readiness to 503 while liveness stays 200;
- all four repository images and generated images reach Docker `healthy`;
- generated Kubernetes manifests use `/health` for startup/liveness and `/ready`
  for readiness;
- documentation no longer describes `.broken` as probe state;
- local and serialized lab parity runs are green with zero unexplained skips.
