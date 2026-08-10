# Task: audit every feature, pick the best implementation, park a plan

> **2026-08-08 re-audit:** every previously audited row is being re-opened for
> adversarial contract-coverage review under `99-feature-reaudit.md`. Feature 27
> proved that zero-skip green suites can still omit contradictions between
> public operations. A prior "closed" label is now a baseline, not final proof.

Owner request (2026-07-28): "a feature by feature audit - each one checked -
decision made as to which is the best implemented - evaluated for performance,
SOLID, DRY, LOC, CC, parked for implementation as a plan. All 98 checked."

Follow-ups, same day: "stream them out as they come so I can check and make
decisions", "this will be only for planning - implementation will come after",
and "each plan will contain the pattern and methodology as well as tests to
write".

**PLANNING ONLY. No framework code changes in this pass.** The output is a
decision plus a parked plan per feature. Implementation is a separate pass, per
feature, after the owner has read the decision.

## Why this pass exists

ADR-0004 says the best implementation prevails and parity flows both ways. That
has been applied case by case, when a bug forced it. This pass applies it to
every feature on purpose, before a bug forces it.

The messenger audit (`messenger-contract.md`, done immediately before this) is
the evidence that the pass is worth running. One subsystem, four shapes, and the
framework that "Python is master" would have promoted turned out to hold the
worst mechanism plus a live copy of the bug being fixed. Nobody reported it. It
came out of reading four implementations side by side.

## Method, per feature

Six steps. Steps 1 to 3 are measurement, 4 is judgement, 5 and 6 are the parked
plan. A feature is not "checked" until all six are done.

1. **Locate.** Name the file(s) that implement the feature in each framework.
   Absent in one framework is a finding, not a blank: a feature counted as
   shipped everywhere with no file behind it is a parity gap.
2. **Measure.** `./feature-audit.py <name> --python ... --php ... --ruby ...
   --node ...` reports LOC, function count, total and average cyclomatic
   complexity, the worst single function, the maintainability index, and every
   offender. One engine (`tina4 metrics --json`, native, ADR-0002) across all
   four languages, so the numbers are comparable.
3. **Read.** Read all four implementations. No verdict is written from metrics
   alone: metrics find the fattest, never the most correct. This is the step that
   found the Python messenger's two-signatures-behind-one-name.
4. **Judge** on six axes, and say which one decided it:
   - **Correctness** (outranks everything below it: the leanest wrong answer
     loses to the fattest right one)
   - **Performance** (measured where a benchmark exists, stated as unmeasured
     where it does not; never guessed)
   - **SOLID** (single responsibility first; then: does the public surface let a
     caller depend on an abstraction rather than a concrete branch)
   - **DRY** (within the framework, and across the four)
   - **LOC** (less code is less to maintain; "maintainability means less code")
   - **CC** (per function, plus the worst single function)
5. **Write the pattern.** The canonical shape all four adopt, stated concretely
   enough to implement from: the signature, the return shape, the gate, the
   error behaviour. Name what is being dropped and why. Every pattern MUST carry
   a surface table (below).
6. **Write the tests.** Named positive/negative pairs, the same set in all four,
   each one required to FAIL before the fix. No mocks: real dependency or a pure
   function.

Then park it. Nothing is implemented in this pass.

## The surface table (mandatory in every plan)

Owner rule, 2026-07-28: "all the frameworks will contain the same method names
(framework specific naming - snake case, camel case) and the same outcomes and
same optimizations where possible."

So every per-feature pattern carries a table with one row per public concept and
one column per framework, giving the exact name a caller types:

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| load | `load_env(root=None)` | `DotEnv::loadEnv($root = null)` | `Tina4.load_env(root = nil)` | `loadEnv(root?)` |

Three rules the table enforces, and each is a defect when broken:

1. **Same concept, same name, idiomatic casing.** snake_case in Python and Ruby,
   camelCase in PHP and Node, PascalCase classes everywhere. A concept that is
   `capture` in one framework and `store` in another is a defect even when both
   work. No alias methods to paper over a mismatch - rename the primary.
2. **Same arguments in the same order, and the same outcome for the same input.**
   Feature 1 found `loadEnv($file)` in PHP against `load_env(dir)` in Ruby, so the
   obvious cross-framework call throws. The audit treats an argument-shape
   difference as equal in weight to a wrong return value.
3. **Same optimizations where the runtime allows.** If one framework memoises a
   compiled pattern, caches a lookup, or hoists work out of a per-row loop, the
   others do too, unless the runtime makes it impossible - and then the plan says
   why in one line. An optimization present in one framework and absent in three
   is a performance parity gap, and it is recorded as such rather than left as
   folklore about which language is fast.

Where a concept genuinely cannot carry the same name (a language keyword clash,
`delete` in Node being the classic), the plan states the substitute and the reason
in the table itself.

## The portability spec (mandatory in every plan, from 2026-08-05)

Owner rule: while the audit runs, every feature plan must also be the SPEC you
would hand someone adding Tina4 to a language it does not have yet.

This is not extra work bolted onto the audit. A spec complete enough to build
Tina4 in another language is, by construction, a spec that pins the contract
the existing four must already share - and pinning that contract is the audit's
whole job. Everything the four keep drifting on (argument order, env precedence,
stored key shapes, what counts as an error) is exactly what a new implementer
would have to ask about, so the questions they would ask ARE the audit's
checklist. If a plan cannot answer them, the plan does not yet describe a
contract; it describes four accidents that currently agree.

**The surface table is not enough on its own.** It has one column per framework,
so it is DESCRIPTIVE - it records what these four happen to call a thing. It
cannot GENERATE another language's spelling, and it says nothing about stored bytes,
ordering, or failure modes. It stays mandatory; the six parts below sit
alongside it.

### 1. Concept and naming RULE

The canonical concept name, plus the derivation rule that produces a spelling in
any language - not just the four columns. State the rule, then let the table
show it applied:

    concept: get_token
    rule:    snake_case in snake_case languages, camelCase in camelCase
             languages, PascalCase for the type. Verb first, noun second.
             Keyword clashes take the documented substitute (Node `delete` ->
             `del`) and the plan names the clash.

Another language derives its own name from the rule. It never copies Python's.

### 2. Behaviour, stated without reference to any language

Inputs to outputs for every case INCLUDING the failure cases: what raises, what
returns empty, what is a silent no-op and why that is correct. Ordering where
order is observable. Defaults for every optional argument.

This is the part that reads as tedious and is not. "A missing key returns null,
NOT an error" is one line here and was a cross-framework defect twice.

### 3. The persisted and wire contract

The exact bytes. Stored key names and their prefixes, JSON field names and
types, SQL column names and types, HTTP headers and status codes, queue message
envelopes, cookie attributes.

THIS is what makes another implementation interoperable rather than merely
similar. A Go implementation must be able to read a session written by the PHP
one, resume a queue the Python one filled, and answer a health check the same
monitor scrapes. Nothing else in the plan establishes that.

Where a fixture already carries the shape (`fixtures/*.json`), reference it
rather than restating it.

### 4. Configuration and PRECEDENCE

Every env var the feature reads, its default, and - when more than one can
supply the same value - the order they win in.

Precedence is the part that gets skipped and the part that bites. MEASURED
2026-08-05: a test set the LOWEST-precedence name in a three-name chain while
the canonical name was set ambiently, so its own setenv never took effect; and
separate probes read redis db 0 while the handler honoured
TINA4_SESSION_REDIS_DB. Both read as framework defects. Both were unstated
precedence.

### 5. Conformance cases as DATA, not prose

The fixtures currently carry `cases` as a list of NAMES. A name is not
executable. A new implementation cannot run "session ttl env var expires the
record on every backend" - it can only run inputs and compare outputs.

Each case grows an input and an expected result, so the fixture becomes the
answer key another language's runner executes directly:

    {
      "name": "a missing key reads as empty, not an error",
      "given": { "backend": "redis", "session_id": "absent-1" },
      "when":  "read",
      "then":  { "returns": {}, "raises": null }
    }

The existing four runners keep working; they gain the ability to assert against
the same data instead of each hand-rolling the case.

### 6. Allowed divergence, with the reason

What a runtime may legitimately do differently, and why, in one line each. PHP
is single-process; Ruby has Puma; Node has the cluster module; Python has
asyncio. A plan that pretends these are identical produces a spec nobody can
implement, and a plan that leaves the difference unstated produces four
accidents again.

Anything NOT listed here is a defect when it differs. That is the point of
writing it down.

### The test of a finished plan

Hand it to someone fluent in a language Tina4 does not support, with no access
to the four repos. If they can implement the feature and pass the fixture, the
plan is done. If they have to read tina4-python to find out what actually
happens, it is not - and whatever they had to look up is precisely the thing the
four will drift on next.

## The spec IS the drift check

Owner, 2026-08-05: "we can use the plan spec to check our drift."

That is the point of writing the contract as DATA rather than prose, and it
changes what a fixture is FOR. Today drift is found two ways, both bad: a human
reads four implementations side by side (slow, and the reason 66 features are
still unaudited), or production finds it. A fixture whose cases carry inputs and
expected outputs is executed by all four runners, so a divergence stops being an
archaeology exercise and becomes a RED TEST with a name.

The loop, once a feature's cases are data:

    spec (fixture) -> four runners execute it -> divergence IS a failing case

Nothing new has to be built to start. All four already consume
`fixtures/*.json`; what they consume is a list of case NAMES, and each framework
then hand-rolls the case. That hand-rolling is exactly where they diverge - the
write-path fixture is the proof: one shared answer key, four independently
written runners, four different case counts (python 17, ruby 16, php 15,
node 14), and the ONE case no runner executed
(`a_string_filter_with_params_works_the_same_as_a_hash_filter`) was the case
that would have caught the Node truncate bug.

So the upgrade is small and the payoff compounds:

- **A drifted framework fails a named case** instead of passing four green
  suites that quietly disagree. Every defect measured on 2026-08-05 would have
  been caught this way at the moment it was introduced.
- **`status` becomes machine-verifiable.** Each invariant already records
  "PROVEN in all four" as PROSE, asserted by a human. With executable cases the
  runner asserts it, and a stale PROVEN is a red build rather than a sentence
  nobody rechecked. This document drifted four times in exactly that way.
- **Another language gets a pass/fail gate on day one.** The same fixture that
  checks the four IS the acceptance test for that implementation, so the question "is the
  Go port done" has an answer that is not an opinion.

The four-way check and the portability spec are therefore the SAME artefact
viewed twice: run it against the frameworks you have and it reports drift; hand
it to a language you do not have and it reports readiness.

## Applying the portability spec WITHOUT wasting energy

Owner rule, 2026-08-05: apply this to the audited AND the unaudited features, but
do not burn effort where it buys nothing.

MEASURED 2026-08-05, so the gap is known rather than guessed: **26 feature plans
exist, 15 carry a surface table, and exactly ONE references a fixture.** Six
fixtures exist (`cache`, `dispatch`, `docstore`, `health`, `queue`, `session`)
and their `cases` are NAMES, not executable data.

Retrofitting all six parts onto all 98 features is the wrong move. Most features
do not need most of the spec, and a spec written where nothing consumes it is
documentation nobody reads and everybody has to maintain.

### The tier rule (decidable, not a taste call)

**Correction, 2026-08-05, owner: "the 22 tier C features are important no matter
how you feel."** He is right, and the first version of this rule was wrong in a
specific way: it conflated IMPORTANCE with SPECIFICATION COST. Those are
orthogonal. A tier is a statement about how much spec a feature needs to be
portable, NEVER about how much the feature matters, and nothing in a lower tier
is optional, deferred, or less carefully audited.

The rule was also too NARROW. Asking only "does it persist" misses that a
PUBLIC API SURFACE A DEVELOPER WRITES AGAINST is equally a contract: if
`validate()` returns a list in one framework and a bool in another, user code
breaks just as hard as a mis-keyed session. The proof is already in this
document - feature 1, the `.env` loader, was classified by the first draft of
this rule as a local utility. It carried FOUR defects, including quote
characters left inside a credential handed to a driver, and a `loadEnv($file)`
against `load_env(dir)` argument-shape split. Two paragraphs would have been
indefensible.

Ask TWO questions, not one:

  1. does anything outside this process consume what the feature produces, and
     does it survive the process? (persisted state, wire bytes)
  2. does a DEVELOPER write code against its exact shape? (public API surface,
     argument order, return type, error behaviour)

A YES to either puts the feature above tier C.

| answer | tier | what the plan owes |
| --- | --- | --- |
| PERSISTS or crosses a process boundary (a stored key, a row, a message, a document, a token another service validates, JSON another program parses) | **A** | all six parts, plus fixture cases as executable data |
| TRANSIENT bytes, OR a public API surface developers write against (an HTTP response, a rendered page, a log line, a header, a validator result, an assertion API) | **B** | parts 1, 2, 4, 6; part 3 for any bytes or shapes that leave the feature |
| Genuinely internal - no caller outside the framework depends on its shape | **C** | parts 1 and 2 |

**Re-classified after the correction.** The keyword pass put these in C; every
one of them fails question 1 or 2 and moves up:

| feature | moves to | because |
| --- | --- | --- |
| 21 `get_next_id` | A | writes the `tina4_sequences` table, race-critical across processes |
| 63 `.env` loader + env helpers | A | reads files, has precedence, and is audit feature 1 with four measured defects |
| 66 CSRF protection | A | a token that crosses a request boundary, and a security control |
| 86 Self-describing CLI manifest | A | emits JSON another program parses |
| 88 Firebird driver | A | a database driver |
| 22 SQL translator | B | emits SQL a real engine parses |
| 27 Validator | B | its result shape is written against by user code |
| 58 Inline testing framework | B | a public assertion API |
| 62 DI container | B | a public API surface |
| 95 Code generators | B | emit code that must compile in each framework |

Tier C is what genuinely remains: the dev toolbar, the gallery, the CSS bundle,
the broken-file tracker, the REPL, the docs search index. Internal or
developer-facing surfaces with no cross-process contract and no shape user code
binds to. They are still audited to the same standard on correctness - they
simply need less written down to be PORTABLE.

Tier A is where another language BREAKS, and it is where these four already
drift: every cross-framework defect measured on 2026-08-05 was tier A (session
key databases, mongo database selection, queue vhost naming, paginate envelope
counts). Tier C is where another language can be written freely and correctly
from two paragraphs - HtmlElement, Testing, FakeData, the DI container, Events.

Mis-tiering DOWN is the dangerous error, and the first draft of this rule made it
five times over. Mis-tiering up costs some writing; mis-tiering down ships a
contract nobody wrote and four implementations that agree by luck.

### Order of work

1. **The six existing fixtures first.** They are already consumed by all four
   runners, so upgrading `cases` from names to executable data (part 5) makes
   the answer key runnable by another implementation with no new machinery. This
   is the single highest-leverage change in the whole programme.
2. **The remaining tier-A features**, whether audited or not. An AUDITED tier-A
   feature with no wire contract written down is not actually closed - the audit
   verified behaviour and left the interoperability contract implicit. Feature 18
   is the worked example: closed on key-set enumeration, then found to have four
   different `to_paginate` contracts underneath.
3. **Tier B**, as each feature comes up in the walk. No separate pass.
4. **Tier C**, inline, in the audit pass itself. Never a separate pass.

### What this changes for the already-audited 32

Nothing is re-audited. Each closed row gets ONE question asked of it: what tier
is it, and does its plan carry that tier's parts? If yes, the row is genuinely
done. If no, the row is reopened for the missing parts ONLY - not for a fresh
verdict.

That is the cheapest possible reconciliation, and it is also the honest one: a
tier-A row closed without a wire contract was closed early, and today has three
separate proofs that closing early is how the drift got in.

## Language-specific issues: when the runtime does the heavy lifting

Owner question, 2026-07-28: "How do we deal with language specific issues -
language may heavy lift certain things."

It happens constantly, and it cuts both ways: one runtime hands a framework
something free that another must build by hand. Handled wrongly it produces two
opposite mistakes - demanding four identical implementations of something only one
runtime supports, or waving "it's a language thing" over drift that has no runtime
cause at all. The messenger row is the cautionary case: Python's instance-method
swap looked like Python being Pythonic and was simply a bad choice, since a branch
inside `send()` was available the whole time.

**The governing rule: outcome parity is non-negotiable, mechanism parity is not
required.** Two callers in two languages must observe the same result for the same
input. How the framework gets there is the runtime's business.

Every divergence sorts into exactly one of four categories, and the plan must say
which:

**1. Runtime gift.** The language or stdlib already provides it, so the framework
uses it instead of reimplementing. Node's `node:sqlite`, Python's stdlib `sqlite3`,
Ruby's native keyword arguments, PHP's `PDO`. Expected effect: that framework has
*less* code for the same outcome. Correct, and a LOC win that must not be read as
the others being bloated. Rule: **use the gift, never reimplement it for symmetry.**

**2. Runtime tax.** The language lacks it, so the framework hand-rolls it. PHP's
silent PDO fallback family (feature 4) is 163 extra lines that exist because a PHP
install may ship `ext-sqlite3` or `pdo_sqlite` and the framework cannot know
which; Python, Node and Ruby each have exactly one canonical binding and need
nothing. Expected effect: that framework has *more* code for the same outcome.
Rule: **record the tax and its reason in the plan**, so a later reader does not
"simplify" it back into a bug. This is the one place a metric outlier is correct.

**3. Runtime-idiomatic difference.** Same outcome, different shape. Keyword
arguments versus positional. `async`/`await` everywhere versus sync-with-async-server.
A long-running process versus PHP's shared-nothing request model. Rule: **the
surface table absorbs the naming and casing, and the contract is stated in terms
of outcome, never mechanism.** A contract that says "call `capture()` with
keywords" is unportable; one that says "the captured message carries `text`" is not.

**4. Genuine drift.** No runtime reason. Somebody made a different choice, or
nobody made a choice. This is the only category that is a defect, and it is the
one the audit exists to find.

**The decisive test, applied to every claimed language-specific issue:**

> Could this framework produce the canonical outcome without the divergence, using
> what its runtime already offers?

If **yes**, it is category 4 - drift - and it gets fixed, regardless of how
idiomatic it looks. Python could have branched inside `send()`. Ruby could have
stripped an `export ` prefix. Neither needed anything the runtime withheld.

If **no**, it is DEFER, and the plan must name the specific runtime limitation in
one line that a reader can check. "Ruby has native keyword arguments and PHP does
not" is checkable. "It's more idiomatic" is not, and is rejected.

**A runtime gift can still set the standard.** Where one language's heavy lifting
produces the best *outcome*, that outcome becomes canonical for all four even
though the mechanism cannot be copied - ADR-0004's "parity flows from semantics,
not implementation". Ruby's keyword arguments make the #42 argument-order bug
unrepresentable; PHP and Node cannot copy keyword arguments, so they adopt the
outcome (no public positional `capture()` to mis-order) by a different means.

**Performance is judged inside the language, not across languages.** Ruby will not
match Node's template throughput and it is not a defect that it does not. The
performance question is always "is Tina4 competitive against the other frameworks
in ITS OWN language", which is what the Carbonah and competitor benchmarks measure.
What IS a defect: an optimization present in one framework and absent in another
where the runtime permits it - a memoised pattern, a hoisted per-row conversion, a
cached lookup. Those are recorded as performance parity gaps rather than left as
folklore about which language is fast.

## Verdict vocabulary

| Verdict | Meaning |
| --- | --- |
| **UNIFORM** | Four implementations already agree on behaviour and surface. Nothing to do; the row is closed. |
| **PROMOTE x** | One framework is clearly best. The other three adopt its shape. |
| **SYNTHESISE** | No single framework is best. Take the pattern from one and specific pieces from others (the messenger case). |
| **GAP** | Missing or non-functional in at least one framework. Build it to the agreed pattern. |
| **DEFER** | Genuinely language-specific by design, with the reason recorded. Not a gap. |
| **REDESIGN** | All four are wrong in the same direction, and the audit has learned enough to design better than any of them. Added 2026-07-30 from feature 3: the other five verdicts all PICK from what exists, so none of them can express this, and the row kept producing answers that had to be corrected (PROMOTE php, then SYNTHESISE) until the option existed. Use it sparingly and only with the learning written down. |

A verdict of UNIFORM still requires steps 1 to 3. "Looks the same" is not a
measurement, and 01-FEATURE-MATRIX.md has claimed 100% parity since 2026-04-03
while the messenger held four different shapes.

## On the count

The published number is unreliable and this pass will settle it. Today:
`01-FEATURE-MATRIX.md` enumerates **93** backend rows and claims 100% parity;
the four framework CLAUDE.md files claim **98**; `feature-recount.md` (2026-07-23)
found four conflicting published numbers and concluded the true count is HIGHER
than any of them, because a large amount of shipped 3.13.x work is in none of the
enumerations.

So the audit list is the union: the 93 matrix rows plus everything shipped since
and never enumerated (realtime collab, MCP server, DocStore, Metrics, Validator,
TestClient, i18n module, unified cache backends, static-asset revalidation,
per-route WebSocket auth, queue visibility timeout, the live API index, and the
CLI's own features). Each row is audited once. The final row count becomes the
published number, per the owner decision recorded in `feature-recount.md`: one
canonical union table with a column per framework, where every row not present in
all four is a parity gap.

Rows are audited in matrix order because that order runs foundation-first, and a
verdict on the router constrains the verdict on middleware.

## Per-feature template

Every audited feature is recorded in this shape.

```markdown
### N. Feature name

**Files.** python: ... | php: ... | ruby: ... | node: ...

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |

**What differs.** The behavioural deltas, read from source. Not the metrics.

**Verdict: PROMOTE python** (or UNIFORM / SYNTHESISE / GAP / DEFER)
Decided on: correctness. One sentence saying which axis was decisive and why.

**Pattern.** The canonical shape, concretely: signature, return, gate, errors.

**Methodology.** The ordered steps to carry it across, per framework.

**Tests to write.** Named positive/negative pairs, identical in all four.

**Parked as.** <plan file, or "this document, section N">
```

## Progress

Streamed in batches. Each batch is reported to the owner as it lands, so a
decision can be challenged before the next batch builds on it.

One plan file per feature under `features/`. Rhythm from 2026-07-28: one feature
reviewed and closed at a time, not batched.

| # | feature | verdict | decided on | plan | state |
| --- | --- | --- | --- | --- | --- |
| 55 | Messenger (historical audit pilot) | SYNTHESISE | correctness | `features/055-email-messenger.md` | **SHIPPED all 4**, 0 open under the original pilot; queued for the adversarial re-audit in numeric order (py `9075423`, php `721aba94`, node `c96ba9f`, ruby `33b25de`) |
| 1 | DotEnv parser | SYNTHESISE | correctness | `features/001-dotenv.md` | **CONTRACT COMPLETE 2026-08-09; implementation pending until the full audit closes.** Owner decisions settle bootstrap/template, hard transactional failures, precedence, native scalar/structured returns, constant/environment references, dependency-graph resolution, portable numeric grammar/ranges, multiline structures, duplicate/cycle/depth rules, case sensitivity and reset. Exact named conformance cases and the ten-part porting capsule are in the plan; the prior shipped narrative remains only as historical evidence. |
| 2 | Structured logger | SYNTHESISE | correctness | `features/002-structured-logger.md` | **CONTRACT COMPLETE 2026-08-09; implementation pending until the full audit closes.** The 25-rule decision register and ten-part normative plan settle configuration lifecycle, format, ANSI, sinks, global levels, file layout, bounded concurrent rotation, oversized records, native normalization, request locality, failure policy, public API and process lifecycle. The shared fixture contains 59 unique cases across 8 owed invariant groups (SHA-1 `1aca82f6e0309f17eb11313334abacf2184509c8`). Focused exact-HEAD lab baseline remains Python 82 passed, PHP 91 tests/217 assertions, Ruby 75 examples and Node 85 passed. Those 333 checks are compatibility evidence, not 3.14 conformance. No framework code changed during the audit. |
| 3 | DB adapter interface | **REDESIGN, superseded execution boundary in ADR-0044** | correctness + SOLID + measured batching | `features/003-database-adapter-interface.md` | **CONTRACT COMPLETE 2026-08-10; implementation pending.** The old shared fixture excluded `executeMany` and `fetchOne` while Python, PHP and Node declared both; its runners passed by checking the JSON against itself. Re-audit makes both required adapter primitives and public facade methods, removes duplicate adapter diagnostics, requires aggregate `DatabaseResult`, one-connection atomic batches and a native async Node contract. Exact-HEAD lab baseline is green, but that is compatibility evidence. New 38-case fixture has 8 owed invariant groups. |
| 4 | SQLite adapter + write path | **GAP** (P1, was broken in 4 of 4) | correctness | `features/004-sqlite-adapter.md` | **EFFECTIVELY CLOSED 2026-07-31; 1 deferred.** (a) PHP `getColumns()` key: re-measured, the drift the plan described is GONE - PHP emits `primaryKey` in all 12 places, no consumer reads `'primary'`, and that matches the contract's idiomatic-casing rule. Plan was stale, not the code; pinned with a test. (b) ORM single-key: **FIXED all 4** (py `deefe50`, node `a253006`, ruby `12002c5`, php `29279b40`). Worse than parked: the INSERT-vs-UPDATE probe tested only the FIRST key column, so saving (acme,a2) was decided an UPDATE and OVERWROTE (acme,a1) - data loss on an ordinary insert. Also update/delete truncated the key, and createTable emitted one inline PRIMARY KEY per column (invalid DDL). PHP needed an ADDITIVE `$primaryKeys` array: widening `$primaryKey` to string|array fatals every existing model (PHP demands identical redeclared types). (c) row cap: **deferred to feature 18**, unchanged. |
| 5 | DATABASE_URL parser | PROMOTE php | SOLID | `features/005-database-url-parser.md` | **SHIPPED all 4** (2026-07-30): php 12/17->17/17, node 0/17->17/17, python + ruby had no parser at all -> 17/17. D3 settled on live Firebird. |
| 6 | Router + dispatch | SYNTHESISE | SOLID | `features/006-router-and-dispatch.md` | **closed, 1 OPEN decision filed.** Stage lists are data + a contract gate in all four; 8 invariants in `fixtures/dispatch_contract.json`, 108 (case x framework) pairs checked. Route precedence (does a specific route beat a catch-all?) is **ADR-0015, ACCEPTED: no change**. The reported bug (a Ruby app catch-all shadowing `/__health`, so a container health check got the app's page) is FIXED in `tina4-ruby 0ad2de1`. Citations verified against primary docs: Django, Rails and Express all resolve by registration order, first match wins; ASP.NET Core is the lone specificity outlier and gets there by a different architecture (all endpoints ranked, ties throw) that we are not adopting. The prior belief that specificity-wins is the norm was WRONG. One follow-on scheduled: our order is filesystem-derived rather than written, so make it VISIBLE (startup warning on a shadowing catch-all, resolution order in `tina4 routes`). |
| 13 | ORM base class | PROMOTE ruby (structure) | LOC/CC | `features/013-orm-base-class.md` | closed |
| 14 | Soft delete | **GAP** (broken in 3 of 4) | correctness | `features/014-soft-delete.md` | closed, 1 outstanding |
| 15 | Relationships + eager load | PROVISIONAL PROMOTE python/ruby | correctness | `features/015-relationships.md` | **closed, 0 open** (Node settled 2026-07-30: serialize-only, no accessor; `hasMany` truncates at 100 in 3 of 4) |
| 16 | Scopes | SYNTHESISE | correctness | `features/016-scopes.md` | closed |
| 17 | Field mapping | PROMOTE node (mechanism) | SOLID | `features/017-field-mapping.md` | closed, decided (ADR-0008) |
| 18 | Paginated results | **PROMOTE php** (was SYNTHESISE) | correctness | `features/018-paginated-results.md` | **RE-OPENED 2026-08-05. The row said "closed, 0 open" while the plan said "Parked. Not implemented." - the row was closed on ENUMERATING the key sets, which unblocked the plan rather than implementing it, and nobody checked whether the envelope tells the truth.** MEASURED, one query against a real 250-row table (`limit=20 offset=40`, page 3 of 13): **only PHP is correct on all five values.** Python and Node report `page=1` because they default the page and ignore the offset. Ruby and Node report `total=20` (rows returned) instead of 250, because **`.count` means the TRUE TOTAL from a COUNT probe in Python/PHP and ROWS RETURNED in Ruby/Node** - so the envelope's `total` is 250 in half the family and 20 in the other half, for one query. Ruby returns **ZERO records** for that valid page-3 fetch and Node returns 10 of the 20, because both re-slice by the ABSOLUTE offset against an array that is already just that page. This is the exact failure the plan already names (the envelope launders a truncation into a fact) shipping in three of four frameworks. Settled pattern: `toPaginate()` takes NO arguments in all four and derives every field from the query that ran; an argument RAISES rather than being silently swallowed, which is how PHP hid the divergence. The deep half is making `.count` mean the true total in Ruby and Node - it reaches into the adapters and is breaking. Key sets still divergent (py 10, php 10, ruby 12, node 13). |
| 19 | Result / ORM caching | GAP (ruby) + SYNTHESISE | correctness | `features/019-orm-result-caching.md` | closed |
| 20 | Input validation | **PROMOTE node** + GAP (php) + P1 (python) | correctness | `features/020-input-validation.md` | **closed, 0 open; VERDICT REVISED 2026-07-30** - PHP's `validate()` is `return []`, so the parked SYNTHESISE leaned on an implementation that does not exist |
| 28-31 | Frond engine (lexer/parser/compiler/runtime) | PROMOTE python (structure) | SOLID | `features/028-031-frond-engine.md` | closed as one row |
| 32 | Frond filters | SYNTHESISE | template portability | `features/032-frond-filters.md` | closed |
| 37 | Auto-escaping | UNIFORM (html) + GAP (js/css/url) | correctness | `features/037-auto-escaping.md` | closed, 1 owner call |
| 38 | Sandboxing | PROMOTE php (**P1**) + GAP (tags) | correctness | `features/038-sandboxing.md` | **SHIPPED all 4**, 0 open (both owner calls answered) |
| 7 | Middleware pipeline | SYNTHESISE | correctness | `features/007-middleware-pipeline.md` | **CLOSED 2026-07-31, merged to v3.** ADR-0014 settles the return-value contract: a returned Response is the PRIMARY short-circuit, `>= 400` state is a documented LEGACY path (it cannot express a 302, so an auth middleware redirecting to /login had its handler run anyway). Fixed: per-route CLASS middleware ran NEITHER phase in Ruby (NoMethodError -> 500) or Node (not in the type at all), and PHP dropped its after phase - three of four silently discarded middleware a developer explicitly attached. Ruby let a 403 through: the status check sat INSIDE the "did it return a 2-array" branch, so a hook setting 403 and returning nil let the handler run. PHP's `get_class_methods()` docblock claimed parent-first; measured own-first on 8.5.7 - wrong the whole time. Node did not reorder inherited hooks, it LOST them. Base -> derived discovery in all four. |
| 8 | Health check endpoint | SYNTHESISE | wire contract | `features/008-health-check.md` | **CLOSED 2026-07-31, merged to v3.** ADR-0016: liveness is process-only, readiness is separate and SPECIFIED not built. The finding: Python's `_write_broken()` runs on the REQUEST path, so ONE unhandled route exception 503'd `/health` for the life of the sentinel file, and nothing cleared it at boot - a guaranteed CrashLoopBackOff from a single bad request that never self-heals, and a restart cannot fix a broken route file. PHP dropped `/health` entirely when `TINA4_HEALTH_PATH` was set; Ruby's `register!` guard called `find_route` with swapped arguments, so a catch-all suppressed registration. Body is now four identical keys in all four. NOT built: Dockerfile HEALTHCHECK (Docker daemon down; refused to ship unverified because Alpine/distroless images lack curl). |
| 9 | Graceful shutdown | SYNTHESISE | correctness | `features/009-graceful-shutdown.md` | **CLOSED 2026-07-31, merged to v3.** ADR-0017. Worst defect of the four audits: a PHP `App` embedded in a long-running CLI worker was UNKILLABLE - the constructor installed a handler that suppressed SIGTERM's default terminate while `pcntl_signal_dispatch()` was never called, so `kill` and `docker stop` were no-ops. Node had no signal handler at all on plain `startServer()`, and registering ANY `background()` task made it worse: the handler replaced Node's default disposition and never exited, so every rolling deploy burned the full grace period and died by SIGKILL. Feature 9 did NOT apply in production for Python or Ruby (uvicorn/Puma own the socket); the contract now splits mechanism from outcome. Exit code follows the socket owner - the one clause where the outcome genuinely is not shared. |
| 10 | CORS middleware | PROMOTE php | **security** | `features/010-cors-middleware.md` | **CLOSED 2026-07-31, merged to v3.** ADR-0018: deny by default (breaking, owner-approved). Ruby's `apply_headers` was DEAD CODE - nothing in the dispatch path called it, so the preflight said yes and the real request came back with no `Access-Control-Allow-Origin`. Cross-origin browser access to a Tina4 Ruby app did not work in ANY configuration, and the successful preflight made it look like a client bug. Ruby also emitted `ACAO: *` with `ACAC: true`, which the Fetch CORS check forbids. Node's default `cors()` never read `TINA4_CORS_CREDENTIALS` - a documented env var doing nothing in the default pipeline. `Vary: Origin` added (origin only - MEASURED that our preflights do not vary on ACRM/ACRH, so copying Spring's three fields would have told caches something untrue). |
| 11-12, 79 | Rate limiter / response types / route groups | SYNTHESISE | **security** | ADR-0019 | **CLOSED 2026-08-01, merged to v3.** ADR-0019: the limiter keys on the SOCKET PEER and `TINA4_TRUSTED_PROXIES` defaults to EMPTY - trust nothing (breaking; a proxied deploy must set it or every client resolves to the proxy IP and shares one bucket). Rack/Rails default to the private ranges and ASP.NET Core to loopback; we fail closed instead. The other two decisions are forced fixes, not forks: Python had an `elif has_middleware: auth_required = False` branch in `Router.add` that SILENTLY OPENED THE AUTH GATE on any route carrying middleware, and PHP/Ruby discarded an explicitly-set status in `json`/`html`/`text`/`xml`, so PHP answered **200 to requests its own rate limiter was blocking**. |
| 41-42 | JWT + session handling | SYNTHESISE | **security** | ADR-0021 | **CLOSED 2026-08-01, merged to v3.** ADR-0021: a session id is OPAQUE - never a path component - and an unverified credential is not an auth result. Closed a real CWE-22: the id arrives in an attacker-controlled cookie and became a filename. The obvious fix was worse than the bug - a lossy `gsub(/[^a-zA-Z0-9_-]/, "")` collapsed `a/b` and `ab` onto ONE file, so two users shared one session record. Now sha256(id). BREAKING and backend-dependent: file and memcached sessions are invalidated, redis/valkey/mongo/database SURVIVE (their keys are the raw id). Also: `start()` refuses to adopt an id the store never issued (session fixation), the api-key result renamed `{api_key: true}` -> `{_auth: "api_key"}`, Python's unverified Basic branch deleted, `>=` on `exp` per RFC 7519 s4.1.4, malformed exp/nbf rejected, constant-time api-key compare. |
| 43 | Cache backends | CONFORMANCE (not a fork) | **security** | ADR-0020 | **CLOSED 2026-08-01, merged to v3.** RFC 9111 s3.5: a shared cache MUST NOT store a response to a request carrying `Authorization`. MEASURED cross-user leak - PHP served one user's private balance to a DIFFERENT user's token with `X-Cache: HIT`. Python and Ruby were not exploitable only because their middleware did not function at all (feature 7). BREAKING: authenticated GETs are no longer stored; opt back in per route with `Cache-Control: public`. **Filed as an ADR but it is not a decision** - RFC 9111 answers it with MUST NOTs and Varnish, nginx proxy_cache and Rack::Cache all agree; three independent reviews said reclassify it as conformance. Kept for its migration note. |
| 48 | Queue backends | SYNTHESISE | correctness | ADR-0022 | **CLOSED 2026-08-01, merged to v3. The caveat below is RESOLVED as of 2026-08-05:** the four-way claim is now true. PHP carries 12 queue commits and Ruby 19 since 2026-07-30 (Python 16, Node 17), and all four carry both the failure-lifecycle and the `close()` suites (`QueueFailureLifecycleTest.php` / `queue_failure_lifecycle_spec.rb` / `test_queue_failure_lifecycle.py` / `queueFailureLifecycle.test.ts`, plus the matching close-releases-backend files). Ruby's `Job#fail` never reaching the broker was fixed on the way. The caveat as originally written follows, kept because it records how a four-way promise came to be stated from a two-framework branch. ADR-0022: the queue promises at-least-once and each backend keeps it the way its protocol allows (AMQP 0-9-1 s1.8.3.12/13 ack-and-republish; Kafka offset-commit). Node's RabbitMQ and Kafka backends now THROW at construction - a HOLDING POSITION, not the settled design, pending the persistent-connection rewrite; an app with `backend: "rabbitmq"` no longer starts. **The caveat: the branch carried 1 commit in tina4-python and 1 in tina4-nodejs and ZERO in tina4-php and tina4-ruby**, while the ADR states the promise across all four and its own trigger records "PHP Kafka had no ack at all". The four-way claim is NOT yet true. |
| 27 | Migrations (run + create + rollback) | **SYNTHESISE (provisional)** | correctness | `features/027-migrations.md` | **AUDIT IN PROGRESS 2026-08-08. LAB BASELINE VERIFIED:** Python 93/0 skipped, PHP 105 tests + 331 assertions/0 skipped, Ruby 94/0 pending, Node 272 passed; exact v3 HEADs recorded in the plan. Live matrix correction: 21-26 are retired adapter rows folded into group 4, not migration features. Confirmed: Node creates `.ts` migrations its runner never discovers; Python/Node file/status surfaces omit native-code migrations; PHP/Ruby/Node can remove tracking when no down implementation exists; Node also removes tracking after down SQL fails; public result shapes differ four ways. Shared fixture + implementation still owed. |
| 33-36, 39-40, 44-46, 49-78, 80-98 | remainder | - | - | - | **not started.** Includes Frond tags/tests/functions/extensibility (33-36), template + fragment caching (39-40), data/ORM remainder (44-46), and the service/tooling features. Base rate so far: **every audited feature found something broken and invisible** - none came back clean - so these are unexamined, not "probably fine". Feature 47 Swagger is already Layer 2 and must not be counted here. |

### Work done OUTSIDE the numbered walk (2026-07-30/31)

Real bugs found while fixing something else. None of it advances the walk, and
none of it had a numbered row, which is itself the finding: the matrix cannot
see two of its four variant groups.

| area | what | state |
| --- | --- | --- |
| Sessions | **memcached was missing as a SESSION backend in all 4** (it had been a CACHE backend since v3). Added as feature **42.6**; sessions restructured into a GROUP (42.1-42.6) so a new backend stops renumbering the matrix. | SHIPPED all 4 |
| Sessions | **The sync transport spawned a `node -e` child PER COMMAND** (Node): spawn p50 41ms / p99 487ms plus a fresh TCP connection, and the tail tripped the child's own deadline. That is what made sessionHandlers flaky - the SET timed out for the caller while still LANDING on the server, so the next GET honestly saw nothing. Replaced with one persistent connection behind a worker + Atomics. Redis/Valkey/memcached p50 80ms -> 10.5ms; MongoDB (driver load per command too) p50 230ms -> 11.5ms. Flake: 2-3 failures in 6 runs -> 0 in 20. | SHIPPED (Node only; the other 3 have native sync sockets and never had this) |
| Cache | **memcached `size` read the GLOBAL `curr_items`**, counting every other tenant's keys - the only leaky backend of seven. And **`clear()` sent `flush_all`, wiping the whole shared server** (Node's was the mirror bug: a no-op that cleared nothing, with a comment claiming a parity that was false in both directions). Both fixed by tracking our own keys + TTLs. | SHIPPED all 4 |
| Write path | **`db.truncate()` was broken outright in Node on PostgreSQL, MySQL, MSSQL and Firebird.** Those four adapters accepted only an OBJECT filter, and truncate passes the string `"1 = 1"` - so `Object.keys("1 = 1")` yielded the string indices `["0","1",...]` and the statement went out as `WHERE "0" = $1 AND "1" = $2 ...` (PostgreSQL: `column "0" does not exist`). The same hole broke the contract's documented `db.delete(t, "id = ?", [1])` form on all four. sqlite/mongodb/odbc already carried the string branch. Ruby/Python/PHP are immune - their facades normalise the filter before it reaches a driver. | SHIPPED (node `93fd73b`) |
| Write path | **Primary-key introspection returned NOTHING on PostgreSQL and MSSQL** in Ruby and Node - `columns()` hardcoded `primary_key: false` on both engines in both frameworks. Feature 4's filterless-write guard reads it, so `update(table, data)` keyed on the PK in the data RAISED against every table on those engines. Python and PHP were already correct (INFORMATION_SCHEMA LEFT JOIN); ported from the Python master, and the subquery yields every column of the key so a COMPOSITE key reports true on each. | SHIPPED (ruby `3912b90`, node `93fd73b`) |
| Write path | **`affected_rows` reported 0 for a write that really changed rows** - Ruby's PostgreSQL and MSSQL drivers exposed no `affected_rows` at all, so `write_affected` fell through to its default of 0, indistinguishable from "matched nothing". MySQL computed the exact count but only INSIDE its INSERT branch. PostgreSQL now tracks `cmd_tuples`, MSSQL captures `TinyTds::Result#do` (which already computed the count and threw it away) plus `@@ROWCOUNT` in the SCOPE_IDENTITY batch, MySQL hoists its existing read. **Still open: Ruby's firebird/odbc/mongodb drivers have no `affected_rows` either** - not fixed because they cannot be verified against a live engine from here. | SHIPPED 3 of 6 engines (ruby `3912b90`) |

**A finding about the audit's own instruments. RESOLVED 2026-08-05** - the
fixture is now consumed in all four (`WritePathContractTest.php`,
`write_path_contract_spec.rb`, `writePathContract.test.ts`, and the Python
runner), and wiring the four runners to it found 5 real bugs, including the
`a_string_filter_with_params_works_the_same_as_a_hash_filter` case this note
predicted would catch the Node truncate bug. The finding as originally written
follows, kept because "a shared answer key that nothing asserts against reads as
coverage" is the reusable lesson, not the specific file. `write_path_contract.json` exists,
byte-identical, in all four repos - and **nothing reads it**. Its two siblings
(`adapter_contract.json`, `batch_write_contract.json`) ARE consumed by their runners
in all four, and by production code; this one is orphaned. So the four write-path
runners are hand-written independently, which is why they have different case counts
(python 17, ruby 16, php 15, node 14) and divergent case names. That is not cosmetic:
the fixture declares `a_string_filter_with_params_works_the_same_as_a_hash_filter`,
**no runner executes it**, and that is exactly the case that would have caught the
Node truncate bug above. A shared answer key that nothing asserts against is worse
than none - it reads as coverage. Wiring the four runners to the fixture is queued.



PHP won features 5 and 38. Feature 3 is now a redesign derived from cross-language
and live transaction evidence, not a promotion of PHP's interface.
Most other rows went SYNTHESISE because no single framework held the whole answer.
**"Python is master" would have been the wrong call on nearly every row**, and
feature 38 is the sharpest case: Python is the broken implementation there, and a
release converged the correct framework (PHP) onto it.

Implementation order, revised as rows closed: **6, 4, 5, 3, 13, 14, 15, 16, 17, 18, 19, 20**, then 2, 1, 0.

**Phase 1 (rows 1-6) and Phase 2 (rows 13-20) are complete. Phase 3 is open.**
**27 of the 28 table rows are closed** (recounted 2026-08-05; the "20 rows
closed" here predated the out-of-queue security cluster - rows 7-12, 41-43, 48
and 79 - and feature 2 re-closing). The one open row is the 66-feature
remainder, so **32 of 98 features are audited and 66 are not started.**

**One row jumped the queue, and it has SHIPPED (feature 38, closed all four).**
MEASURED 2026-08-05 against a sandboxed engine in Python and Ruby, the two the
finding named: `{{ x|raw }}`, `{{ x|safe }}` and
`{% autoescape false %}{{ x }}{% endautoescape %}` all render ESCAPED under
`sandbox(...)` - none leaks raw HTML. The finding as originally written follows;
it is kept because it is the one case where the audit recommended breaking its
own planning-only rule, and that judgement proved right.

Feature 38 found an exploitable bypass of a
documented security control: the Frond sandbox cannot revoke `raw` / `safe` in Python, Ruby and
Node, and `{% autoescape false %}` bypasses the tag gate in all four. Every other finding in
this programme is parked for planned implementation. That one is a live XSS hole in the
feature whose documented purpose is rendering user-supplied templates, and the fix is small.
See `features/038-sandboxing.md`. **Owner decision: taken, and shipped.**

**Phase 3 reads differently from 1 and 2.** Frond's correctness parity is already
enforced by a byte-identical 82-case corpus in all four frameworks (verified, md5
`931ed20b`), so the axis is **structure and performance**, not drift. It is also the
worst-measuring subsystem in the framework: 42 scanner errors across the four, two
frameworks at maintainability 0.0, and the single highest complexity number measured
anywhere (Node's Frond, 1095).
Feature 3 sits behind 5 because 5 removes the URL parsing that 3 would otherwise
refactor twice, and behind 4 because both touch the same facade methods.

## Implementation order (owner decision, 2026-07-28)

The audit runs to completion first; implementation follows. Within the
implementation queue, **the named-stage dispatch pipeline (feature 6) goes
first** - owner's call, "get it done early". The reason it earns the front of the
queue: every downstream verdict in this audit describes behaviour that currently
lives inside one of four god-functions, so until the stages have names there is
nothing to compare a downstream feature against. Fixing it first turns later
verdicts from archaeology into a diff.

Order within feature 6: Ruby, Node, Python, PHP. Characterisation tests green
before any extraction, one stage per commit.

## Owner decisions taken during the audit

| decision | outcome | recorded |
| --- | --- | --- |
| Implementation order | dispatch pipeline (feature 6) goes first | this doc |
| PHP `autoSnakeCase` default (feature 17) | **`false`** - the property name is the column in all four; PHP takes the migration | **ADR-0008** |
| Feature layout, all four (raised in Phase 3) | **one folder per feature**, so a feature can be deleted; Python is the reference | **ADR-0009** |

## Cross-cutting decision: one default row cap. RESOLVED IN CODE 2026-08-05, no owner call owed.

MEASURED across the four, by reading the signatures and running the reads, not by
re-reading this section: the cap is **100 everywhere**, and the table below is
stale in every row that claims otherwise.

| path | cap now |
| --- | --- |
| `Model.all` / `where` / `select` / `scope()` / `has_many()` | 100 in all four (Node via a named `DEFAULT_ROW_CAP = 100`) |
| `db.fetch()` | 100 rows returned; `.count` carries the true total from a separate COUNT probe (Python and PHP - see feature 18, this is NOT true in Ruby and Node) |
| `db.fetchAll()` / `limit <= 0` | uncapped, deliberately |
| `QueryBuilder#get` | uncapped |

That is a coherent two-tier design - convenience reads capped, explicit
escape hatches uncapped - not the "five paths, four defaults" inconsistency this
section was filed to resolve. The 20-versus-100-versus-unbounded spread is gone.

**Feature 18's correctness requirement is satisfied on the read side**: a 250-row
table read with the default cap reports `total = 250`, not 100, because `total`
comes from the COUNT probe rather than the capped read. Verified on a real table.

**What survived is not a cap question at all.** It moved into the envelope: see
feature 18, RE-OPENED, where `.count` means the true total in two frameworks and
rows returned in the other two. Fix that there. Nothing here needs deciding.

The section as originally written follows, kept because the reasoning that
produced the current design is worth more than the verdict it reached.

## Cross-cutting decision as originally filed: one default row cap

Surfaced by features 15 and 16 together, plus a fix that already landed. "Give me
some related or filtered rows" currently caps at four different numbers:

| path | default cap |
| --- | --- |
| `scope()` | 20 (python, php, node) / unbounded (ruby) |
| `has_many()` | 100 (python, php, **node** - measured 2026-07-30) / unbounded (ruby DSL) |
| `Model.where` | 20 (python, php, node) / nil (ruby) |
| `Model.all` | 100 (python) |
| `QueryBuilder#get` | unbounded - the `LIMIT 100` was **deliberately removed** |

Five read paths, four defaults, all truncating silently, and one of them was
already fixed once by removing its cap. That is not five bugs; it is one missing
decision applied inconsistently five times.

**This needs the owner's call, once, for the whole ORM** - either every read is
unbounded with explicit opt-in pagination, or they all cap at the same number and
say so. Deciding it per feature guarantees the inconsistency survives. Recorded
here rather than in any single feature plan because no single plan owns it.

A third inverted-flag defect turned up in feature 20 (`required` vs `nullable`),
after feature 2 (`production` vs `development`) and feature 17's schema split. Three
occurrences make it a pattern worth its own rule: **the audit treats an inverted
spelling of the same concept as equal in severity to a wrong value**, because the code
runs either way and the failure is silent. Every rename of one gets a hard error on
the old name rather than a silent reinterpretation.

**Feature 18 turned this from a preference into a correctness requirement.** A
paginate envelope is only honest if `total` is the true total. If `Model.all` caps at
100 and the table has 250 rows, `total` reads 100 and `total_pages` reads 5 - both
wrong, and wrong in a way that looks authoritative. The envelope launders a
truncation into a fact.

So `total` must come from a real `COUNT(*)` over the filter, never from a capped
read, and every path feeding a paginated response must be uncapped. That is the
argument for **unbounded by default, with pagination as the only thing that limits
rows** - and feature 18's `total_is_not_capped_by_a_default_read_limit` test is the
enforcement mechanism rather than a note in a plan.

## Findings that are not per-feature

Collected as they surface, because they change how the audit is read.

- **This document drifted, and the drift ran in the direction that flatters the
  work.** Audited 2026-08-05 by re-measuring every row that looked stale rather
  than re-reading it. Four rows were wrong: feature 2 was still marked RE-OPENED
  after all 5 of its defects had been fixed; feature 48 still carried a caveat
  that its four-way promise was untrue after PHP and Ruby had landed 12 and 19
  queue commits; the "nothing reads `write_path_contract.json`" finding was
  false in all four repos; and the narrative still asked for an owner decision
  on a live XSS hole that feature 38's own row recorded as shipped. Every one
  of those was stale in the SAFE direction for the reader (an open item that is
  actually closed), which is exactly why nobody noticed - a stale WARNING costs
  nothing to ignore until the day someone re-does the work it describes, or
  quotes it as the current state. **A closed row must be closed in the row on
  the day it closes.** The instrument that caught this is the same one the audit
  uses on the frameworks: re-measure, do not re-read.

- **The maintainability index is low across the board.** The messenger scored
  MI 7.1 (Python) to 14.7 (Ruby) against the scanner's minimum of 40, and all
  four raised maintainability errors. If that holds across features, the useful
  reading is relative (which of the four is least bad) plus an absolute finding
  worth its own plan.

## Status: In progress. Planning AND implementation.

The "planning only" framing held for the first pass. It stopped being true once
the owner switched to the walk model (2026-07-30): take features from the top,
audit the next unaudited one, ship it. Rows 0-5 and 38 have shipped code in all
four frameworks; 3 and 6 are the live edge.

Next up: **feature 6** (audited, planned, owner-sequenced FIRST, still not
implemented - no named-stage pipeline exists in any framework as of 2026-07-31),
then **7**, the first genuinely unaudited row.

Feature 3's earlier CRUD move landed 2026-07-31 and remains valid evidence, but
it no longer closes the feature. Measured rather than assumed: the six
Python adapters' INSERT statements were character-identical except for the
parameter marker and PostgreSQL's RETURNING, and PHP's method bodies hashed
identical across MySQL/MSSQL/Firebird and across SQLite3/ODBC. Python -199 lines,
PHP -459. Node is a DRY win rather than a LOC win (net +130): its duplication was
2-3 lines per method, not whole methods. **Ruby needed no change** - its only
driver-level CRUD is Postgres' `RETURNING *` seam, which is what the plan
predicted, and that is the check that the shape was right.
