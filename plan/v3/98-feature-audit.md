# Task: audit every feature, pick the best implementation, park a plan

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
| 0 | Messenger (pilot) | SYNTHESISE | correctness | `messenger-contract.md` | closed, tests red + committed |
| 1 | DotEnv parser | SYNTHESISE | correctness | `features/001-dotenv.md` | closed |
| 2 | Structured logger | SYNTHESISE | correctness | `features/002-structured-logger.md` | closed |
| 3 | DB adapter interface | PROMOTE php | SOLID | `features/003-database-adapter-interface.md` | closed |
| 4 | SQLite adapter + write path | SYNTHESISE (**P1**) | correctness | `features/004-sqlite-adapter.md` | closed |
| 5 | DATABASE_URL parser | PROMOTE php | SOLID | `features/005-database-url-parser.md` | closed, one blocker |
| 6 | Router + dispatch | SYNTHESISE | SOLID | `features/006-router-and-dispatch.md` | closed, sequenced first |
| 13 | ORM base class | PROMOTE ruby (structure) | LOC/CC | `features/013-orm-base-class.md` | closed |
| 14 | Soft delete | **GAP** (broken in 3 of 4) | correctness | `features/014-soft-delete.md` | closed, 1 outstanding |
| 15 | Relationships + eager load | PROVISIONAL PROMOTE python/ruby | correctness | `features/015-relationships.md` | closed, 2 outstanding |
| 16 | Scopes | SYNTHESISE | correctness | `features/016-scopes.md` | closed |
| 17 | Field mapping | PROMOTE node (mechanism) | SOLID | `features/017-field-mapping.md` | closed, decided (ADR-0008) |
| 18 | Paginated results | SYNTHESISE | wire contract | `features/018-paginated-results.md` | closed, 1 outstanding |
| 19 | Result / ORM caching | GAP (ruby) + SYNTHESISE | correctness | `features/019-orm-result-caching.md` | closed |
| 20 | Input validation | SYNTHESISE | correctness | `features/020-input-validation.md` | closed, 1 outstanding |
| 7-12, 21-93+ | remainder | - | - | - | not started |

Seven closed rows. PHP has now won twice (features 3 and 5, both on SOLID) and is
the only framework to win at all - every other row went SYNTHESISE because no
single framework held the whole answer. "Python is master" would have been the
wrong call on six of the seven.

Implementation order, revised as rows closed: **6, 4, 5, 3, 13, 14, 15, 16, 17, 18, 19, 20**, then 2, 1, 0.

**Phase 1 (rows 1-6) and Phase 2 (rows 13-20) are both complete.** 16 rows closed.
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

## Cross-cutting decision still open: one default row cap

Surfaced by features 15 and 16 together, plus a fix that already landed. "Give me
some related or filtered rows" currently caps at four different numbers:

| path | default cap |
| --- | --- |
| `scope()` | 20 (python, php, node) / unbounded (ruby) |
| `has_many()` | 100 (python, php) / unbounded (ruby DSL) |
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

- **The maintainability index is low across the board.** The messenger scored
  MI 7.1 (Python) to 14.7 (Ruby) against the scanner's minimum of 40, and all
  four raised maintainability errors. If that holds across features, the useful
  reading is relative (which of the four is least bad) plus an absolute finding
  worth its own plan.

## Status: In progress. Planning only, nothing implemented.
