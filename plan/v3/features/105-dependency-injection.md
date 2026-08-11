# Feature 105: Dependency injection container

## Identity and status

- Matrix identity: 105 - Dependency injection container (register / singleton / get / has / reset)
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-11 at Python `container/__init__.py` (105), PHP
  `Tina4/Container.php` (102), Ruby `lib/tina4/container.rb` (74), Node `packages/core/src/container.ts`
  (90). Suites are reported, not re-run.
- Dependencies: none. The container is a pure in-memory registry with no external collaborator.
- Dependants: application wiring only. No framework subsystem resolves itself through the container.
- Existing ADRs: none.
- Shared fixtures: NONE. `container_contract.json` is owed (DI-FIXTURE). Each language has a real,
  no-mock suite (Python 34, PHP 25, Ruby 17, Node 34) whose comments claim cross-language parity, but the
  reset / instantiation / register-instance behaviours demonstrably diverge and no shared oracle enforces
  them.

- Catalog phase: Developer internals

## Why this feature exists

The container is a small service locator: register how to build a thing under a name, resolve it later
by that name. `register` makes a transient (a new instance on every `get`); `singleton` makes a
memoized one (built once, same instance thereafter). It lets an application centralize construction of
its database handle, queue, mailer, and config without threading them through every call site.

It is deliberately minimal and zero-dependency. It does NOT autowire (no reflection over constructor
types), does NOT inject the container into factories, and the framework itself does not use it - core
services (db, queue, cache, session) are wired through their own modules and env vars. The container is
a convenience for application code, not a framework backbone.

## Boundary

This packet owns the container: registration (`register`, `singleton`), resolution (`get`), and the
`has` / `reset` surface. It owns the transient-vs-singleton semantics and the memoization.

It does NOT own: the services an application registers in it; the framework's own service wiring (which
bypasses the container); the Ruby `Tina4.register`/`singleton`/`resolve` DSL shims and the Node
module-global `container` (those are thin surface over this class/module).

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Type | `class Container` (instance) | `class Container` (instance) | `module Container` (global singleton) | `class Container` + global `container` |
| Public surface | register, singleton, get, has, reset, reset_all | register, singleton, get, has, reset | registry, register, singleton, get, has?, reset | register, singleton, get, has, reset |
| Factory model | callable only | callable only | block OR raw instance | function only |
| reset() scope | singleton cache only (keeps factories) | everything | everything | everything |
| Unknown key | `KeyError` | `RuntimeException` | `KeyError` | `Error` |
| Thread guard | `threading.Lock` (held across factory - DI-01) | none (N/A) | none (racy) | none (N/A, single-thread) |
| Global default | none | none | the module IS global | `container` module-global |
| Focused tests | 34 real | 25 real | 17 real | 34 real |

## Public surface contract

The intended shared surface is `register(name, factory)`, `singleton(name, factory)`, `get(name)`,
`has(name)`, and `reset()`, with two consistent semantics everywhere: a transient returns a new value on
every `get`; a singleton is lazy and memoized. Factories are called with NO arguments (the container is
not passed), and nothing autowires - registration is always explicit. `get` on an unknown name raises;
it never returns null.

Around that shared core, the surface actually diverges: Python adds `reset_all()`; Ruby names the query
`has?`, exposes a public `registry` reader, and its `register` also accepts a raw instance; Node's `get`
is generic (`get<T>`) and ships a module-global default container. These are the findings below.

## Inputs and outputs

- `register` / `singleton` input: a name and a factory callable (Ruby also a raw instance). Output: void.
  A non-callable factory is rejected with the language's type error in Python, PHP, and Node.
- `get(name)` output: a transient builds and returns a fresh value each call; a singleton returns the
  one memoized value. An async factory (Node) is memoized as a Promise the caller must await.
- `has(name)` output: a boolean.
- `reset()` output: void, but the SCOPE diverges (DI-RESET): Python clears only the singleton cache; PHP,
  Ruby, and Node clear the whole registry.
- Unknown `get` output: a raise (`KeyError` Python/Ruby, `RuntimeException` PHP, `Error` Node) with the
  message "service not registered: <name>" (PHP capitalizes "Service").

## Lifecycle and operation graph

1. `register` / `singleton` store the factory (and a singleton flag) under the name; nothing is built.
2. `get` looks up the entry, builds a transient every time, or builds-and-memoizes a singleton on first
   call.
3. `has` reports registration; `reset` clears (cache-only in Python, everything elsewhere).
4. There is no framework lifecycle involvement: the container is constructed and used entirely by
   application code (Ruby's is a process-global module; Node also offers a process-global default).

## Configuration and precedence

The container reads NO environment variables in any language. There is nothing to configure: behaviour
is fixed and in-memory. Registration is the only input.

## Failures, side effects and security

- Unknown key: raises in all four (see above). Clean, no stack leak.
- Circular / nested resolution: NO language guards it. Python is the worst (DI-01): the factory runs
  while a non-reentrant `threading.Lock` is held, so a factory that calls `get()` to resolve a
  dependency - circular OR a plain A-needs-B chain - re-enters `get`, tries to re-acquire the same lock
  on the same thread, and DEADLOCKS (hangs). PHP, Ruby, and Node instead recurse to a stack overflow on
  a true cycle, but a non-circular nested `get()` works there. Untested in all four.
- Falsy memoization (DI-FALSY-MEMO): a singleton whose factory returns a falsy value is re-run on every
  `get` in Python (`is None`), PHP (`=== null`), and Ruby (`||=`), because the memo slot stays empty.
  Only Node uses a key-presence check and memoizes it correctly.
- Thread safety (DI-THREAD): Python locks (but the lock is the DI-01 deadlock cause and serializes every
  `get`); Ruby has no lock, so two threads racing a singleton's first `get` can both run the factory;
  PHP is shared-nothing per request; Node is single-threaded and correct (an async factory is invoked
  exactly once and its Promise is shared).
- No security surface: process-local, in-memory, no untrusted input executed, no secrets held.

## Wire and persistence contract

There is no wire format and no persistence. State is an in-memory map/hash, process-local, lost on
restart. Python and PHP hold it per instance; Ruby holds one process-global module registry; Node holds
per-instance plus one module-global default. `reset` is the only bulk clear.

## Providers and substitutability

There is no external provider. Each container is a hand-rolled registry over the language's native map.
The only substitutability is what the application registers. No dependency is added in any language, and
none of the four autowires - so the container never substitutes a dependency it was not explicitly given.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| DI-01 | Python deadlocks on nested resolution. The factory runs while a non-reentrant `threading.Lock` is held, so a factory that calls `container.get()` for a dependency (circular OR a simple A-needs-B chain) re-acquires the same lock on the same thread and hangs. It also serializes every `get`. Latent, untested. The other three do not have this (no lock across the factory). | FIX Python: release the lock before invoking the factory (compute outside the critical section, or use a double-checked pattern), or use an `RLock`. Add a regression: a factory that resolves another registered service returns without hanging. |
| DI-RESET | `reset()` semantics diverge 1-vs-3, and Python contradicts the doc. Python `reset()` clears only the singleton cache and keeps factories; PHP, Ruby, and Node `reset()` clear the entire registry. Python alone adds `reset_all()`. The CLAUDE.md contract describes `reset()` as "clear all registrations", which matches the other three, not Python. | OWNER DECISION (DI-DEC-01), needs discussion (breaking either way). Recommendation: adopt the consensus - `reset()` clears everything in all four (matches PHP/Ruby/Node and the doc), and either drop Python's `reset_all()` or keep it as an alias; if a cache-only reset is wanted, add it as a distinct named method (`reset_singletons`) to all four rather than overloading `reset`. |
| DI-GLOBAL | The instantiation model is not uniform. Python and PHP are instance-only (no global default); Ruby is a global module (not instantiable) with a `Tina4.register`/`singleton`/`resolve` DSL; Node offers both a `Container` class and a module-global `container`. A program written against one model does not port to another. | OWNER DECISION (DI-DEC-02). Recommendation: adopt Node's model everywhere - ship a `Container` class AND a process-global default instance in all four (Ruby keeps its DSL as sugar over the global). That satisfies both the "one shared container" and the "isolated container" use cases uniformly. |
| DI-REGISTER-INSTANCE | Ruby's `register(name, instance = nil, &factory)` accepts a raw instance OR a factory block; Python, PHP, and Node accept a factory callable only (a raw value must be wrapped in a lambda). Ruby also cannot register a FALSY raw instance (its `instance || factory` guard rejects `false`/`nil`). | OWNER DECISION (DI-DEC-03). Recommendation: add a uniform raw-value path everywhere - either a dedicated `instance(name, value)` method or a documented `register(name, () => value)` idiom - and pick one so the surface matches. If Ruby keeps the overload, fix the falsy-instance guard (distinguish "no argument given" from "a falsy value given"). |
| DI-FALSY-MEMO | A singleton whose factory returns a falsy value (None/null/false/0/"") is re-run on every `get` in Python, PHP, and Ruby (empty-slot memo check), defeating "built once". Only Node memoizes it correctly via a key-presence check. | FIX Python, PHP, Ruby: memoize on key presence (a "built" flag or a sentinel), not on truthiness of the cached value, matching Node. Add a falsy-singleton regression. |
| DI-THREAD | Thread-safety is inconsistent. Python locks (but see DI-01); Ruby has no lock and a concurrent first-`get` of a singleton can run the factory twice; PHP and Node do not need one. | Tie to DI-01 and DI-DEC-01. If thread-safe singletons are a goal, Ruby should guard only the memo write with a `Mutex` (never held across the factory), and Python's lock scope should be fixed the same way. Otherwise document that singleton construction is not thread-safe. |
| DI-ERROR | Unknown-key error type is language-idiomatic (`KeyError` / `RuntimeException` / `Error`) - acceptable - but the message case differs: PHP emits "Service not registered", the others "service not registered". | Low priority. Align PHP to the lowercase "service not registered" message for a byte-identical contract. |
| DI-FIXTURE | No `container_contract.json`, no CONTRACT-MAP row, no ADR. Four real suites with parity comments but no shared oracle, and the reset/global/register divergences above are unproven against each other. | Add `container_contract.json` (below) and the first Container ADR ratifying the resolved decisions. |

## Owner decisions

- DI-DEC-01 (proposed, DISCUSS): unify `reset()` to clear everything (the PHP/Ruby/Node/doc consensus);
  handle Python's `reset_all()` and any cache-only reset as a separate uniform method. Breaking to Python.
- DI-DEC-02 (proposed): adopt the class + module-global-default model in all four (Node's shape).
- DI-DEC-03 (proposed): provide a uniform raw-instance registration path; fix Ruby's falsy-instance guard.
- DI-DEC-04 (proposed): fix the correctness bugs - DI-01 (Python lock/deadlock), DI-FALSY-MEMO (Python,
  PHP, Ruby), and DI-THREAD (Ruby) - with named regressions.

## Proposed conformance fixture

`container_contract.json` - one scripted sequence per language against a real container (no doubles;
factories are plain closures returning real objects). Cases:

- Transient: two `get`s return distinct instances; the factory ran twice.
- Singleton: two `get`s return the same instance; the factory ran once; it is lazy (not called before
  the first `get`).
- Falsy singleton (DI-FALSY-MEMO witness): a singleton factory returning a falsy value runs exactly once
  (fails on current Python, PHP, Ruby).
- Nested resolution (DI-01 witness): a factory that resolves another registered service returns without
  hanging (fails on current Python).
- Unknown key: `get` raises with "service not registered: <name>".
- has: true for a registered name (transient or singleton), false otherwise.
- reset (DI-RESET witness): assert the ratified scope - after `reset`, `has` and `get` behave per
  DI-DEC-01 identically in all four.
- Non-callable factory: rejected with the language's type error.
- Independence: two containers (or the global vs a fresh one) do not share state.
- Zero-arg factory: the factory receives no arguments.

## Integration map

- Exports: each language exports the container type (Node also the module-global `container`; Ruby also
  the `Tina4.register`/`singleton`/`resolve` DSL).
- Framework use: NONE. No core subsystem registers or resolves through the container; db/queue/cache are
  wired through their own modules. This is uniform across all four and is the intended design.
- CLI / startup / request lifecycle: no involvement.
- Documentation: the CLAUDE.md "Container" section documents `reset()` as clear-all, which the DI-DEC-01
  decision must reconcile with Python's code.

## Breaking changes and migration

- DI-DEC-01 (reset semantics): whichever way it resolves is breaking for at least one language. If the
  consensus (clear-all) wins, Python's `reset()` changes to clear factories too and `reset_all()` is
  removed/aliased - document the one-line migration (call the new cache-only method if you relied on
  keeping factories). If Python's split wins, PHP/Ruby/Node `reset()` changes to cache-only and they gain
  `reset_all()` - a louder break for three languages, which is why the consensus is recommended.
- DI-DEC-02 / DI-DEC-03: additive (adding a global default, adding a raw-instance path) - non-breaking.
- The correctness fixes (DI-01, DI-FALSY-MEMO, DI-THREAD) only change broken behaviour; no correct
  program depends on a deadlock or a re-run singleton.
- No persistence exists, so there is no stored-format migration.

## Implementation backlog

Dependency-ordered:

1. Settle DI-DEC-01 (reset semantics) and write the first Container ADR capturing it plus DI-DEC-02 and
   DI-DEC-03.
2. Fix the correctness bugs with named regressions in the affected languages: DI-01 (Python), DI-FALSY-
   MEMO (Python/PHP/Ruby), DI-THREAD (Ruby).
3. Apply the surface decisions: reset unification (DI-DEC-01), global-default + class in all four
   (DI-DEC-02), uniform raw-instance path (DI-DEC-03), and the PHP message-case fix (DI-ERROR).
4. Author `container_contract.json` and a runner per language; flip owed to proven; add the CONTRACT-MAP
   row.

## Porting capsule

A clean-room implementation needs: a per-name registry of `{factory, singleton, instance}`; `register`
(transient) and `singleton` (lazy, memoized on key-presence so a falsy result still caches); `get` that
builds a transient every call, builds-and-memoizes a singleton once, and calls the factory with no
arguments (no container hand-in, no autowiring); `has`; `reset` with the ratified scope (per DI-DEC-01);
a raise on an unknown key ("service not registered: <name>"); and the ratified instantiation model (a
class plus a module-global default). Do not hold a lock across the factory call. This packet is
sufficient for a clean-room implementation once DI-DEC-01..03 are settled.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded.
- [x] Owner ambiguities decided and recorded.
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
