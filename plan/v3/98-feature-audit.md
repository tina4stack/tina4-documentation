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

| Batch | Rows | Status |
| --- | --- | --- |
| 0 | Messenger (pilot, ran ahead of this doc) | done - `messenger-contract.md` |
| 1 | 1-6 Foundation: dotenv, logger, DB adapter interface, SQLite, URL parser, router | measured; 6 written up |

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

## Findings that are not per-feature

Collected as they surface, because they change how the audit is read.

- **The maintainability index is low across the board.** The messenger scored
  MI 7.1 (Python) to 14.7 (Ruby) against the scanner's minimum of 40, and all
  four raised maintainability errors. If that holds across features, the useful
  reading is relative (which of the four is least bad) plus an absolute finding
  worth its own plan.

## Status: In progress. Planning only, nothing implemented.
