# 19 — Seamless Dev Admin (design notes)

> Written 2026-04-25 mid-session after a long whack-a-mole on the
> supervisor/MCP/chat path. The user pulled me up: **stop fixing one
> bug at a time, write down what "seamless" means, agree on it, then
> build it properly across all 4 frameworks at once.** This file is
> that brief.

## Vision

The Tina4 dev-admin SPA + MCP server should feel like one product
across PHP / Python / Ruby / Node. A user opens `/__dev`, types what
they want in plain English, and the project advances:

- Routes appear and respond without a server restart.
- Models, migrations, images, copy, css land in the right paths with
  the right idioms for the host framework.
- The file tree, the editor buffers, and the running server stay in
  sync. No "did that work?", no "click refresh".
- If the model can't do something, it says so once and the system
  fills the gap with a tool — not the other way round.

The supervisor's job is to **propose changes safely** (worktree
diff, Apply to commit). The chat's job is to **express intent**.
Everything between those two is plumbing we own.

---

## What we have today (mid-session inventory)

### Working

- `/__dev` SPA bundle, framework-agnostic (single bundle, all 4).
- Supervisor session lifecycle (Rust agent, git worktree, diff/apply).
- 45 MCP tools spanning DB / routes / files / plan / project_index /
  docs / git / deps.
- Per-framework chat-prompt overlay (PHP/Ruby/Node/Python idiom hints
  prepended to the system message).
- Image generation via `/image/v1/images/generations` proxied through
  the framework to SDXL Turbo.
- Chat history persisted to `localStorage` across page reloads.
- Image-intent shortcut in the chat input ("make a picture of cow").
- Auto-`git init` when starting a session in a non-git project.
- EINTR retry in stream_select (PHP) so the server doesn't die mid
  request.
- Compact JSON in chat proxy so token streaming actually parses.

### Reproducible failures observed live (2026-04-25 session)

These are not theoretical — every one was hit in 30 minutes of actual
testing on a fresh PHP project. They pin Phase 1 priorities.

| Failure | What the user typed | What broke | Root cause |
|---|---|---|---|
| Hallucinated tool | "call it index" | Agent emitted `file_move` (doesn't exist), got "Unknown tool", retried twice, never recovered | No availability discovery (Gap 6); no `file_rename` tool (Gap 5) |
| Sequence error | (same) | Agent called `file_patch` on `src/routes/index.php` before the rename happened | No scaffold tool that does rename + reference-update atomically |
| Empty base.twig | "where is base.twig?" | Agent `index_search` failed → created a 33-byte placeholder file | No `template_create` scaffold, no awareness of the framework's actual base template content |
| No index convention | "add a home page" then "call it index" | Agent created `home.php`/`home.twig` but doesn't know Tina4 PHP's index convention — `/` route, template extends `base.twig` | Per-framework conventions not encoded as scaffolds; only as prose in the chat overlay |
| Lying about images | "make a picture of a tree" / "image of a cow" (typo: "pciture") | Pre-fix: regex didn't match → LLM said "I can't generate images". Post-fix: works | Already fixed Phase 1 (intent regex relaxed) but proves the model will lie about capability when intent isn't intercepted |
| File tree stale | (anything that writes a nested file) | New file in `src/routes/` invisible until manual refresh | Refresh is root-only (Gap 3) |
| Server restart needed | (any new route file) | New route doesn't respond until `tina4 serve` restart | Gap 1 (hot route discovery) |
| Raw tool_result noise in chat | (any tool call) | Chat bubbles render literal ` ```tool_result name=file_write { "written": "...", "bytes": N } ``` ` blocks — internal protocol leaking through to the user | The compact chip rendering only fires when `extractTouchedPath` returns a known mutator; non-recognised tools and the model's verbatim echo of `tool_result` blocks bypass the renderer. Chat formatter should strip ALL `tool_result` blocks (the chip row already shows the result) |
| Twig/Frond not highlighted | Open `home.twig` | `{% extends %}` and `{% block %}` render as plain text; HTML inside also unstyled | No CodeMirror Twig language pack imported. Editor.ts only registers js/py/php/html/css/json/yaml/sql/md. `.twig` falls through to the no-language default |
| DevReload kicks the dev-admin itself | Chat with the supervisor; it writes a file | The Rust CLI broadcasts `{type: 'reload'}` on `/__dev_reload` after the file change → the dev-admin SPA full-page-reloads → user loses the chat scroll, the open file tabs, the in-flight tool stream | The reload-watcher in the dev-admin doesn't differentiate "I'm editing a user app" from "I'm the editor". When the SPA is on `/__dev*`, file-change events should refresh tree + open buffers only — never `location.reload()`. This is Section D's job |
| Model tells user to run git CLI | "commit my changes" in supervisor mode | Reply: "I'm unable to perform Git operations directly. To commit your changes, you can use the following steps: `git add .` …" — with a copy-able shell snippet | Two real failures: (a) **Apply button IS the commit mechanism** in supervisor mode — telling the user to `git add` bypasses the worktree isolation and corrupts the proposal flow; system prompt must explicitly forbid suggesting raw git commands. (b) No `git_commit` / `git_add` / `git_log` MCP tools for the legitimate Q&A-mode case where a user just wants a quick commit; only `git_status` exists today |
| Error overlay is a dead-end | A user route throws (e.g. `Call to undefined method Tina4\Response::template()`) | Full-page error overlay takes over; user has to manually navigate back to `/__dev` to ask the AI to fix it | Error overlay should mount the **dev-admin shell** as a sibling panel — same chat, same plan, same file tree, same MCP tools — so the user can say "fix this" and the LLM can act with the error trace + stack already in context. The current overlay is a static HTML page; it should be the error page's content INSIDE the dev-admin layout when `TINA4_DEBUG=true`. Belongs in Section M (toolbar-on-error) but extended: not just inject the toolbar, **inject the whole SPA**, with the error pre-loaded as a chat context bubble |
| No undo of agent actions | Agent file_writes a wrong file mid-session | The only undo today is "Cancel session" — which discards EVERYTHING since session start, not just the bad turn | Need per-turn undo: every mutating tool call records a reverse-patch in the decision ledger (Section J). Undo = apply the reverse-patch + delete forward records. Maps cleanly onto git in supervisor mode (each turn = a commit on the worktree branch; undo = `git reset HEAD~1` on the worktree). Outside supervisor mode (Q&A-write or future direct-edit), reverse patches are stored in `.tina4/undo/<id>.patch` |

**Lesson:** the agent's failure modes are not "bad LLM" — they're
"missing tools". Every failure above resolves to either "tool didn't
exist" or "tool didn't have framework awareness". The design doc's
Phase 1 (canonical tool spec + scaffolds + availability block) fixes
all seven.

### Broken or fragmented (the punch list "from the start")

1. **Hot route discovery.** PHP loads `src/routes/` once at boot.
   New route files written by the supervisor don't register until
   `tina4 serve` is restarted. Fatal for the seamless story.
2. **Worktree isolation mismatch.** Supervisor creates a worktree at
   `.tina4/sessions/<id>/tree/` but MCP tool calls go through the
   framework's MCP server, which writes to the project root — NOT
   the worktree. Apply has nothing to apply.
3. **File-tree refresh is shallow.** `refreshAfterToolMutation()`
   reloads the root dir only. A tool that writes `src/routes/foo.php`
   doesn't trigger a re-fetch of `src/routes/`, so the user has to
   click out + back to see new files.
4. **Cross-framework tool drift.** Every gap (file_patch, SafeString,
   image_generate, background helper) lands in PHP first, then has
   to be ported. We patched in 30+ releases this week to get parity.
5. **MCP tool surface is fragmented.** No first-class scaffolds for
   the things users actually ask for: "add a route", "add a model",
   "add an image". The model improvises with `file_write` and
   sometimes hallucinates content.
6. **No tool-availability discovery.** The chat system prompt
   enumerates tools with text descriptions; the model still
   sometimes claims "I can't generate images" because it didn't read
   the list. Need a hard "tools available right now" block at the
   top of every turn.
7. **Error surfaces are inconsistent.** "Path escapes project
   directory" was thrown on a perfectly innocent `tests/foo.php`
   because of a `realpath()` quirk. Other surface leaks: PHP 8.5
   deprecations, EINTR warnings, 404 with no toolbar injection.
8. **No image_save loop.** SDXL generates an image inline in chat;
   there was no path from "this image is good, save it to my
   project" without typing a base64 blob.

---

## Target architecture

### A. One MCP spec, four implementations

A single source-of-truth doc enumerates every MCP tool: name, args,
return shape, side-effects. PHP/Python/Ruby/Node implement against
that spec. New tool? Spec change first, then 4 PRs in lockstep.

Concrete: `tina4-mcp-spec.md` next to this doc, with versioned
sections (`v1: 45 tools`, `v2: + image_generate, route_create, …`).
A test harness verifies each framework's MCP server matches.

### B. Hot route loading in dev mode

When `TINA4_DEBUG=true`, the framework rescans the route dir on every
request (cheap — maybe 50 files), or watches the dir for changes via
the existing Rust file watcher and re-imports the touched file. PHP
needs `require_once` reset so re-includes register routes again
without `Cannot redeclare` errors — solvable by routing through a
class-method registration pattern.

Exit criterion: write `src/routes/foo.php`, hit `GET /foo` from
curl, get a 200 — without restarting the server.

### C. Worktree-aware MCP

When a supervisor session is active, the SPA sends `X-Tina4-Session:
<id>` on `/mcp/call` requests. The framework's MCP server resolves
file paths against the session's worktree root, not `getcwd()`.
That makes Apply meaningful — the worktree IS the staging area.

Q&A mode (no session) writes to project root unchanged.

### D. Granular file-tree refresh

After a mutating MCP tool result, the SPA should:
- Re-fetch the dir(s) containing every touched path.
- Recursively re-fetch any expanded sub-dirs of those parents.
- Prefer a WS event `{type: 'fs-changed', paths: [...]}` broadcast
  by the framework when the MCP server writes — single source of
  truth for FS state, multiple SPA tabs stay in sync.

### E. First-class scaffolds as MCP tools

Replace the model's improvised `file_write` for common asks:

- `route_create(path, method='GET', handler_body, file_name?)` →
  writes `src/routes/<file>.php` (or .py, .rb, .ts) with the
  framework-correct shape.
- `model_create(name, fields[])` → writes `src/orm/<Name>.php` AND
  the matching migration. One call, both files.
- `migration_create(description, sql?)` → SQL-file in `migrations/`
  with the framework's naming convention.
- `image_generate(prompt, path?)` → SDXL + save in one shot. (PHP
  draft landed this session; port to others.)
- `template_create(name, content)` → `src/templates/<name>.twig`.
- `middleware_create(name, body)` → matching language idiom.

The system prompt for supervisor mode lists these in priority order
above `file_write` so the model reaches for them first.

### F. Tool-availability block in every turn

Top of system prompt:

```
TOOLS AVAILABLE THIS TURN (call by name, not by description):
  image_generate, route_create, model_create, migration_create,
  file_patch, file_write, file_read, plan_*, index_*, …
```

Plus a short "if user asks for X, call Y" mapping table. Eliminates
"I can't generate images" / "I can only assist with code" lies.

### G. Consistent error envelope

Every MCP tool returns one of two shapes:
```
{"ok": true, "result": ...}
{"ok": false, "error": "<string>", "hint?": "<string>"}
```

The SPA renders the `hint` as a soft suggestion ("try file_patch
instead", "the parent dir doesn't exist — call file_write with a
nested path"). No more terse "ERROR: …" walls.

### N. Twig / Frond syntax highlighting

Opening a `.twig` file in the dev-admin shows it as plain text.
`{% extends %}`, `{% block %}`, `{{ var }}`, HTML tags, attribute
strings — all rendered with the default colour. Reading or editing
a template feels like reading a `.txt`.

CodeMirror has no first-party Twig pack. Options, ranked:

1. **Mixed-mode HTML + Twig stream overlay** *(preferred)* —
   `@codemirror/lang-html` as the base, a `StreamLanguage`
   extension that recognises `{% … %}` / `{{ … }}` / `{# … #}` and
   tags them with a `tw-tag` / `tw-expr` / `tw-comment` highlight
   class. Editor.ts already uses `StreamLanguage` for one or two
   languages — this fits the existing pattern.
2. **Community package** — `codemirror-lang-twig` (or similar)
   exists; check zero-dep policy and license. If it pulls
   transitive deps the SPA bundle bloats.
3. **Inline custom mode** — define a tiny tokenizer in
   `framework-context.ts`-adjacent file, register against
   `.twig` / `.html.twig`. ~80 lines.

Frond is a Twig superset on the framework side. From the editor's
perspective, treating Frond as Twig is correct — the highlighter
doesn't need to know about Frond-specific filters (those are
runtime concerns).

#### Acceptance test

Open `src/templates/base.twig` with the new build and verify:
- `{% extends 'base.twig' %}` — `extends` keyword highlighted, the
  string literal in a different colour.
- `{% block content %}` ... `{% endblock %}` — block markers
  visually distinct from HTML.
- `{{ user.name | upper }}` — `{{` `}}` brackets, the variable
  path, and the filter all separately tinted.
- HTML inside (`<h1>`, `<p>`) still gets HTML highlighting.
- A `.twig` file with no extends declaration still highlights HTML.

#### Why it matters now

The supervisor frequently writes templates. The user reviews them.
A template diff with no highlighting buries the actual change in a
wall of grey text. Time-to-spot-bug doubles. Every screenshot the
user sent us this session of a `.twig` file proved the highlighting
was missing — they noticed every time.

This is a **Phase 1** item, ~1 day of work, ships in the same wave
as the per-framework chat overlay (which already detects file
language for the system prompt — same detection table).

### M. Dev lifecycle for the dev-admin itself

We released 30+ point versions this week chasing silly regressions
(curl_close deprecation, EINTR loop, pretty-printed JSON, missing
file_patch, Path-escapes-realpath, image proxy 404, etc.). Most were
preventable. The dev-admin's own dev lifecycle needs to mature
before we ship more features.

**Rule:** a dev-admin or framework release that "fixes a bug found
by the user mid-session" is a CI failure. CI should have caught it.

#### Pre-tag CI suite (per framework)

Run on every commit to `v3`:

1. **Unit + integration tests** — already exist in each framework
   (`composer test`, `pytest`, `rspec`, `npm test`). Must stay green.
2. **Bundle integrity** — `npm run build` in `tina4-dev-admin` must
   succeed; smoke-grep the output for known bad patterns
   (`localhost:7200`, unescaped backticks in HTML comments, etc.).
3. **Cross-framework MCP parity test** — boot each framework with
   `TINA4_DEBUG=true`, hit `/__dev/api/mcp/tools`, assert the
   returned tool list matches the canonical spec
   (`plan/v3/20-MCP-SPEC.md`). Different across frameworks → red.
4. **Dev-admin smoke flow** — boot a fresh framework instance, run
   a scripted SPA flow against it via `Claude_in_Chrome` or curl:
   - Open `/__dev`, assert SPA loads
   - Start a supervisor session, assert worktree created
   - Send a known prompt ("add a /hello route"), assert tool calls
     fire AND the route serves 200 within 30s
   - Apply, assert files land in real tree
   - Cancel, assert worktree gone
   The flow runs on all 4 frameworks. Any framework failing → red.
5. **Static deprecation grep** — run the language's deprecation
   checker (PHP `--syntax-check` + `vendor/bin/phpstan`, Python
   `pyright`, Ruby `rubocop`, Node `tsc --noEmit`) and fail on new
   warnings.

#### Pre-release manual gate

Even with green CI, every release goes through:

- **Manual smoke** — open the dev-admin in a browser against the
  candidate, click through 5 canonical flows (chat, plan create,
  route create + curl, image generate, supervise apply). Sign-off
  in PR.
- **Release-notes diff** — auto-generate from commits since last
  tag (existing `git log` pattern). Maintainer redlines before
  tagging.

#### Testing the LLM path

The chat is non-deterministic so traditional test asserts don't
work directly. But we can:

- **Pin a model** — every test run uses qwen2.5-coder:14b at a
  specific revision, recorded in test metadata.
- **Use the decision ledger as a test corpus** — Section J's
  `.tina4/decisions/*.jsonl` files are replayable. A nightly job
  replays last week's user-tested intents through the latest
  build, compares outcome rates, and flags regressions.
- **Mock RAG and image** — the test suite injects deterministic
  RAG hits and a stub image backend so chat replay is repeatable.

#### Release cadence

Stop tagging on every fix. Batch fixes into:

- **Patch (3.11.x)** — weekly. CI green + smoke green.
- **Minor (3.x.0)** — when a phase ships. Includes coordinated
  4-framework release. Major version locked to v3 for now.

This week's 30 patch tags should have been 1–2 patch releases.

#### Tina4 dev-admin's own plan

Eat our own dog food. The dev-admin's roadmap (this file) gets
tracked as a Tina4 plan in `tina4-dev-admin/plan/`. Steps map 1:1
with the phases in this doc. We work the plan from a Tina4
supervisor session — that surfaces our own UX gaps faster than
anything else.

---

## Section index → phase map

| § | Topic | Phase |
|---|---|---|
| A | One MCP spec, four implementations | 1 |
| B | Hot route loading | 2 |
| C | Worktree-aware MCP | 3 |
| D | Granular file-tree refresh | 1 |
| E | First-class scaffold tools | 1 (basics) → 4 (rest) |
| F | Tool-availability block in system prompt | 1 |
| G | Consistent error envelope | 1 |
| H | RAG on by default | 5 |
| I | Chat export for triage | 1 (small) |
| J | Decision / outcome ledger | 1 (parallel) |
| K | Plan-driven workflow contract | 1 |
| L | Verification loop (execute / test / observe) | 2 (after hot routes) |
| M | Dev lifecycle / CI / release cadence | 0 (must precede 1) |

Phase 0 (M) is **non-optional** and starts now. Without CI + cadence
discipline, every other phase regresses inside a week.

---

## How we work from now (commitment)

The user's pulled me up multiple times this session. Fair. Here's
how I behave going forward:

1. **Plan-first, code-second.** Every non-trivial change starts as
   a Tina4 plan in `tina4-dev-admin/plan/` (or the relevant
   framework's `plan/`). I `plan_create` before I `file_write`. If
   I catch myself coding without a plan, I stop and create one.
2. **Cross-framework parity from the first commit, not the third
   release.** A change that needs to land in PHP/Python/Ruby/Node
   ships in all 4 in the same wave or it doesn't ship. No more
   "PHP first, port later" — that's how we got 30 patches this
   week.
   **No stubs count as parity.** A `/__dev/api/supervise/*` that
   returns `501 Not Implemented` is not parity with a working
   implementation — it's a lie that defers the real work to a
   later release that often doesn't come. If a framework can't
   support a feature yet, the parity matrix marks it as "unsupported
   on framework X" and the dev-admin SPA hides or disables the
   feature on that framework. Stub responses are forbidden.
3. **Tests before tag.** Phase 0 (Section M) ships first. CI
   green + manual smoke green = tag-able. No tag without both.
4. **One bug, one issue, one fix, one merge.** Open a GitHub
   issue against the right repo before fixing anything. The user
   shouldn't be the issue tracker.
5. **Stop volunteering UI buttons.** Sections E (scaffold tools)
   and K (plan-driven workflow) are the right abstractions. New
   buttons in the chat row are a smell.
6. **Stop apologising in the chat replies.** "Quick win" framing
   is gone. We deliver the proper thing or we explain what's
   missing and ask. No middle ground.
7. **Verify before claiming done.** Section L's verification loop
   applies to my own work too. I don't say "shipped" until I've
   curl'd the new endpoint or the equivalent.
8. **One design doc, one truth.** This file + `20-MCP-SPEC.md`
   (when written) are the source of truth. PRs reference sections
   here by letter (A/B/…/N).

If I drift from any of those, the user can quote this section
back at me and I correct course in the same turn.

---

## Immediate next moves (no code, decisions only)

In order, **before any more commits**:

1. User reads this doc end-to-end and redlines what's wrong.
2. We promote Section A's tool spec to its own file:
   `plan/v3/20-MCP-SPEC.md`. Lists every MCP tool name, args,
   return shape, behaviour. Versioned (v1 = today's 45, v2 = +
   `route_create`/`template_create`/`file_rename`/`image_generate`
   /`route_test`/`template_test`).
3. Open issues in the right repos — one per phase, plus one per
   live-failure-table row that isn't already addressed.
4. Decide on the uncommitted state from this session:
   - PHP `image_generate` MCP draft → keep as-is or revert?
   - PHP Router.php toolbar-on-404 refactor → keep or revert?
   - dev-admin `framework-context.ts` + RAG hook + chat
     persistence + image-intent regex → already shipped in 3.11.30,
     fine to keep.
5. Phase 0 (M) starts: write the CI suite, add the bundle
   integrity grep, set up the cross-framework MCP parity test.
6. Phase 1 begins only after Phase 0 is green for one full day.

### K. Plan-driven workflow as the default contract

**This is the missing top-level abstraction.** Every other section
(A–J) supports it.

The Tina4 Plan module already exists in all 4 frameworks
(`plan_create`, `plan_add_step`, `plan_complete_step`, `plan_note`,
`plan_archive`). Today the supervisor uses it inconsistently — plans
get created, then forgotten across turns, and the user ends up
repeating their goal because the model lost the thread.

**Design rule:** every supervisor session operates against a plan.
The plan is the persistent goal that survives chat turns, page
refreshes, server restarts, and even chat-history loss.

#### Workflow contract

1. **First user prompt creates the plan.** When supervisor mode +
   no current plan + first send, the system auto-runs `plan_flesh`
   on the user's prompt: qwen turns "add a contact form with
   validation and email" into 6–10 concrete steps. The plan is
   created, set as current, and step 1 starts. The user sees the
   step list immediately in the Plan tab — no scope drift.
2. **Every turn executes against the active plan's current step.**
   The system prompt always includes "ACTIVE STEP: <step text>" at
   the top. The model's job is to advance that step, not to
   freelance.
3. **Step completes → `plan_complete_step` MUST be called in the
   same turn.** No batching at the end. A partial session leaves
   correct progress state. This is already in the prompt rules but
   not enforced — Phase 1 should add a hard guard: if a step is
   "done" by inspection (tool calls succeeded, files match the
   step description) and the model didn't tick the box, the
   framework auto-ticks it.
4. **Step blocked → `plan_note(why)` and stop.** No silent
   guessing. The user can intervene.
5. **All steps done → `plan_archive` and confirm with the user.**
   No starting a new plan automatically.
6. **Off-plan request mid-session →** model asks: "That's not in
   the current plan. Add a step or switch plans?" Two MCP calls
   wired to that decision (`plan_add_step` / `plan_switch_to`).

#### Plan as memory

The plan file is the *only* memory the supervisor needs across
sessions. Chat history is convenience. If the user closes the tab
and comes back tomorrow:

- The active plan loads (`plan_current`).
- The active step is the next thing to execute.
- Decisions ledger entries (Section J) tagged with `plan_name` give
  the audit trail of what was tried for each step.
- The model says "Resuming plan X at step Y. Last action was Z. Do
  you want to continue or revise?"

#### Plan-bound tools

Some tools should refuse to run without an active plan in
supervisor mode:

- `route_create`, `model_create`, `migration_create`,
  `template_create`, `image_generate(path=...)` — anything that
  mutates the project structure. Rationale: every artefact should
  trace back to a plan step. Violations get caught in the decision
  ledger ("Q&A mode write attempt: rejected").

In Q&A mode no plan is needed (read-only). In supervisor without a
plan, the system auto-creates one from the first prompt rather than
erroring — so the contract is "you always have a plan", not "the
system rejects you".

### L. Verification loop — execute, test, observe

The user noted "testing / execution is lacking". They're right.
Today the supervisor writes files; it does not verify the files
work. That gap is the difference between a chat that demos well
and a tool that ships features.

**Every step that produces a code change must be followed by an
automated verification step.** The plan's step list grows from
6 to ~12: each "do X" step is paired with a "verify X" step that
the system can execute without asking the user.

#### Verifications by artefact type

| Artefact | Verification step | MCP tool |
|---|---|---|
| Route file | `curl -s http://localhost:<port><path>` | new: `route_test(path, method, expected_status?)` |
| Migration | `migration_run` then check schema with `database_columns(table)` | existing: combine |
| Model | `database_query` selecting from the model's table | existing |
| Template | render with sample data, check no Twig errors | new: `template_test(name, sample_data)` |
| Image | check file exists + valid PNG header | new: `file_validate(path, type)` |
| Frontend | open in headless browser, check no console errors | new: `browser_check(url)` (Phase 5+) |
| Whole project | run the framework's test suite | existing: `tool` runner |

If verification fails, the model retries against the failure (real
error message in hand) rather than the user reporting "it didn't
work" 30 seconds later.

#### Step result encoded into the plan

`plan_complete_step` accepts an optional `verification` field:
```json
{
  "step_index": 3,
  "verification": {
    "ran": "curl -s http://localhost:7145/contact",
    "expected": "HTTP 200",
    "actual": "HTTP 200",
    "passed": true
  }
}
```

This pairs with the decisions ledger (Section J) — the verification
record is what makes "outcome: success" trustworthy.

#### Failure escalation

A verification step fails 3 times → the system stops, marks the
step `blocked` with `plan_note`, and asks the user to intervene.
No infinite-loop "let me try again" thrash.

### J. Decision / outcome ledger for post-analysis

Chat export (Section I) gets us a transcript. That's enough for
"what did we say?" but not for "what did we *learn*?" — and the
whole point of testing the dev-admin is to get smarter about how
to make it work.

We need a structured ledger that records, per turn:

- **Decision** — what was attempted: user's natural-language intent,
  the model's interpretation, the tool calls it emitted with args.
- **Outcome** — what actually happened: tool results, final state of
  the active file, error envelopes, time elapsed, whether the user
  retried / corrected / abandoned.
- **Verdict** (optional, user-set): 👍 / 👎 / 🤔 — was this what the
  user wanted? Free-text note for "why".

Each turn becomes one ledger entry. After 100 turns of testing across
PHP/Python/Ruby/Node, you can run analysis: which intents fail most?
which tools get hallucinated? which framework drifts hardest from the
canonical spec? *That* is what post-analysis is for.

#### Storage

Framework-side, durable. Browser localStorage is fragile (private
windows, cache clears, multi-tab races) — these records need to
survive a system reboot.

Path: `.tina4/decisions/<YYYY-MM-DD>.jsonl` — one ledger entry per
line, append-only. Auto-rotated by date. Easy to grep, easy to ship.

#### API

- `POST /__dev/api/decisions` — append one ledger entry. Body is the
  decision/outcome record (schema below). Returns `{id, ts}`.
- `GET /__dev/api/decisions?since=<iso8601>&limit=N` — paginated
  read. Default returns last 50 from today's file.
- `POST /__dev/api/decisions/<id>/verdict` — user-set thumb +
  optional note after the fact (e.g. clicking 👍 on a turn that
  worked). Updates the entry in place (rewrites the line).

#### Record schema (jsonl)

```json
{
  "id": "dec_a1b2c3d4",
  "ts": "2026-04-25T01:45:00.123Z",
  "session_id": "c239c512",
  "plan_name": "fix-hell-route",
  "framework": "php",
  "framework_version": "3.11.30",
  "bundle_hash": "abc1234",
  "model": "qwen2.5-coder:14b",
  "active_file": "src/routes/home.php",
  "intent": "call it index",
  "model_response_text": "To rename the home page route...",
  "tool_calls": [
    {
      "name": "file_move",
      "args": {"from": "src/routes/home.php", "to": "src/routes/index.php"},
      "ok": false,
      "error": "Unknown tool: file_move",
      "duration_ms": 12
    }
  ],
  "outcome": "failed",
  "outcome_reason": "all tool calls errored",
  "rag_hits": [{"source": "tina4-php/CLAUDE.md", "score": 0.78}],
  "verdict": null,
  "notes": null
}
```

Outcome enum: `success` | `partial` | `failed` | `cancelled` —
auto-derived from tool-call success rate + whether the user sent a
follow-up correction within 60s.

#### SPA surface

Two visible places:

1. **New "Decisions" tab** in the right-hand session panel
   (alongside Activity / Plan / Thoughts / Diff / Checks). Shows a
   filterable list of recent ledger entries with quick verdict
   buttons. Click a row → modal with the full record + the
   surrounding chat context.
2. **Inline verdict pills** under every assistant bubble in the
   chat: 👍 👎 🤔. One click sets the verdict. Optional second click
   opens a tiny note input ("why?").

#### Export

Same format as Section I's chat export, plus:

- **Download .jsonl** — raw ledger file, one record per line.
- **Download .md** — narrative report grouped by outcome ("12
  failures, 8 successes; common failure mode: hallucinated tools").

#### Why this matters

Without it we're guessing why the dev-admin breaks. With it we have
a regression suite and a training corpus. A new PHP release can be
graded against the same 50-decision test set: did we move from 60%
success to 80%?

This is independent of phases 1–5 and can ship in any wave — small
self-contained surface.

### I. Chat export for triage

The user can't fix what they can't analyse. Add a one-click chat
export so a transcript ships off as a single artefact for review,
issue-filing, or training-data harvest.

Shape:

- **Export button** in the chat panel header. Opens a small menu:
  - **Download .json** — full `chatHistory` array (user/assistant
    turns + tool calls + tool results), prefixed with metadata:
    framework, framework version, dev-admin bundle hash, active file,
    plan name, session id, timestamp, model name, RAG hits per turn.
  - **Download .md** — a human-readable markdown render of the same
    content (what the user sees in the bubbles, plus a header
    block). Suitable for pasting into a GitHub issue.
  - **Copy markdown** — same as above but to clipboard.
  - **Open as GitHub issue draft** — opens a new tab to
    `github.com/tina4stack/<repo>/issues/new?title=…&body=…` with
    the markdown pre-filled. The repo is selected by framework.

- **Endpoint**: client-side only (no server roundtrip). The chat
  history is already in `localStorage` per Gap N (chat persistence)
  so the export reads from there.

- **Privacy**: no automatic upload. Everything is user-initiated.
  Filenames default to `tina4-chat-<timestamp>-<framework>.json`.

- **Tool-call detail level**: include arguments (truncated to 4 KB
  per call) but always include the response shape. The model often
  fails because of arg shape mismatch; we need to see what it sent.

This is independent of phases 1–5 and can ship in any wave — small
self-contained client-side change.

### H. RAG on by default

`/rag/search` is queried per-turn for top-3 framework-doc passages.
If RAG is unreachable (env not set, network down) the call is a
non-fatal skip. We ship a tina4-rag instance per framework with
that framework's docs, so a Python project gets Python docs etc.
Already wired client-side; needs the rag instance pre-populated.

---

## Phasing

We do NOT try to land all of this in one release. Phases are
independently shippable and visible:

### Phase 1 — Make the basics seamless (1-2 days)
- F. Tool-availability block.
- D. Granular file-tree refresh.
- G. Consistent error envelope across all MCP tools.
- E.1, E.4 — `route_create` and `image_generate` MCP tools across
  all 4 frameworks.

Exit: user types "make a route /hello and an image of a cow", both
land in the right paths, file tree shows them immediately, server
serves /hello without restart needed (because Phase 2 is in flight
next).

### Phase 2 — Hot route loading (2-3 days)
- B. Per-framework route rescanning in debug mode.
- Tests: write a route file, curl it, no restart.

Exit: the user never has to ⌘+C / `tina4 serve` again during a
session.

### Phase 3 — Worktree-aware MCP (3-5 days)
- C. Session-scoped MCP path resolution.
- Apply truly stages worktree → project root via git apply.
- Diff tab shows real proposed-vs-current.

Exit: dirty state of the project doesn't change until Apply is
clicked. Cancelling a session leaves no trace.

### Phase 4 — Scaffold tools beyond the basics (1 week)
- E.2, E.3, E.5, E.6 — model/migration/template/middleware scaffold
  tools in all 4 frameworks.
- Spec doc lives in plan/MCP-SPEC.md as the source of truth.

### Phase 5 — RAG-everywhere (2-3 days)
- H. tina4-rag instances pre-populated with each framework's
  current docs.
- System prompt updated to instruct `docs_search` as the FIRST
  call when uncertain about an API.

---

## Anti-goals

We are NOT trying to:
- Replace the framework's CLI (`tina4 generate model X` still works
  and is documented).
- Make dev-admin work in production. It's `TINA4_DEBUG=true` only.
- Build a full IDE. We have CodeMirror for in-place edits and that
  is enough.
- Support every model on the planet. qwen2.5-coder:14b + SDXL Turbo
  + nomic-embed are the stack. Adding a model = a new MCP route.

---

## Success criteria for "seamless"

A new user clones a Tina4 PHP starter, runs `tina4 serve`, opens
`/__dev`, and says:

> "Add a contact form route at /contact that takes name, email,
> message, validates them, stores in a contacts table, and sends
> a confirmation email."

The system:
1. Creates `src/orm/Contact.php` (model).
2. Creates `migrations/<NN>_create_contacts.sql` and runs it.
3. Creates `src/routes/contact.php` with the validated POST handler.
4. Creates `src/templates/contact-form.twig` if asked for the GET form.
5. Wires the email send to `Tina4\Messenger::send`.
6. The route serves immediately without restart.
7. The file tree shows the new files immediately.
8. The plan tracks the steps as completed.

If any of those eight steps fails, the failure is one clear line
("contacts table create failed: column 'email' already exists") and
the model retries against that error.

That is what "seamless" means. Anything less than that is a bug we
file under one of phases 1–5 above.
