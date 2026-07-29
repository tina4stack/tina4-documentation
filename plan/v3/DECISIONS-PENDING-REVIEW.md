# Decisions taken autonomously, banked for owner review

Every call I made without asking, so it can be reviewed in one place instead of
reconstructed from diffs. Each row names the principle that drove it, so a
disagreement is a disagreement with the principle, not with a guess.

Nothing here is released. All of it sits unreleased on `v3` (frameworks) and
`main` (CLI, docs), waiting for the next tag.

Standing authority used: `feedback_decide_dont_ask` (2026-07-29) - "decide it
myself whenever the answer is derivable from an existing principle, ADR, or
standing feedback", with the tiebreak `feedback_maintainability_means_less_code`
(prefer less code / fewer contracts / one path).

---

## 1. Contract changes (these are the ones to read first)

| # | Decision | Driven by | Blast radius | Reversible? |
| --- | --- | --- | --- | --- |
| 1.1 | **Deleted all four hand-rolled metrics analyzers.** `tina4 metrics --json` is the ONLY engine. | ADR-0002 + owner: "hand rolled analysers get removed" | dev-admin metrics panel, MCP metrics tools, CLI metrics, in all 4 | Yes, git revert |
| 1.2 | **No fallback when the CLI is missing.** It raises and names the install command; `/metrics/full` returns 503, `/metrics/file` 404 for a bad path. | Owner: "No fall backs" + errors-are-DX | anyone running dev-admin without the CLI on PATH | Yes |
| 1.3 | **`quick_metrics` stays in-process.** It is a file census (globs, line counts), not analysis. | Measured: census 60-78ms vs engine 1.0-1.4s on ~100 files; the dashboard hits it every load | none (kept as-is) | n/a |
| 1.4 | **`violations` key REMOVED from `full_analysis`.** The ranked `offenders` list replaces it, and `--fail-on` reads that same list. | one-engine; two names for one concept is two contracts | any consumer reading `violations`. Verified: **zero** consumers outside tests | Yes |
| 1.5 | **`file_detail` loses `total_lines`, `classes`, `imports`, `warnings`; `functions` is now a COUNT.** This is the engine's own per-file shape. | one-engine + Python master's shape is the contract | dev-admin per-file drill-down | Yes |
| 1.6 | **Dropped the empty-class warning outright.** No engine equivalent, and inventing a PHP-only one puts a second analyzer back in the build. | `feedback_no_aliases` (no second path for compatibility) | a marginal dev-admin hint | Yes, but needs an engine feature |
| 1.7 | **Primary-key field is named per language paradigm**: `primary_key` (Python/Ruby), `primaryKey` (PHP/Node). Dead `:primary` fallback deleted in Ruby. | Owner: "Keep the case specific to the language paradigms" | `getColumns`/`columns` consumers | Yes |

**Needs a `Breaking:` changelog entry + migration note** (per
`feedback_contract_change_changelog`): 1.4, 1.5, 1.6, 1.7. I have NOT written
those yet - they go in with the release notes.

## 2. Real bugs found and fixed while doing the above

| # | Bug | Where | Proof |
| --- | --- | --- | --- |
| 2.1 | `module_has_tests` had no class-symbol stage: a class a test imports through the package root was reported UNTESTED and raised a false offender. | `tina4/src/metrics.rs` | 4 Rust tests incl. the negative; commit `f72338c` |
| 2.2 | **PHPUnit's `FooTest.php` matched nothing.** Every stage-1 pattern uses a separator (`test_x`, `x_test`, `x.test`), so PascalCase matched none, and stage 3 correctly refuses to find `Widget` inside `WidgetTest`. Result: **every PHP source file raised a false "untested" offender.** | `tina4/src/metrics.rs` | positive + anchored-negative test; proved RED without the fix, green with it |
| 2.3 | A PHP test looped `foreach` over the `functions` COUNT. An int is not iterable, so the body never ran - the test asserted **nothing** while reporting green. | `tina4-php/tests/MetricsTest.php` | rewritten to assert non-empty FIRST so it cannot rot back |
| 2.4 | `PRAGMA table_info` returns `pk` as a 1-based POSITION, not a boolean. Testing `pk == 1` truncated composite keys. | Ruby + Node drivers (2 frameworks, not 3 - I miscounted first) | `ColumnShapeContractTest` (7 tests, real SQLite, composite key + source-invariant) |

## 3. Claims of mine that turned out WRONG (corrected, on the record)

| Claim I made | Reality | How it was caught |
| --- | --- | --- |
| "There is a CLI LOC bug" | No bug. I derived "should be 2" by hand; the contract explicitly counts the `def` line. Verified 4/4, 2/2, 2/2 against the master's fixtures. | Read the test that defines the contract |
| "`FooTest.php` is already handled by stage 3" | False. Nothing handled it - see 2.2. This was my third guess-instead-of-read in one session. | Ran the engine on a real fixture |
| "Composite-key driver bug hits 3 frameworks" | Two. | Read `git log 3.13.92..HEAD` |
| "Docker 3.13.94 failed on a transient flake" | Deterministic: DOCKERHUB secrets missing in all four repos. | Reran; it failed later, revealing the real cause |
| "`assertArrayHasKey('offenders')` on `fullAnalysis`" | Wrong shape. `offenders` belongs to `offenders()`; PHP and Python key sets are byte-identical without it. | Compared both key sets directly |

## 4. Measurement credibility - the thing worth knowing

ADR-0002's premise is that numbers are comparable across the four languages.
**That was true of nothing before this work**: each framework ran its OWN
analyzer. So every cross-framework LOC/CC/MI number in the 98-feature audit,
including the Frond findings (two frameworks at MI 0.0, Node CC 1095), was
produced by four different implementations. The rankings may well hold, but they
were not evidence. They become evidence once all four route through one engine.

Bug 2.2 compounds this: until now the PHP scan called every file untested.

## 5. Lines removed

| Framework | Before | After | Delta |
| --- | --- | --- | --- |
| Python `metrics.py` + `metrics_engine.py` | 975 | 375 | **-600** |
| PHP `Metrics.php` | 1669 | 534 | **-1135** |
| Ruby | pending | | |
| Node | pending | | |

## 5b. Answered by the owner mid-session (2026-07-29)

| # | Question | Answer | Follow-up |
| --- | --- | --- | --- |
| A | ORM field / column naming case | **Keep the column name exactly as it is in the DATABASE.** A language-specific case mapping may be an OPT-IN later, but the default must mirror the DB so nobody guesses wrong. (PHP historically carried both camel AND snake_case.) | Audit all 4 for any implicit case conversion on column names, and confirm the opt-in is genuinely off by default. NOT yet done. |
| E | (my 6.6 was badly worded, so here it is plainly) The deleted PHP analyzer had a `warnings` list, and one entry flagged `class Foo {}` with no members as "empty_class". The engine has no equivalent, so decision 1.6 dropped it. Should the engine grow it back? | **No. Dropped permanently.** An empty class is usually CORRECT, not a defect: marker classes, base exception types, DTO placeholders. Tina4 itself now ships `class MetricsEngineError extends RuntimeException {}` -- that warning would flag the framework's own correct code. A check that fires on correct code is noise, and noise is precisely why the offenders list was ignored for months. The engine's vocabulary stays the four things that are actually actionable: complexity, large file, low maintainability, untested. | None. 1.6 stands. |
| D | Node `db.executeMany()` facade atomicity (you asked me to call it) | **Make it ATOMIC: all rows commit or none do.** Three reasons. (1) The Python master is atomic, and Python is the reference. (2) `executeManyAsync` was ALREADY made atomic for mysql/mssql/postgres, so the facade currently offers a WEAKER guarantee than the method it fronts, which is the "two paths for one concept" the maintainability tiebreak rejects. (3) A half-applied batch is the worst outcome available: it writes real rows, returns without an error, and leaves nobody able to tell how far it got. A caller who genuinely wants per-row best-effort can loop and catch. | Wrap the facade in a transaction, return a DatabaseResult, and lock it in with a real rollback test on each engine (no mocks). NOT yet done. |
| C | ORM default row cap (was 5 code paths, 4 different defaults) | **100.** Pagination is a default principle, so every read path caps at 100 unless the caller asks for more. | Unify all 5 paths on 100 across all 4 frameworks, with a lock-in test per path. NOT yet done. |
| B | Docker Hub credentials for the missing 3.13.94 images | Credentials live on the **192.168.88.99** server; images can be built and pushed from there. | Build + push the four 3.13.94 images from that host. NOT yet done. |

Note this is a DIFFERENT axis from decision 1.7. 1.7 is about the metadata KEY
the framework returns (`primary_key` / `primaryKey`), which follows each
language's paradigm because it is framework API surface. A is about the COLUMN
NAME itself, which is DATA and must mirror the database verbatim.

## 6. Open questions I did NOT decide (they need you)

| # | Question | Why I did not decide it |
| --- | --- | --- |
| 6.5 | Firebird has no live server, so 3 Ruby rollback specs + the PHP Firebird paths are UNVERIFIED | Cannot verify without infrastructure |

## Status: banked, unreleased. Awaiting review.
