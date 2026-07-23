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

## Three parity fixes are HALF-LANDED (each 2 of 4) — the real reconciliation output

| Fix | Python | PHP | Ruby | Node | Missing |
|-----|--------|-----|------|------|---------|
| D6 TestClient -> real front controller | ✅ `010e381` | ❌ old `Router::dispatch` | ✅ `417e5a3` | ❌ old | **PHP, Node** |
| test-gate: fail run on a service-skip | ❌ | ✅ `2ef3580f` | ✅ `c67fd7f` | ❌ | **Python, Node** |
| background: deregister a stopped task | ✅ `7e53aa7` | ✅ `14df2a3a` | ❌ | ❌ | **Ruby, Node** |

Six framework-ports remain, plus their lock-in tests. Node is missing all three. Under the parity
mandate none of these is "done" until 4 of 4. **These came from independent/background sessions that
each stalled mid-matrix** - the pattern of the day (4+ workers died mid-task leaving orphans), which
is why they are half-landed rather than complete.

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
