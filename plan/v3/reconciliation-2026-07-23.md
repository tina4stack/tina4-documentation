# Reconciliation ledger — 2026-07-23

Snapshot after a burst of concurrent/background sessions. Establishes the TRUE committed
state, recovers orphaned work, and lists what remains. Nothing is pushed.

## Method note

`git status` showed several Ruby/Python files as `M` that `git diff` found identical to HEAD —
git's **stat cache** flagged them dirty because their mtime changed (a session wrote then reverted,
or checkout touched them) while content matched. `git update-index --refresh` cleared the phantoms.
Lesson: on a busy tree, trust `git diff`/`--stat` (real content compare), not the `M` flag alone.

## All four suites green at the merged HEAD (re-run by me, 2026-07-23)

| Framework | HEAD | Result |
|-----------|------|--------|
| Python | `010e381` | 3586 passed / 104 skipped / 0 failed |
| PHP | `2ef3580f` | 3900 tests, 10093 assertions / 0 failed (100 skipped) |
| Ruby | (clean) | 4094 examples / 0 failed |
| Node | `d4d862f` | 5589 passed / 0 failed across 170 files |

No mocks; full suites, not subsets. This is the shippable baseline once the six ports below land.

## Committed and verified this session

- CSS refresh + calc fix (5 repos), `!default` compiler fix (4), CLI delegation (4), Node
  `require()` devAdmin fix, Ruby MQTT client + auth + TLS + EMQX.
- **Python D6 master RECOVERED + committed** (`010e381`). A prior worker rewrote TestClient to
  dispatch through the real `core.server.app` front controller, then died uncommitted with no
  lock-in. Verified rather than trusted: full suite 3586/0, and a new lock-in that BITES against the
  pre-fix client (unmatched path -> real 404, not the fabricated `{"error":"Not found"}`). Carries a
  `Breaking:` note: `TestResponse.status_code -> .status`, which ALIGNS Python with Ruby/PHP/Node
  (Python was the outlier), not a divergence.

## The three "half-landed" fixes — RESOLVED. Only ONE was a real gap.

The matrix below was first built from **commit-message presence**, which overcounted the backlog:
independent verification (read the behaviour / run it) proved 2 of the 3 were already complete. This
is the recurring lesson — a commit-message absence is not a behaviour absence.

| Fix | Python | PHP | Ruby | Node | Verdict |
|-----|--------|-----|------|------|---------|
| D6 TestClient -> real front controller | ✅ `010e381` | ✅ `6f3f8fc1` | ✅ `417e5a3` | ✅ `ce07a8a` | **REAL gap, now 4/4** |
| test-gate: fail run on a service-skip | ✅ (native) | ✅ `2ef3580f` | ✅ `c67fd7f` | ✅ (native) | **NOT a gap** |
| background: deregister a stopped task | ✅ | ✅ | ✅ | ✅ | **NOT a gap** |

**D6 (real).** Python's old TestClient hand-rolled `Router.match` + fabricated `{"error":"Not
found"}`; Node's did the same and skipped RFC-9110 conformance + middleware. Both fixed to dispatch
through the real front-controller tail, each with a biting lock-in. PHP was ALREADY correct
(`Router::dispatch` IS the front controller — proven empirically: a miss renders the real
`<!DOCTYPE ... 404`); its gap was only the missing lock-in, now added. Ruby had it (`417e5a3`).

**test-gate (not a gap).** The PHP fix (`2ef3580f`) patches a blind spot specific to the PHPUnit/
RSpec EVENT model: a skip from `setUpBeforeClass`/`before(:all)` emits one `TestSuite\Skipped` for
the whole class, which a per-test subscriber misses. Python's gate is a per-item
`pytest_runtest_makereport` hook and Node's is a stdout SKIP scanner — neither shares the blind spot.
**Verified empirically for Python:** a `setup_class` skip under `TINA4_REQUIRE_SERVICES=1` exits 1
(gate caught it, becomes a per-item ERROR on every test in the class); exits 0 with the flag off.
Like C13 (Ruby ERB): the same guarantee achieved by a different, inherently-complete mechanism.

**background-deregister (not a gap).** Already 4/4 in code AND tests: Ruby `Background.stop_task`
(`tasks.delete_if { |r| r.equal?(task) }`, `background.rb:60`) + `spec/background_spec.rb` `.stop_task`
block; Node `handle.stop()` (`_tasks.splice`, `background.ts:106`) + `backgroundTaskCount() === 0,
"stop() must deregister the task"` (`backgroundOverlap.test.ts:81`); Python + PHP documented and
tested. The ledger's ❌ came from the absence of a commit titled "background: deregister", not the
absence of the behaviour.

**Net:** one real gap (D6) closed to 4/4 this session; the other two were verification artifacts.
The day's stalled sessions left the D6 orphan, but did NOT leave six ports — the parity backlog from
this reconciliation is now empty.

## Orphan status

- Python D6 orphan: RECOVERED, committed, lock-in added. No longer at risk.
- No other orphaned uncommitted framework code. Ruby/PHP/Node working trees are clean.
- Stashes present (not mine, left by other sessions): tina4-python 5, tina4-ruby 1, tina4-nodejs 1,
  tina4-documentation 1. Left untouched - dropping another session's stash is destructive.

## Recommended close-out

All framework trees are now quiescent (no live worker). The six remaining ports are well-specified
and low-ambiguity (two already have a committed reference framework to mirror; D6 has both Ruby and
Python). Given the day's repeated worker stalls, sequence them as ONE worker per framework in turn -
NOT concurrent in a shared tree - or hand the owner the choice. Do not spawn concurrent workers into
the same repo again (see [[feedback_no_parallel_workers_one_tree]]).

## Still-open D-list (unchanged, outside this reconciliation)

D16 MCP SSE `header()+echo`; D19 `@each` fail-loud; D20 Ruby compiler parity; C1 Ruby doc-truth
checker; feature-list page regeneration; `composer.json`/`llms.txt` number fix; the book
`.status_code`->`.status` TestClient doc follow-up from D6.
