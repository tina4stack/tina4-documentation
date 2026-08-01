# Tina4 Decision Log (ADRs)

The durable record of architecture/API decisions across all four frameworks: WHAT we
decided, WHEN, and — the part that gets lost over months — WHY, and which alternatives we
rejected at the time. Search this before changing a contract. You may not silently
re-decide a logged decision: supersede its ADR explicitly (new entry, mark the old
`Superseded by ADR-NNNN`).

Conventions:
- One entry per decision, newest at the bottom. ID `ADR-NNNN` (zero-padded, monotonic).
- Anchor it in the code: a `tina4: ADR-NNNN` comment at the decision site, and the
  lock-in/regression test names the ADR ID. That makes "why is this a bool?" one grep.
- Status: Proposed | Accepted | Prototype-gated | Superseded | Rejected.

---

## ADR-0001 — Introduce an ahead-of-time "compile" layer across all four frameworks
- **Date:** 2026-07-26
- **Status:** Accepted (direction); **Prototype-gated** for execution (part 1 first, measured)
- **Scope:** all four backends (+ Frond); dev stays uncompiled, only production compiles.

**Question.** Maintainable source wants many small single-concern files (low MI, cheap
context for a human or an LLM). A fast runtime wants few boundaries and flat hot paths.
Which do we optimise for?

**Decision.** Both — via a compile layer. Author maximally maintainable source; ship an
optimised compiled artifact. "Maintainability means less code" for the human; "compiled"
for the machine.

**What gets compiled (scope, owner-clarified).** BOTH the application's `src/` (the
developer's routes, ORM models, templates, SCSS) AND the framework itself — everything that
ships. The compile step READS `src/` and EMITS a SEPARATE optimised build artifact; it NEVER
mutates or replaces `src/`. Source stays exactly as written, readable and in version control
(code is sacred). DEV runs `src/` raw — auto-discovered routes, source-rendered templates,
hot-reload, full visibility; only the SHIP/prod build compiles. At ship time: templates ->
precompiled native functions, SCSS -> CSS, routes -> a manifest (no boot-time filesystem
walk), the whole lot bundled/flattened + tree-shaken + a checksum manifest. "Compiled" means
different mechanics per language (Python bytecode + manifest, Node bundle, PHP opcache +
precompiled views, Ruby bootsnap + ERB) but the same principle: expensive prep done once,
before ship.

**Why (measured + precedent).**
- MEASURED this session: splitting `shop.py` (monolith) into a single-concern package
  won maintainability (MI 15.5 error -> cleared; per-edit context 604 -> 76 lines) but
  REGRESSED the hot path ~9% (485,937 -> 440,201 ops/sec, best-of-5) and doubled cold
  import (2.2 -> 4.5 ms). A compile step is how you keep the maintainability win without
  paying the runtime tax.
- PRECEDENT (this is how competitors get speed): Jinja2 compiles templates to Python
  functions; Laravel Blade compiles views + `artisan optimize` caches routes/config/
  container; Symfony compiles the DI container to PHP; Rails compiles ERB (bootsnap caches
  bytecode); Node bundles + tree-shakes. Node/Tina4 ALREADY compiles (the dist bundle) —
  this generalises that model to the three interpreted frameworks and makes all four
  consistent.

**Shape — three parts, sequenced by proven payoff + risk (owner chose all three):**
1. **Template + asset precompile** (Frond -> native code; SCSS precompiled). Highest,
   best-proven win (Jinja2/Blade/ERB do exactly this); most on-DNA; zero-dep feasible.
   **FIRST — the proof-of-pipeline.**
2. **Production bundle / flatten + config/route/container cache + tree-shake.** Recovers
   the import cost + shrinks the distribution (already a core Tina4 goal). Precedent:
   Laravel optimize / Symfony container / Node bundle. SECOND.
3. **Hot-path optimisation (recover the ~9%).** HONEST CAVEAT: competitors mostly do NOT
   hand-roll an app-code inliner — they lean on the runtime (PHP 8 JIT + OPcache, Ruby
   YJIT, V8, CPython bytecode). So FIRST measure whether *not over-decomposing hot
   functions* + the runtime JIT already recovers the hot path; build a real AST inliner
   only if measurement proves a residual gap. THIRD — measured before built.

**Dev vs prod (owner, non-negotiable).** DEV = full visibility: uncompiled, split,
hot-reloaded, with the debug overlay + live API index reading REAL source — the developer
sees everything, always. PROD = the single most-optimal compiled package, nothing more.
The compile step runs only at the dev->ship boundary, never inside the dev loop. Losing
dev visibility to gain prod speed is the failure mode; both must hold.

**Bonus benefit — integrity / tamper-detection (owner).** A compiled prod build is a
single, stable, hashable artifact (a sprawling interpreted source tree is not). Ship it
with a SHA256 checksum (+ optional signature) in a manifest; the loader / deploy step
verifies the checksum on boot and refuses-or-warns on mismatch, so tampering with shipped
code is detectable. This composes with the existing installer hardening (per-release
SHA256SUMS + code-signing, added after the Ampath MDR flag) and is a real reason the
compile layer earns its complexity beyond raw speed.

**Constraints / risks (must hold or the decision is wrong).**
- **Zero-dep:** the compiler is written in each language's stdlib (Jinja2 proves a
  pure-language template compiler is possible). No bundler dependency added to core.
- **Docs match code (First Principle):** a compiled artifact must map back to source —
  stack traces, the error overlay, and the live API index all read SOURCE. Source-maps or
  a source-first debug mode are mandatory, not optional.
- **Dev/prod parity:** dev runs uncompiled + hot-reloaded; only prod compiles. Two paths,
  both tested, identical behaviour (a parity test locks it).
- **Reversible:** if the prototype doesn't beat the tradeoff, we stop — this ADR is
  superseded, not quietly abandoned.

**Gate.** Prototype part 1 (Frond precompile) on the Python MASTER, prove it (a) beats the
current render bench with Carbonah, (b) keeps the full suite green with zero behaviour
change, before any 4-language parity work. Each part is its own scoped sub-plan; owner
approves scope before a fleet runs.

**Alternatives rejected.**
- *Optimise source only (no compile):* rejected — the measured ~9%/2× tax is the cost, and
  you can't have both small files and a flat runtime without a build step.
- *Never split (keep monoliths for speed):* rejected — that's the exact maintainability
  hole this whole program exists to close.

**Enforcement / links:** (fill as it lands — prototype branch, bench numbers, parity test)
**Supersedes:** none.

---

## ADR-0002 — Metrics engine moves into the tina4 Rust CLI (language-agnostic)
- **Date:** 2026-07-26
- **Status:** BUILT + INDEPENDENTLY VERIFIED (`feature/metrics-engine` @ `c88119e`, built in a
  linked worktree to avoid a concurrent session in the CLI tree). Parity EXACT vs Python
  metrics.py (MI to 0.1, CC/LOC/funcs), clippy clean, 167 tests green, +4.9 MB binary
  (tree-sitter grammars). Live `tina4 metrics --path tina4-js/src` works with no project.
  NOT merged/tagged — gated for a signed CLI release (owner). Was: worker off CLI `main`.
  Parser decided (owner): **tree-sitter** (per-language AST for py/php/rb/ts) for accuracy +
  formula parity (numbers match today's per-framework metrics so `--fail-on` thresholds
  carry). Accepted the CLI-binary-size cost for accuracy. First build = the standalone
  native `tina4 metrics` command only; wiring dev-admin/MCP to consume it + retiring the 4
  per-framework metrics modules is a follow-up. Plan: plan/v3/rust-metrics-engine.md.

**Question.** `tina4 metrics` today forwards to each framework's OWN metrics module and
needs a Tina4 project. That leaves two holes: (1) it CANNOT evaluate the frontend — it
forwards to a nonexistent `vite metrics`, so a tina4-js app has no maintainability gate at
all; (2) it cannot evaluate non-framework / arbitrary code. Where should metrics live?

**Decision.** Build a native, language-agnostic metrics engine INTO the `tina4` Rust
client. It scans source directly (per-file LOC, cyclomatic complexity, maintainability
index, coupling, offenders + `--fail-on`) for any supported language, with NO Tina4 project
and NO running framework required.

**Why.**
- Fixes the frontend + non-framework gap (evaluate tina4-js, or any repo, directly).
- **Retires the four oversized per-framework metrics modules** (PHP Metrics.php 1565 /
  Node metrics.ts 1390 / Ruby metrics.rb 1071 / Py dev_admin/metrics.py 796) — themselves
  offenders. One Rust engine replaces four drifting implementations = instant parity + less
  code (maintainability-means-less-code applied to our own tooling).
- Universal `--fail-on` gate everywhere, incl. the frontend that had none.
- Precedent in-house: Carbonah already does tree-sitter AST analysis across 12 languages —
  the CLI can use the same approach (don't reinvent the parser layer).

**Shape / open questions (resolve in the design sub-plan).**
- Canonical vs duplicate: the Rust engine is canonical; the frameworks' dev-admin dashboard
  + MCP `metrics` tools must CALL it (or a shared lib), not keep their own — else we
  recreate the drift we are removing.
- **Dev visibility preserved (owner, non-negotiable):** the dev-admin dashboard's metrics
  BUBBLE CHART (+ the offenders list) must keep its data. The Rust engine emits structured
  `--json` that the dev backend consumes to draw the bubbles — relocating the COMPUTATION
  must NEVER remove the dev VISUALISATION. The dev-admin chat/feedback bubbles + overlay
  stay live too. Dev = full visibility, always (ADR-0001).
  - **Consumption model (decided): pull on open + PUSH on code change (live).** dev-admin
    is NOT taught metrics as a new competency — it consumes a metrics payload. Initial load:
    the dashboard opens -> dev-admin shells `tina4 metrics --json` once -> renders the bubble
    chart. Live: the CLI is ALREADY the file watcher (it POSTs /__dev/api/reload on a real
    change); once it owns metrics it recomputes ONLY the changed file (tree-sitter parses one
    file in ms) and broadcasts a `{type:"metrics",...}` message on the SAME `/__dev_reload`
    WebSocket that already drives reload. The bubble chart updates in place as you edit — the
    offender you create/fix moves in real time. This is the FOLLOW-UP integration (all 4
    frameworks), NOT the first standalone-engine build.
- Parser: tree-sitter grammars per language (as Carbonah) vs lighter language-specific
  scanners. Keep the CLI zero-heavy-dep in spirit.
- Formula parity: the MI/complexity numbers must match today's per-framework output (or we
  deliberately re-baseline and say so) so the `--fail-on` thresholds carry over.
- Fixes the known Node bundle-scan defect for free (Rust scans real source, not dist).

**Gate.** Design sub-plan + owner scope approval before build. Sequence after the ahead-of-time
prototype proves out (shared CLI surface area; don't fork the CLI twice at once).

**Alternatives rejected.**
- *Fix each framework's metrics module in place (4x):* rejected — perpetuates four drifting
  implementations that are themselves offenders, and still leaves the frontend uncovered.
- *A separate metrics tool:* rejected — the `tina4` CLI is already the one tool devs run;
  metrics belongs there next to `serve`/`doctor`.

**Enforcement / links:** (fill as it lands)
**Supersedes:** none (partially subsumes the Node metrics scan-root fix in
plan/v3/maintainability-optimization-release.md Phase 0b).

---

## ADR-0003 — Program order: maintainability sweep first, THEN the compile layer
- **Date:** 2026-07-26
- **Status:** Accepted (owner)

**Question.** Two big programs are queued: the maintainability sweep (split the oversized
modules by concern, all four — plan/v3/maintainability-optimization-release.md) and the
ahead-of-time compile layer (ADR-0001). Which goes first?

**Decision (owner, refined).** Front-load the template compile + Frond parity, THEN the
maintainability sweep, THEN the rest of the compile layer.

**Why.**
- Compiling a monolith just ships a fast monolith — zero maintainability gain. Split before
  the broad compile so the source is clean + single-concern; the compiler then makes THAT
  fast. The value-creating refactor precedes the performance enabler.
- Template compilation is the biggest, best-proven single win (Jinja2 model) AND it is
  already in flight — front-loading it banks an immediate, consistent speed gain and clears
  the Frond-optimisation DRIFT (Python's engine is the only one with the token/expr caches).

**Order (refined by owner — template compile + Frond parity FIRST).**
A. **Frond template compilation (Python master).** Precompile templates to native functions
   (the prototype running now — a NEEDED deliverable, not a throwaway spike). Ship on Python
   once it beats baseline with the full suite green.
B. **Frond parity across all four.** Mirror the proven Python precompile to PHP/Ruby/Node so
   every Frond engine compiles templates the same way. This RETIRES the drifted ad-hoc Frond
   opts (token/expr caches were Python-heavy only) — the compile approach becomes the ONE
   unified Frond optimisation, not four hand-tuned piles.
C. **Code sweep (maintainability).** Split the oversized subsystems by concern, all four,
   Python master leads; gated per module; behaviour-preserving; suite green. Gated behind the
   Phase-0 prereqs: skills reframe proven + `tina4 metrics --fail-on` gate wired (grandfather
   + ratchet) so splits do not regrow. ADR-0002 (Rust metrics engine) is tooling — parallel.
D. **The rest of the compile layer (ahead-of-time).** ADR-0001 parts 2+3 — prod bundle /
   flatten, route/config/container cache, tree-shake, hot-path, the src-wide compile +
   checksum manifest, all four. Reclaims the sweep's interim hot-path tax and ships the
   optimal package.

Mapping to ADR-0001: its part 1 (template precompile) IS phases A+B here; its parts 2+3 are
phase D.

**Honest caveat — the interim tax.** The sweep REGRESSES hot paths (~9% measured) in the
window BETWEEN the sweep (Phase C) and the compile rollout (Phase D), because the compiler
that reclaims it does not exist yet. Mitigate: during the sweep split COLD code freely but
keep HOT functions tight (do not over-decompose a hot function into tiny cross-module calls
— ADR-0001 part 3); Carbonah-measure every split; a small, measured, temporary hot-path cost
is the accepted price of maintainability, reclaimed when the compiler lands. NEVER ship an
unmeasured regression. (Frond render is largely exempt from this window — its templates are
already compiled in Phases A+B, ahead of the sweep.)

**The Frond precompile prototype (running now) IS Phase A, not a throwaway spike.** It proves
the approach on the Python master; if it beats baseline with the full suite green it SHIPS
(Phase A) and is mirrored to the other three (Phase B). If it does NOT beat baseline, we
learn that before committing the rest — the whole compile bet rests on this proof.

**Alternatives rejected.** *Compile first, split after:* rejected (ships fast monoliths;
re-chases the compiler across changing source). *Interleave per subsystem:* rejected for
now (more moving parts; owner chose clean sequential phases).

**Supersedes:** none. Refines the gate in ADR-0001 and the phasing in
plan/v3/maintainability-optimization-release.md.

---

## ADR-0004 — Best implementation prevails: parity flows BOTH ways, and audits rank quality
- **Date:** 2026-07-26
- **Status:** Accepted (owner: "make it happen, the best implementation should prevail")

**Question.** Python is master ([[feedback_python_master]]): the other three mirror it. But
what happens when a MIRROR has the better implementation? And how would we even notice?

**Decision (two parts).**
1. **Best implementation prevails, regardless of which language found it.** Python stays the
   API-design master (naming, contracts, who-leads-a-feature), but when a mirror's
   IMPLEMENTATION is measurably better, the master ADOPTS it and the others follow. This
   extends [[feedback_python_master_governance]] ("if Python is broken, FIX Python, do not
   mirror the bug") to its logical completion: if Python is merely WEAKER, fix Python too.
2. **Audits must rank QUALITY, not just presence.** The parity audit as practised asks "does
   framework X have feature Y?" — a presence check that is structurally blind to "which of
   the four does it best". Every audit of a shared subsystem must now also compare the four
   implementations and name the best one (with evidence: perf numbers, complexity/MI,
   bounded-vs-unbounded, fallback coverage, test depth), then either adopt it everywhere or
   record why not.

**Why (both found in ONE session, neither visible to a presence-based audit).**
- **PHP's Frond has an AST layer; Python does not.** PHP parses tokens -> `parse($tokens)` ->
  AST, and compiles/inherits off the AST (`renderAst`, `resolveInheritance`). Python's
  compiler consumes a FLAT TOKEN LIST, so `compiler.py` must RE-DERIVE structure and
  duplicate the engine's token-grouping (`_collect_if`/`_collect_for` mirror
  `_handle_if`/`_handle_for` "EXACTLY" — its own docstring names the handlers as the source
  of truth). That duplication is fragile (change a handler, silently break the compiler) and
  is very likely WHY Python's compiler falls back on extends/block/include/macro — the
  constructs an AST models naturally. Both frameworks pass their suites, so a presence audit
  sees "Frond: yes / Frond: yes".
- **Python bounds its expression caches; PHP does not.** Python uses
  `lru_cache(maxsize=1024)`; PHP's `filterChainCache`/`dottedSplitCache` are plain unbounded
  instance arrays -> unbounded memory growth on dynamically-built expression strings. Same
  feature, one is a footgun.

**Actions.**
- **Python master adopts a parse-to-AST layer** (adopted FROM PHP). Goal: the compiler
  consumes a structured tree instead of re-deriving structure from tokens, which removes the
  compiler/engine grouping duplication AND should shrink the fallback set (extends/block/
  include/macro become compilable). Behaviour-preserving; the full Frond suite is the guard.
  Then the other three align to the same shape.
- **PHP bounds its expression caches** (adopted FROM Python) — cap them the way Python does;
  the PHP expr-cache port must NOT copy the unbounded pattern.
- **The audit program gains a quality-ranking pass** — for each shared subsystem, compare all
  four, name the best implementation + evidence, adopt or justify. Folded into
  plan/v3/maintainability-optimization-release.md.

**Alternatives rejected.** *Keep parity strictly one-way (master -> mirrors):* rejected — it
locks the family to the master's weakest choices and wastes work the mirrors already proved.
*Leave each engine as-is since all suites pass:* rejected — "it passes" is not "it is the best
of the four", and the drift compounds (this is how Frond's optimisations diverged in the first
place).

**Supersedes:** none. Extends [[feedback_python_master]] /
[[feedback_python_master_governance]]; the AST work reshapes ADR-0001 part 1's Python side.

---

## ADR-0005 - Frond tracks Twig and Jinja2, not Blade: fragment/push/stack/switch are dropped

**Date:** 2026-07-27. **Status:** Accepted. **Context:** 3.13.87 (Frond expression parity).

**Context.** A stale local copy of the maintainer skill documented `{% switch %}`,
`{% capture %}`, `{% embed %}`, `{% fragment %}` and `{% push %}/{% stack %}` as real Frond
tags. None are implemented. The question raised was whether `embed` and `fragment` are worth
building before the next release.

**What was measured**, not assumed:

- Every one of those tags **fails SILENTLY**. `{% switch %}` renders the matching case AND
  the default; `{% capture %}` prints its body inline and captures nothing; `{% push %}`
  renders at the push site instead of the stack; `{% fragment %}` passes its body through.
- The leak is not specific to those tags. **Any** unrecognised block tag renders its body and
  swallows the tag: `{% frobnicate 42 %}INNER{% endfrobnicate %}` -> `INNER`. The dangerous
  shape is a typo'd conditional: `{% iff user.is_admin %}<admin>{% endiff %}` renders the
  gated content UNCONDITIONALLY.
- `{% extends "card.twig" %}{% block title %}...{% endblock %}` produces byte-identical
  output to what `{% embed %}` would produce for the single-parent case.
- `{% set x %}...{% endset %}` - core syntax in BOTH Twig and Jinja2 - is broken identically
  in all four: prints inline, captures nothing.

**Decision.**

1. **`{% fragment %}`, `{% push %}/{% stack %}` and `{% switch %}` are DROPPED permanently.**
   They are Laravel Blade idioms. Frond is modelled on Twig and Jinja2, and neither has them
   (Twig has no `switch` in core; `fragment`/`push`/`stack` exist in neither). A developer
   arriving from either engine will not reach for them. The HTMX partial-render need behind
   Blade's `@fragment` is already served by Frond's `{% live %}`, which is strictly more
   capable. Do not re-open without a real user request.
2. **`{% embed %}` stays unimplemented for now.** It IS a genuine Twig tag, so it is the only
   one of the five with a real claim, but it is an ERGONOMICS gap rather than a capability
   gap (see the measurement above). Revisit on user demand.
3. **`{% set x %}...{% endset %}` WILL be implemented** in all four - it is core in both
   reference engines, so its absence is a compatibility bug, not a missing nicety.
4. **Unknown block tags must fail loudly**, at least in debug. A tag the engine does not know
   is far more likely a typo than an intention, and silently rendering the body of a
   mis-typed conditional is a security-shaped failure.

Items 3 and 4 are scheduled for **3.13.88**. They were deliberately kept OUT of 3.13.87:
that release was fully measured and verified, and bolting an untested cross-framework
behaviour change onto it would have traded a known-good release for an unverified one.

**Alternatives rejected.** *Implement all five for "Twig/Blade completeness":* rejected -
four of the five are not Twig, and shipping tags nobody asked for is exactly the speculative
complexity the reuse ladder exists to prevent. *Leave unknown tags silently leaking because
it is long-standing behaviour:* rejected - age is not correctness, and the `{% iff %}` case
can expose gated content.

**Supersedes:** none. The stale skill copy at `IdeaProjects/tina4-maintainer/` (not a git
repo, not the install source) is the origin of the confusion and must not be synced from.

---

## ADR-0006 - We own only OUR Dockerfiles; competitor images are official/community, cited

**Date:** 2026-07-27
**Status:** Accepted
**Owner decision.**

**Context.** Moving the framework benchmark from bare metal to Docker raised the question of
where every container comes from. The bare-metal harness it replaces compared Tina4's
built-in production server against competitors' DEV servers (`artisan serve`, `runserver`,
`WEBrick`, `php -S`), which is how a "110x faster than Laravel" claim ended up published.
Repeating that mistake in a new form - by hand-authoring the opponents' containers - was a
live risk.

**Decision.**

1. **We author and own exactly one kind of image: ours.** The four Tina4 images are built by
   `tina4 deploy docker`, the same path a user takes, so the benchmark dogfoods the real
   deploy route rather than a bespoke benchmark rig.
2. **Every competitor runs from its OWN official or best community image**, at latest, in
   production mode. We do not write their Dockerfiles.
3. **The image source and tag are published next to the number.** Not a footnote: the source
   is part of the result.
4. **Where no defensible image exists** - Django, Flask and Sinatra have no official Docker
   Hub image - name the community image chosen and why. If nothing defensible exists, record
   the row as **NOT MEASURED**.

**Why.** A benchmark in which we author the opponent's container is one nobody should trust,
and it hands critics a one-line rebuttal: "you configured it badly." Running each framework
from the image its own maintainers publish removes that argument completely, and is less work
than maintaining a dozen Dockerfiles we would then have to keep current. It also makes the
comparison reproducible by a third party, which our numbers have never been.

The honesty rule generalises: **an unmeasured row is acceptable, a self-built opponent is
not.** A gap in the table costs credibility once; a rigged comparison costs it permanently.

**Alternatives rejected.** *Hand-write production Dockerfiles for every competitor so the
stack is "identical":* rejected - identical-by-our-hand is not neutral, and the frameworks
disagree about what production means (php-fpm vs FrankenPHP, gunicorn vs uvicorn); imposing
one shape favours whoever happens to suit it. *Keep the bare-metal dev-server comparison and
just refresh the numbers:* rejected - re-measuring a meaningless comparison only makes it
look precise. Section 1 of each BENCHMARK.md is retired, not refreshed.

**Supersedes:** none. Implements the harness described in
`plan/v3/docker-benchmark-harness.md`; base-image work is tracked in
`plan/v3/docker-base-images.md`.

## ADR-0007 - Base images stay on official runtime images; we do not compile a runtime to shrink one

**Status:** accepted, 2026-07-28. Owner decision.

**Decision.** Each Tina4 base image builds `FROM` the runtime's own official image (or bare
Alpine plus a copied interpreter, where that is already the case) and we accept the resulting
floor. We do NOT compile a language runtime ourselves to reduce image size. Specifically,
`tina4-nodejs` stays on `node:24-alpine` with npm intact, at roughly 174 MB.

**Measured, on a native amd64 box (`du -sx /` inside the container, not the compressed size
Docker Hub reports):**

| image | empty base | our image | Tina4 adds |
| --- | --- | --- | --- |
| tina4-nodejs | node:24-alpine 165 MB | 174 MB | 9 MB |
| tina4-php | php:8.4-cli-alpine 109 MB | 112 MB | 3 MB |
| tina4-ruby | ruby:3.3-alpine 75 MB | 97 MB | 22 MB |
| tina4-python | alpine:3.23 9 MB | 41 MB | 32 MB |

Inside `tina4-nodejs`: the `node` binary alone is 123 MB, npm 19 MB, headers 7 MB, Alpine and
the rest 25 MB, the Tina4 framework 6 MB, the app close to nothing.

**Why.** The Node image looks like an outlier and is not one. Tina4 contributes 9 MB to it,
the smallest addition of the four in absolute terms. What is large is the runtime: one
statically linked binary carrying V8 and a full ICU build. There is nothing to prune, because
unlike Python there is no separable standard library to strip.

Two levers exist and both are rejected.

*Remove npm (saves 24 MB, base 165 -> 141).* Rejected because npm is precisely what makes
`FROM tina4-nodejs` plus `RUN npm install pg` work, which is the documented way a user adds a
database driver. Verified working at 185 MB. Trading that capability for 14% of the image is a
bad deal, and it would contradict the direction the other three images are moving in, where
shipping the ecosystem's package manager is the goal.

*Compile Node with small-icu or without-intl (saves perhaps 30 MB of the 123 MB binary).*
Rejected as too much effort to maintain. It means owning a Node build: tracking upstream
releases, rebuilding for every security patch on two architectures, and carrying the blame for
any behavioural difference between our Node and everyone else's. That is a permanent
maintenance liability for a one-time percentage. The official image is maintained by people
whose job it is, and it is the image every Node developer already trusts.

The same reasoning binds the other three. If a runtime's official image is large, that is the
runtime's size, and we report it honestly rather than fork the runtime to flatter a table.

**What we DO optimise.** Everything that is ours: no transpiler in production, no dev
dependencies, no optional database driver trees (SQLite only, add your own), no duplicated
framework copy, no build tooling left in a runtime stage. That is how tina4-nodejs went 288 MB
-> 174 MB, and it is where the remaining wins are.

**Reporting rule.** Always quote the on-disk figure from `du -sx /` inside the container, and
say so. `docker image inspect {{.Size}}` and the Docker Hub listing both report a COMPRESSED
size: Hub shows tina4-nodejs as 59 MB against 174 MB on disk. Quoting the smaller number
without qualification is flattering and wrong.

**Alternatives rejected.** *Publish a second "slim" Node tag without npm alongside the normal
one:* rejected - two tags with different capabilities is a support burden and an invitation to
pick the one that then cannot install a driver. *Switch to a distroless Node base:* rejected -
it removes the shell and package manager, so `FROM` plus add stops working, which is the same
objection as removing npm, only worse.

**Supersedes:** none. Related: `plan/v3/docker-base-images.md`, ADR-0006 (we own only our
Dockerfiles).

---

## ADR-0008 - A property name is a column name: no framework rewrites it silently

**Date:** 2026-07-28
**Status:** Accepted
**Owner decision:** yes, on the 98-feature audit's feature 17.

### Context

Feature 17 of the 98-feature audit measured how each framework turns an ORM property
name into a database column name. Verified by execution against real SQLite, one
model with `id`, `firstName` and `emailAddress`:

| | `firstName` becomes | mechanism |
| --- | --- | --- |
| php | **`first_name`** | automatic `camelToSnake` on every property |
| python | `firstName` | none - the property name is the column |
| ruby | `firstName` | none - `field_mapping` is `{}` by default |
| node | `firstName` | `fieldMapping[prop] ?? prop` |

Ruby's run is the clearest evidence the mapping is opt-in rather than automatic:
declaring `firstName` AND `email_address` in one class produced
`['id', 'firstName', 'email_address']` - both spellings verbatim, side by side.

So one model definition produces two different schemas. A database cannot be shared
between a PHP service and a Python service built from the same model, a migration
written once does not match both, and a doc example that works in one section of the
site is wrong in another.

The drift is usually invisible because each language's idiomatic property naming
happens to converge: PHP developers write camelCase and get `first_name`, Python and
Ruby developers write snake_case and get `first_name`. But the convergence is
accidental, not enforced - and Node breaks it even when the developer follows
convention, since idiomatic JS camelCase yields a camelCase column.

### Decision

**The property name IS the column name in all four frameworks, unless an explicit
map says otherwise.** PHP's automatic conversion becomes opt-in and defaults to OFF.

- `field_mapping` / `fieldMapping` exists in all four, empty by default, and
  `get_db_column(prop)` returns `mapping[prop]` or `prop` - Node's mechanism, which
  is one line and does nothing surprising, promoted to all four.
- PHP keeps its `camelToSnake` converter, exposed as `$autoSnakeCase`, **defaulting
  to `false`**. An existing PHP app sets one property to keep its schema.
- `camel_to_snake` / `snake_to_camel` become public helpers in all four, so opting
  in to snake_case columns is available everywhere rather than only in PHP.
- The four scaffolders generate snake_case column names. The convention belongs in
  generated code a developer can read, not in a silent rewrite they cannot see.

### Why false rather than true

`true` would preserve every existing PHP schema and cost nothing today. It was
rejected because it keeps the family permanently split on the one thing that must be
identical: a column name is more load-bearing than a method name, an env var or a
directory layout, all of which Core Principle 6 already requires to match. A schema
that differs by framework is the more expensive problem, and it gets more expensive
the longer it stands.

The cost is real and falls on the framework with the largest installed base. It is
accepted deliberately, with the mitigations below.

### Consequences

- **Breaking for PHP.** Any PHP app calling `createTable()` on a camelCase model
  emits different column names after this change. It needs a `Breaking:` changelog
  entry, a migration note, and the one-line opt-back-in (`$autoSnakeCase = true`)
  stated prominently in both.
- Additive for Python, Ruby and Node: they gain the explicit map, the public
  helpers, and a `get_property(column)` reverse resolver.
- A committed cross-framework schema fixture (one model, one expected column list,
  read by all four suites) turns the accidental convergence into an enforced
  contract. That fixture is the artifact that keeps this decision from eroding.

**Supersedes:** none. Related: `plan/v3/features/017-field-mapping.md`, ADR-0004
(best implementation prevails - Node's mechanism won here on explicitness, not on
being the master).

---

## ADR-0009 - One folder per feature, in all four frameworks, so a feature can be deleted

**Date:** 2026-07-28
**Status:** Accepted
**Owner decision:** yes, raised during the Phase 3 (Frond) audit.

### Context

Owner, on seeing that Python's Frond is three files in a `frond/` folder while the
other three are one or two flat files: "on python we need to keep each feature and
its sub files in the folder of its name", and then the reason - "if we can do this
for all the frameworks it means ripping out a module / feature becomes easier".

Measured today, the same feature has four different physical shapes:

| | Frond layout |
| --- | --- |
| python | `tina4_python/frond/` - `engine.py`, `parser.py`, `compiler.py` |
| php | `Tina4/Frond.php` + `Tina4/FrondCompiler.php` - flat, no folder |
| ruby | `lib/tina4/frond.rb` - one file, everything |
| node | `packages/frond/src/engine.ts` - one file, everything |

The consequence showed up immediately in the audit: rows 28 to 31 of the feature
matrix are lexer, parser, compiler and runtime as four separate features. They are
**separately auditable in Python only**. In the other three they are one file, so
there is nothing to measure per row and nothing to change per row.

### Decision

**Every feature lives in a folder named after it, in all four frameworks, and its
sub-files live inside that folder.**

```
python   tina4_python/<feature>/         engine.py, parser.py, compiler.py, __init__.py
php      Tina4/<Feature>/                Engine.php, Parser.php, Compiler.php
ruby     lib/tina4/<feature>/            engine.rb, parser.rb, compiler.rb
node     packages/<feature>/src/         engine.ts, parser.ts, compiler.ts, index.ts
```

Python already satisfies this and is the reference. The public entry point stays
where callers expect it (a barrel `__init__.py` / `index.ts`, a facade class, or a
`require` shim), so **this is a physical reorganisation, not an API change.**

### Why: removability is the point

The owner's reason is the decision's whole justification, and it is stronger than
tidiness. A feature that is one folder is a feature you can:

- **Delete.** `rm -rf` the folder, remove one registry line, and the framework still
  boots without it. That is the only reliable test that a feature is genuinely
  optional rather than entangled.
- **Lazy-load.** The lazy feature-loading work already shipped depends on knowing
  what belongs to a feature. A folder answers that; a flat file next to forty others
  does not.
- **Audit.** This programme measures per feature. A folder is a measurement boundary,
  which is why Python is the only framework where rows 28 to 31 can be told apart.
- **Own.** One folder is one thing to review, one thing to test, one thing to
  document.

It also serves the standing north star, "maintainability means less code": a
deletable feature is the strongest form of that, because the cheapest code to
maintain is code you removed.

### The enforceable test

A convention with no test is a preference. This one has an unusually good test:

> Delete the feature's folder, remove its registry entry, and the framework must
> still boot, serve a request, and pass the suite minus that feature's own tests.

Any feature that fails it is entangled, and the failure names the entanglement.
Recommend this becomes a CI job that removes each feature folder in turn - expensive
to run, so nightly rather than per-PR, and only over the features already migrated.

### Consequences

- **A large physical move in three frameworks, and no behaviour change.** Every file
  path in the framework changes for PHP, Ruby and Node. Imports, autoload maps,
  package exports and the docs all follow.
- **PHP's PSR-4 autoload and Node's `exports` map both need updating** - and Node's
  exports map has already broken importability once (nodejs#32/#353), so that one
  needs the import test that fix added.
- **Migrate feature by feature, not in one sweep.** Each move is its own commit with
  the removability test attached; a single giant rename is unreviewable and
  unbisectable.
- **New features are folder-shaped from the start.** The scaffolders emit the folder
  layout, so the convention holds without policing.
- Not a `Breaking:` change for users if the entry points hold, which is the
  constraint that makes it worth doing at all.

**Supersedes:** none. Related: ADR-0004 (best implementation prevails - Python's
layout won here), the lazy feature-loading work, and
`plan/v3/features/028-031-frond-engine.md`, where the split is a prerequisite for
auditing four features that currently share one file.

---

## ADR-0010: Routes beat files - static assets resolve AFTER route matching

**Status:** Accepted (owner, 2026-07-31). Feature 6.

### Context

Enumerating all four dispatchers found no agreed position for static-file
serving:

| | static asset |
| --- | --- |
| ruby | BEFORE route matching |
| node | BEFORE route matching |
| python | AFTER, in the fallback |
| php | none - `php -S` / nginx serve files before `index.php` runs |

The parked pattern said "stage 5, only when stage 3 found nothing", which matched
exactly one framework. Ruby's ordering carries a tell: it SKIPS the static check
entirely for `/api/` paths, a hack that exists only because file-first would
otherwise shadow API routes.

### Decision

**A registered route always wins over a file at the same path.** Static resolution
moves AFTER route matching, into the not-found fallback.

### Rationale

- **Code beats data.** A route is written and reviewed; a file in `public/` can
  arrive from a build step, an upload directory, or a careless deploy. Data must
  not silently override code.
- **It closes a shadowing hazard.** With file-first, dropping `public/api/users`
  shadows the `/api/users` route with no error anywhere. Ruby's `/api/` skip is a
  partial patch for exactly this; route-first removes the need for it.
- **PHP already behaves this way in effect.** The SAPI serves genuine static files
  before `index.php` is reached, so anything arriving at the framework is not a
  static file. Python does it explicitly. That is two of four already aligned.
- The two frameworks that change are Ruby and Node, which the owner confirmed are
  the less prominent deployments.

### Consequences

- **Breaking for Ruby and Node**, in the narrow case where a file and a route share
  a path. That case previously resolved to the file and now resolves to the route.
- Ruby's `/api/` static skip becomes dead code and is removed with the change.
- Needs its own positive/negative pair (`a_route_wins_over_a_file_at_the_same_path`
  / `a_file_is_still_served_when_no_route_matches`), not a silent edit inside the
  pipeline extraction.
- A genuinely static-heavy deployment should front the app with a web server, which
  is what PHP already relies on.

**Related:** ADR-0011, and `plan/v3/features/006-router-and-dispatch.md`.

---

## ADR-0011: HEAD keeps its per-runtime mechanism - outcome parity, not mechanism parity

**Status:** Accepted (2026-07-31, derived). Feature 6.

### Context

All four strip the body from a HEAD response, at opposite ends of dispatch:

- **Node** wraps `rawRes.write`/`end` EARLY, so every later path - explicit HEAD
  handler, GET fallback, 404, 405, 500 - drops its body without knowing it must.
- **Ruby and Python** strip content LATE, at their single return point.
- **PHP** does not handle it in dispatch at all.

### Decision

**No change.** The contract is the OUTCOME - a HEAD response carries no body,
whatever produced it - and the mechanism stays idiomatic per runtime.

### Rationale

Node writes to a stream, so there is no single exit to strip at; an early wrap is
the only way to catch every path. Ruby and Python RETURN a response from one
place, so a late strip at that point already guarantees the same thing. Forcing
one mechanism onto both would make one of them worse for no observable gain.

This is the audit's category 3 (runtime-idiomatic difference) applied honestly:
the decisive test is "could this framework produce the canonical outcome without
the divergence, using what its runtime offers", and the answer is that both
already do.

### Consequences

- The stage list names a `head_response` CONCERN, not a fixed position - Node
  satisfies it at the top, Ruby and Python at the bottom.
- A conformance test asserts the outcome (no body on HEAD across handler, 404, 405
  and 500 paths) rather than the mechanism, so neither implementation can drift
  without a red test.

**Related:** ADR-0010, and `plan/v3/features/006-router-and-dispatch.md`.

---

## ADR-0012: Settle a contract against real-world frameworks, not internal precedent

**Date:** 2026-07-31
**Status:** Accepted
**Context:** Feature 6 (router and dispatch), global middleware ordering

### Context

When the four frameworks disagree on a contract, the standing tiebreak has been
"Python is master". Applied to middleware ordering it produced the wrong answer.

The measured drift: does a global middleware run before or after the auth gate?

| Framework | Position | Global middleware sees a 401 |
| --- | --- | --- |
| Python | after the gate | no |
| Ruby | after the gate | no |
| Node | before the gate | yes |
| PHP | before the gate | yes |

Two-two. "Python is master" resolves it to "after the gate", and that resolution
was made and then reverted, because checking it against how the rest of the
industry builds the same pipeline showed the opposite:

| Framework | Where auth sits |
| --- | --- |
| Django | `CsrfViewMiddleware` ships BEFORE `AuthenticationMiddleware`; enforcement is `login_required`, a view decorator that runs after all MIDDLEWARE |
| Laravel | `HandleCors` is global (pre-routing), `VerifyCsrfToken` is in the `web` group (post-routing), `auth` is route middleware - last |
| Rails | Rack stack, then controller `before_action`s; `protect_from_forgery` conventionally precedes `authenticate_user!` |
| ASP.NET Core | `UseCors()` then `UseAuthentication()` then `UseAuthorization()` then endpoints; anything registered earlier runs on rejected requests |
| Express | one linear chain; `morgan` / `cors` / `rateLimit` are `app.use`d before `passport.authenticate` |

Unanimous, and the operational argument is decisive: a rate limiter that cannot
see failed logins cannot throttle brute force, and an access log that runs after
the gate silently omits every 401. Both are real bugs, and both are caused by
the "master-wins" answer.

### Decision

**Where a contract has a well-established real-world answer, that answer wins -
over internal precedent, over a majority of our own implementations, and over
the master framework.** "Python is master" remains the tiebreak for questions
that are genuinely internal (naming, argument order, which of two equivalent
spellings to keep). It is not a reason to ship an ordering the rest of the
industry has already rejected.

Before settling any cross-framework contract, check how Django, Laravel, Rails,
ASP.NET Core and Express solve the same problem, and record what was found. If
Tina4 deviates, the deviation is a deliberate, written decision - not an
accident nobody compared.

**Scope note:** this ADR settles the DECISION PROCEDURE. It does not by itself
authorise changing Python and Ruby: an ordering change is a behaviour change,
and it goes to the maintainer as an open question with the evidence attached
(see `plan/v3/features/006-router-and-dispatch.md`).

### Rationale

Tina4 is re-implementing a well-understood pipeline with less ceremony, not
inventing a new one. Where the shape is already settled, matching it is what
makes the framework predictable to someone arriving from Laravel or Django;
novelty there is a cost with no matching benefit. Deviation has to earn itself.

The lean part is real and is the point: Laravel needs three registries (global,
group, route) to express pre-routing / post-routing / per-route ordering. Tina4
gets the same three positions from ONE flag plus the existing route list. Same
semantics, less to learn - that is the streamlined wheel, and it only works if
the semantics are actually the familiar ones.

### Consequences

- The audit gains a step: for each contract, name the mainstream answer before
  choosing. A finding that does not cite one is incomplete.
- A "we already do it this way in three of four" argument no longer settles a
  contract on its own.
- The Python/Ruby vs Node/PHP middleware-ordering drift is recorded as OPEN,
  with the evidence, rather than silently resolved either way.

### Amendment, 2026-07-31: the standard outranks the frameworks

Applying this ADR to the OPTIONS `Allow` question (ADR-0013) exposed a missing
tier. "Compare against the real world" was read as "compare against the popular
libraries", which gave the wrong answer: five CORS libraries omit `Allow` on a
preflight, so the comparison said Tina4 was deviating - when RFC 9110 s9.3.7
says a successful OPTIONS response SHOULD carry it, and the frameworks' OWN
OPTIONS handlers (Django's `View.options()`, Express's router) already do.

The order of authority, most binding first:

1. **The standard.** An RFC, a W3C/WHATWG spec, the protocol itself. If a
   normative MUST or SHOULD covers the question, that settles it. Deviating
   from a MUST needs a very good reason; from a SHOULD, a written one.
2. **What the frameworks themselves do** - Django, Laravel, Rails, ASP.NET
   Core, Express. Their own built-in behaviour, not their plugins.
3. **The popular add-on library** for that concern. WEAKEST signal. A library's
   behaviour is often an artifact of where it is mounted rather than a
   decision - a component that short-circuits ahead of the framework skips
   whatever the framework would have done, and the difference is accidental.
4. **Internal precedent**, including "Python is master". Tiebreak only, for
   questions genuinely internal to Tina4 (naming, argument order).

So: check the standard FIRST. Only where it is silent does the framework
comparison decide, and a library's behaviour never outranks either.

**Related:** ADR-0010, ADR-0011, and
`plan/v3/features/006-router-and-dispatch.md`.

---

## ADR-0013: A CORS preflight carries Allow (RFC 9110 s9.3.7 conformance)

**Date:** 2026-07-31
**Status:** Accepted
**Context:** Feature 6 (router and dispatch), OPTIONS conformance

### Context

There are two OPTIONS paths and they were answering different questions:

- **bare OPTIONS** (no `Origin`) - protocol introspection, per RFC 9110 s9.3.7.
  Link checkers, monitoring probes, `curl -X OPTIONS`. Answered 204 with `Allow`.
- **CORS preflight** (`Origin` present) - a browser asking "may I send this?".
  Answered 204 with the `Access-Control-*` policy headers and NO `Allow`.

Measured 2026-07-31 on a route registered for GET and POST:

| Framework | bare OPTIONS | preflight |
| --- | --- | --- |
| Ruby | `Allow: GET, POST, HEAD, OPTIONS` | no `Allow` |
| Python | `Allow: GET, POST, HEAD, OPTIONS` | no `Allow` |
| Node | `Allow: GET, POST, HEAD, OPTIONS` | no `Allow` |
| PHP, CORS off | `Allow: GET, POST, HEAD, OPTIONS` | `Allow` kept |
| PHP, CORS **on** | **no `Allow`** | **no `Allow`** |

So the gap was in three frameworks, not the two originally recorded, and PHP
had a worse variant: `CorsMiddleware::beforeCors` short-circuited on ANY
OPTIONS with no `Origin` check, so registering it swallowed the RFC 9110 path
entirely. Node had that identical bug and was fixed earlier the same way.

### What the standard and the frameworks do

Per ADR-0012, checked first - and the check has two layers that disagree.

**The standard.** RFC 9110 s9.3.7 says a server generating a successful
response to OPTIONS SHOULD send header fields indicating what is applicable to
the target resource, naming `Allow` as the example. A preflight IS a successful
OPTIONS response, so the SHOULD applies to it.

**The frameworks' own OPTIONS handlers agree.** Django's
`View.options()` sets `Allow` from `_allowed_methods()`; Express's router
auto-answers an unhandled OPTIONS with an `Allow` header listing the route's
methods. Emitting `Allow` on an OPTIONS response is the normal thing.

**The CORS add-on libraries are where it goes missing.** `cors` (npm),
`django-cors-headers`, `rack-cors`, `asm89/stack-cors` (Laravel) and ASP.NET
Core's CORS middleware all answer a preflight without `Allow`. That is a
LAYERING artifact, not a considered decision: each is a separate component
sitting ahead of the framework's routing, so short-circuiting the preflight
also skips the framework's own OPTIONS handler and the `Allow` it would have
produced. Nobody chose to drop the header; the seam dropped it.

### Decision

**A CORS preflight response also carries `Allow`, derived from the router's
real method set for that path.** Tina4 owns both the CORS handling and the RFC
9110 OPTIONS handler in one dispatcher, so it costs exactly one header to
answer both questions at once, and the two OPTIONS paths stop disagreeing.

**This is conformance, not deviation.** It follows the RFC's SHOULD and matches
what the frameworks' own OPTIONS handlers already do. The add-on CORS
libraries are the outlier, and only by accident of where they sit. No
"deviation budget" under ADR-0012 is being spent here - the earlier framing of
this decision as a deliberate departure was simply wrong, because it compared
Tina4's dispatcher against a set of bolt-on libraries rather than against the
standard or against the frameworks themselves.

Also settled here:

- **`Allow` and `Access-Control-Allow-Methods` are not interchangeable.**
  `Allow` is what the RESOURCE supports (derived from the router). `ACAM` is
  what the CORS POLICY permits cross-origin (a configured static list -
  `TINA4_CORS_METHODS`, matching every mainstream library, which is why the
  static list is NOT a bug). They are different values on purpose: a policy
  naming DELETE on a GET-only route is still a 405, so a client reading only
  ACAM is misled. A conformance test asserts they differ.
- **Only a real preflight short-circuits.** A bare OPTIONS belongs to the RFC
  9110 handler in all four.
- **`Router::methodsAllowedForPath` is public in PHP**, as its equivalent
  already was in the other three.

### Consequences

- Four new conformance suites, same case names, each proven red against the
  unfixed code: `a bare options carries allow`, `a cors preflight also carries
  allow`, `a real preflight is still answered by cors`, `allow describes the
  resource not the policy`.
- Non-breaking: an added response header on a 204. No existing header changes
  value, and CORS behaviour is untouched.
- The comparison lesson generalises: when checking "what does the real world
  do" (ADR-0012), compare against the STANDARD and against the frameworks'
  own behaviour, not only against the popular add-on for that concern. A
  library's behaviour can be an artifact of where it is mounted.
- PHP's `CorsMiddleware::isPreflight(string $method)` still returns true for
  ANY OPTIONS regardless of `Origin`, so its name overstates what it checks.
  The real short-circuit decision no longer uses it, and eight existing tests
  pin the current meaning. Recorded as a naming finding, not renamed here.

**Related:** ADR-0012, and `plan/v3/features/006-router-and-dispatch.md`.

## ADR-0015: Route precedence - does a specific route beat a catch-all? (OPEN)

**Date:** 2026-07-31
**Status:** Accepted, 2026-07-31. Filed OPEN, then decided the same day once the
four citations were verified against primary documentation. **Outcome: no change
to route resolution.** A follow-on visibility item is scheduled (see below).
**Context:** Feature 6 (router and dispatch), follow-on. Surfaced by the feature
8 (health check) audit.
**Number note:** ADR-0014 is claimed by the `feature/audit-007` branch
(middleware return-value contract) and is not merged yet. This takes 0015 so the
two cannot collide whichever lands first.

### How this surfaced

The feature 8 audit found a Ruby app serving its CMS catch-all on `/__health`.
A container health check therefore got the app's page instead of the health
payload, against a perfectly healthy app. Two separate causes, both already
FIXED in `tina4-ruby 0ad2de1`:

1. `find_route` built candidates as `ANY + method`, so an ANY route always won
   regardless of registration order.
2. `initialize!` ran `auto_discover` before `register_builtin_routes!`, so every
   app route registered ahead of the framework's own.

What remains open is the design question underneath, which the fix deliberately
did not answer.

### Measured, all four, 2026-07-31

Registering `any("/{slug}")` and `get("/probe")` in both orders, then matching
`GET /probe`:

| framework | ANY registered first | GET registered first |
| --- | --- | --- |
| Ruby (before the fix) | ANY wins | ANY wins |
| Ruby (after the fix) | ANY wins | GET wins |
| Python | ANY wins | GET wins |
| PHP | ANY wins | GET wins |
| Node | ANY wins | GET wins |

All four now agree: forward registration order, first match wins.

### The open question

Should a specific route beat a catch-all REGARDLESS of registration order?

Today the answer is no, uniformly. A catch-all registered before a specific
route still shadows it. That is defensible, and it is what the fix standardised
on, because it was the 3-of-4 behaviour and it fixed the reported bug.

### What the real world does - VERIFIED against primary documentation

The prior belief going in was that specificity-wins is the industry norm. That
belief was wrong. Each of the four was checked against its own documentation on
2026-07-31, not against a recollection and not against a blog post:

- **Django** - CONFIRMED, normative sentence: "Django runs through each URL
  pattern, in order, and stops at the first one that matches the requested URL,
  matching against `path_info`." The docs go further and tell you to exploit it:
  "Feel free to exploit the ordering to insert special cases like this." No
  specificity ranking anywhere.
  Source: https://docs.djangoproject.com/en/stable/topics/http/urls/
- **Rails** - CONFIRMED, normative sentence: "Order matters in the `routes.rb`
  file. Rails routes are matched in the order they are specified." The guide's
  own example shows `resources :photos` declared first swallowing a later
  `get 'photos/poll'`, and instructs you to move the specific route above it.
  Source: https://guides.rubyonrails.org/routing.html
- **Express** - CONFIRMED in direction, WEAKER in kind. The docs demonstrate it
  by example rather than stating a rule: of two handlers on the same path, "The
  second route will not cause any problems, but it will never get called because
  the first route ends the request-response cycle." Definition order decides, and
  no specificity ranking appears anywhere in the routing or middleware guides.
  Label this honestly when citing it: supported by primary docs, but not by a
  single normative sentence the way Django and Rails are.
  Source: https://expressjs.com/en/guide/using-middleware.html
- **ASP.NET Core** - CONFIRMED as the outlier, and more strongly than expected.
  It has explicit route-template precedence: literal segments beat parameter
  segments, more segments beat fewer, constrained parameters beat unconstrained,
  catch-all parameters rank last. And registration order is explicitly NOT a
  factor: "The order of operations inside UseEndpoints doesn't influence the
  behavior of routing", and endpoint routing "Doesn't provide ordering
  guarantees. All endpoints are processed at once." Ambiguous matches throw.
  Source: https://learn.microsoft.com/en-us/aspnet/core/fundamentals/routing

**Three of four resolve by registration order. Tina4 already matches the
majority**, and has since `tina4-ruby 0ad2de1` brought Ruby into line.

Worth recording for anyone tempted by the ASP.NET model later: it is not a
tiebreak bolted onto first-match. It is a different architecture - every
endpoint is evaluated, candidates are ranked, and an unresolvable tie is an
exception rather than a silent winner. Adopting it is a rewrite of route
resolution in four languages, not an added comparison.

### The argument that specificity may still be right FOR US

There is one real difference that the mainstream comparison does not capture.
In Django and Rails the developer WRITES the order, in one file, explicitly. In
Tina4 the order comes substantially from auto-discovery walking a directory, so
"registration order" is partly a filesystem-traversal detail the developer never
chose and cannot see. An ordering that is explicit and reviewable in Django is
implicit and invisible here.

That asymmetry, not a general appeal to specificity, is the strongest case for
ranking candidates instead of taking the first match. It should be weighed
against the cost: a ranking rule is more code in four languages, and it makes
route resolution harder to reason about than "first one wins".

### Options

1. **No change.** Registration order everywhere, as it is now. Cheapest, matches
   the mainstream if the verification above holds, and the reported bug is
   already fixed. Documentation must then state plainly that a catch-all
   registered before a specific route shadows it.
2. **Method specificity only.** A method-specific route beats an ANY route on
   the same path, regardless of order. Path matching stays first-match.
   Narrower than full specificity and addresses the actual failure mode seen.
3. **Full specificity ranking.** Literal segments beat parameterised, more
   specific patterns beat less. Closest to ASP.NET Core. Most code, biggest
   behaviour change, hardest to explain.

### Decision

**Option 1. No change to route resolution.** Forward registration order,
first match wins, in all four. Three of the four frameworks we measure against
do exactly this, and the fourth achieves its ordering by an architecture we are
not adopting. Tina4 is already conformant.

The specificity idea is rejected on its own merits, not merely on precedent:
it is more code in four languages, it makes resolution harder to reason about
than "first one wins", and the failure it was proposed to fix has already been
fixed at its real cause.

### The one thing the citations do NOT settle

Django, Rails and Express all have the developer WRITE the order, explicitly,
in one file they can read top to bottom. Tina4 does not: order comes
substantially from auto-discovery walking a directory, so it is a
filesystem-traversal detail nobody chose and nobody can see. The mainstream
comparison establishes that registration order is the right RULE; it says
nothing about our order being invisible.

That is the real complaint behind the original bug report, and it survives this
decision.

### Scheduled follow-on: make the order visible

Filed as its own item, not built here. Two pieces, both additive and neither
touching resolution:

1. A startup warning when a catch-all is registered ahead of a route it would
   shadow, naming both routes. Cheap, and it converts a silent shadowing into
   an obvious one.
2. Resolution order shown in `tina4 routes` output, so "which route wins" is a
   question you can answer without reading the router.

This targets invisibility directly and costs far less than a ranking rule.

### Consequences

- No code change. All four already behave this way.
- The documentation must state plainly that a catch-all registered before a
  specific route shadows it, and that discovery order is registration order.
- `tina4-ruby 0ad2de1` (the parity fix and the built-ins-register-first fix)
  stands as the resolution of the reported bug.
- Anyone reopening this should read the ASP.NET note above first: that model is
  a rewrite, not a tweak.

**Related:** ADR-0010 (routes beat files), ADR-0012 (settle a contract against
real-world frameworks), and `plan/v3/features/006-router-and-dispatch.md`.
---

## ADR-0014: A middleware's return value is the contract; response state is a legacy path

**Date:** 2026-07-31
**Status:** Accepted
**Context:** Feature 7 (middleware pipeline), return-value handling and hook scope

### Context

The four frameworks agreed on what a middleware IS and disagreed on what it
RETURNS. Measured against the live source in all four:

| return value | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| the `[req, res]` pair | rebind, continue | rebind, continue | rebind, continue | rebind, continue |
| a Response object | crash (TypeError, 500) | short-circuit | continue | continue |
| `false` | crash (TypeError, 500) | short-circuit, 403 | short-circuit | continue |
| nothing (`None`/`null`/`nil`) | continue | continue | continue | continue |

Only the first row was a contract. The other three were four accidents.
Python's crash is literal: `_run_before_middleware` did
`if result is not None: request, response = result`, so returning `false`
raised `TypeError: cannot unpack non-sequence bool` and the developer got a
500 with no clue why.

Three of the four also short-circuited when a before hook left the response at
status >= 400, whatever it returned. Ruby nested that check inside the
"did it return a 2-element array" branch, so a hook that set 403 and returned
`nil` let the handler run anyway. That was proven with a real Request and
Response, not read from the source.

### The rule that decides it

Per ADR-0012, check the real world first. The real world splits:

- **Django** is return-value driven. A middleware that returns an
  `HttpResponse` short-circuits; anything else continues.
  (docs.djangoproject.com, topics/http/middleware.)
- **Rails** ignores the return value. A `before_action` short-circuits on
  response STATE. `AbstractController::Callbacks::ClassMethods` states it
  verbatim: "If the callback renders or redirects, the action will not run. If
  there are additional callbacks scheduled to run after that callback, they are
  also cancelled." Note the Action Controller GUIDE is silent on this; the API
  doc is the citation.
- **Laravel** and **Express** are return/next driven.

No unanimous answer, so ADR-0012's ladder does not settle this one and it was
decided on the merits.

The deciding argument is the redirect. A status >= 400 state check cannot
express one. An auth middleware that sets 302 to `/login` and expects the
handler not to run gets the handler run anyway, because 302 is not >= 400.
Any rule built on error status alone has that hole in it, and the hole is in
the most common middleware anyone writes.

### Decision

**One table, all four frameworks, every hook, every scope.**

| return value | behaviour |
| --- | --- |
| a Response object | SHORT-CIRCUIT. That object IS the response. Any status. |
| the `[req, res]` pair | rebind both, continue |
| `false` | SHORT-CIRCUIT. Send the response as set; if it is still default or empty, send 403. |
| nothing (`None`/`null`/`nil`/`undefined`) | continue |

**Returning a Response is the primary rule.** It is explicit, it is
language-neutral, and it covers every status code including the 3xx that the
state check cannot reach.

**The status >= 400 state check is retained as a legacy compatibility path,
not as the mechanism.** Three of the four already had it, and removing it
would break error middleware that sets 403 and returns nothing. It is
documented in the code as compatibility, so nobody mistakes it for the design.

Also settled here:

- **Per-route class middleware runs both phases.** A class attached to a route
  runs its `before_*` hooks AND its `after_*` hooks, in every framework. Python
  already did. PHP ran only `before*`, so a route-scoped `after*` was dead code.
  Ruby called `mw.call(request, response)` on the class, which raised
  `NoMethodError`. Node invoked it as a plain function, so it was inert. An
  after hook that never runs leaks the release half of an acquire, never stops
  a timer its before half started, and never logs the response half of a
  request.
- **Before hooks run base class first, then subclass.** Measured: Python and
  Ruby already do; PHP returned derived-then-base on PHP 8.5.7, contradicting
  its own docblock; Node dropped inherited hooks entirely because
  `Object.getOwnPropertyNames` returns own statics only.
- **After hooks keep the same order as before hooks** for now. Zero of the four
  unwind them across an inheritance chain today, so no unwind is invented here.

### Consequences

- **Breaking, and the risk differs per framework.** In PHP and Node, middleware
  that is inert today starts executing. In Ruby, the same call raises
  `NoMethodError` today, so it is broken-to-working. In Python, returning
  `false` stops being a 500. Each repo's changelog carries a `Breaking:` line
  saying which of those applies to it.
- Four regression suites with identical case names, each proven red before the
  fix, including `a before hook that returns a redirect response short
  circuits` (the case that forces the Response rule) and `a before hook that
  sets 4xx and returns nothing skips the handler` (the Ruby security hole).
- **Not decided here, deliberately:** the after pass runs in REGISTRATION order
  across middleware classes in all four, so any acquire/release pair spanning
  two middlewares nests WRONGLY. That is a latent correctness bug, not a
  stylistic deviation, and it is uniform across the four rather than a parity
  defect. It changes behaviour in all four at once, so it gets its own ADR
  instead of riding along in a parity pass that is already carrying three
  breaking changes. The concrete failure, the measurements, and its
  interaction with the ADR-0012 pre/post-match split are recorded in
  `plan/v3/features/007-middleware-pipeline.md`.

**Related:** ADR-0012, and `plan/v3/features/007-middleware-pipeline.md`.
---

## ADR-0016: Liveness is process-only; readiness is a separate endpoint

**Date:** 2026-07-31
**Status:** Accepted
**Context:** Feature 8 (health check endpoint)

### Context

Docker and Kubernetes are the default deployment target, so the health endpoint's
consumer is an orchestrator, not a human. Measured across the four frameworks at
3.13.94 (real servers, real HTTP), the endpoint had diverged badly:

| | `/health` | `/__health` | reports failure | probes a dependency |
| --- | --- | --- | --- | --- |
| python | 200 | 200 | 503 on a route error | no |
| php | 200 | 404 | never | no |
| ruby | 200 | 200 | never | no |
| node | 200 | 200 | never | no |

No framework probed any dependency. Python was the only one that could report
failure at all, and it reported the wrong thing:

```
GET /health                       -> 200
GET /boom (a route that raises)   -> 500  and writes data/.broken/*.broken
GET /health                       -> 503
...process restarted...
GET /health                       -> 503   nothing clears the sentinel
```

One ordinary bad request took the endpoint down permanently, across restarts.

### What the authorities say

Per ADR-0012, checked before deciding.

**Kubernetes is unambiguous, and the body is invisible to it.** An `httpGet`
probe succeeds when the status code is `>= 200 and < 400`
(https://kubernetes.io/docs/concepts/workloads/pods/probes/, "Check mechanisms").
The `HTTPGetAction` API has five fields (`path`, `port`, `host`, `scheme`,
`httpHeaders`) and no body-matching field of any kind, so `200` carrying
`{"status":"unhealthy"}` reads as healthy. The two failure modes differ
completely: for liveness "the kubelet kills the container, and the container is
subjected to its restart policy"; for readiness "the kubelet marks the container
as not ready, and the Pod stops receiving traffic".

**The IETF health+json draft agrees on the code mapping, and it is NOT a
standard.** `draft-inadarei-api-health-check-06` expired 2022-04-19 and carries
the disclaimer "This I-D is not endorsed by the IETF and has no formal standing
in the IETF standards process". Cite it as a de-facto convention only. It says:
"For 'pass' status, HTTP response code in the 2xx-3xx range MUST be used. For
'fail' status, HTTP response code in the 4xx-5xx range MUST be used." It names
`ok` as an explicitly acceptable alias for `pass`, which is what Tina4 already
emits.

**The frameworks that ship a health route deliberately probe nothing.**

| framework | path | probes dependencies |
| --- | --- | --- |
| Rails 7.1+ | `/up` | no, deliberately |
| Laravel 11+ | `/up` | no |
| Django | none shipped | n/a |
| Express | none shipped | n/a |
| Spring Boot Actuator | `/actuator/health` | yes, and maps DOWN to 503 |
| ASP.NET Core | mapped by the app | yes, Unhealthy 503, Degraded 200 |

Rails states the reasoning Tina4 needs, in its own guides: "if a third-party
service is down and your application reports that it's down due to the
dependency, your application may be restarted unnecessarily". DHH, in the pull
request that added it: "I'm not convinced that it's a good idea to have the app's
health status, which determines whether it'll get yanked from an LB pool, for
example, dependent on secondary storage. Those elements should have their own
health checks."

Spring and ASP.NET, which do probe dependencies, both map only hard-down to a
non-2xx and keep a degraded state at 200.

### Decision

**A failing health check returns a non-2xx status.** 503. Never 200 with a
failure reported in the body, because nothing reads the body.

**Liveness and readiness are separate endpoints, because they mean opposite
things.** A liveness failure restarts the container; a readiness failure
withdraws traffic and restarts nothing. A dependency check on liveness turns one
database outage into a fleet-wide restart loop that cannot fix the database.

- **`/__health` is LIVENESS and checks the process only.** No database, no cache,
  no queue, no outbound network. It answers 200 whenever it runs; the response
  itself is the signal. The only way it fails is that the process cannot answer,
  which is exactly what a restart repairs.
- **Readiness is a separate endpoint** that probes configured dependencies and
  returns 503 when one is down. **Specified here, not built.** It is scheduled
  separately.

**A recorded route error drives neither.** A restart cannot fix a route file that
fails to import, so it is not liveness. One broken route should not withdraw all
traffic from an app whose other routes serve, so it is not readiness. It belongs
on the dev dashboard, which already reads `data/.broken` in all four frameworks.

**The body is exactly four keys, identical in all four frameworks:**

```json
{"status": "ok", "version": "3.13.94", "uptime": 12.34, "framework": "tina4-python"}
```

`uptime` is seconds as a float to 2 decimal places. Note the authority here is
thinner than it looks: **no standard prescribes `uptime_seconds`**, and the one
convention that covers JSON health bodies does the opposite, keeping the key bare
as `uptime` and putting the unit in a sibling `observedUnit: "s"` field
(draft-inadarei-06 s4.4). The Prometheus base-unit suffix convention
(https://prometheus.io/docs/practices/naming/) governs metric names in a
line-delimited text format, not JSON. So `uptime` as a float wins on the only
applicable convention as well as on internal consistency: three of four
frameworks already emitted it, and the published docs documented it.

**`/health` is always registered alongside the configured path.** Setting
`TINA4_HEALTH_PATH` adds a path; it never removes one. A probe written before the
env var existed keeps working.

### Consequences

- Python's health body changes shape. `Breaking:`, with a migration note.
  `uptime_seconds` (int) becomes `uptime` (float); `framework` `"tina4py"`
  becomes `"tina4-python"`; `errors` and `latest_error` are removed; the 503 path
  is removed. Error diagnostics move to the dev dashboard.
- PHP gains `/__health` and a permanent `/health` alias. Purely additive.
- Ruby's registration guard is removed; it could be suppressed entirely by a
  catch-all route.
- All four now answer both paths, so one probe definition works against any Tina4
  app.
- Readiness, and a `HEALTHCHECK` instruction in the Dockerfiles, are specified
  and outstanding. Neither is built here.

**Related:** ADR-0012 (the decision procedure), ADR-0015 (route precedence -
a catch-all ANY route shadowed the health route at dispatch; found by this audit,
fixed separately because it is a framework-wide route contract, not a health
concern), and `plan/v3/features/008-health-check.md`.
## ADR-0017: Graceful shutdown - drain in-flight requests, bounded, exit 0

**Date:** 2026-07-31
**Status:** Accepted
**Context:** Feature 9 (graceful shutdown), signal handling in all four frameworks

### Context

A container orchestrator sends SIGTERM and SIGKILLs after a grace period.
Dropping in-flight requests on SIGTERM is a production defect, not a style
question. The four frameworks disagreed on every part of it.

Measured 2026-07-31 on macOS 26.5.2 (Darwin 25.5.0), arm64. Real spawned
server, real request to a route occupying the handler for 2.0s, real signal
0.6s in, exit code read from `waitpid`:

| Framework | in-flight request | connection after signal | exit | drain |
| --- | --- | --- | --- | --- |
| Python | COMPLETED (200) | refused | 0 | 1.42s |
| PHP | COMPLETED (200) | accepted, then RESET | 0 | 1.46s |
| Ruby | COMPLETED (200) | accepted, 503 JSON | 0 | 1.43s |
| Node, plain `startServer()` | **DROPPED** | refused | **143** | 0.15s |
| Node, one `background()` task | n/a | still serving 200 | **never exits** | **HUNG** |

SIGINT matched SIGTERM in every row. SIGHUP was trapped nowhere.

A measurement trap worth recording: a signal makes a blocking `sleep`/`usleep`
return early with EINTR, so PHP's handler first appeared to drain in 0.604s
carrying the correct body. It had only been interrupted. Every slow route in
these suites is now wall-clock bounded so an interrupted sleep cannot
masquerade as a completed handler.

### What the standard and the platforms do

Per ADR-0012, checked before deciding.

| Authority | Behaviour |
| --- | --- |
| Kubernetes | SIGTERM, then SIGKILL at `terminationGracePeriodSeconds` (default 30). The period covers the preStop hook AND shutdown together. |
| Node `server.close()` | Documented as ASYNCHRONOUS: stops accepting, "keeps existing connections", fires the callback once all connections end. |
| Gunicorn | `graceful_timeout` default 30s. TERM waits for workers to finish current requests. |
| Puma | TERM: "the worker will attempt to finish then exit". `force_shutdown_after` defaults to `:forever`. SIGHUP reopens log files, else behaves like INT. |
| Exit codes | `128 + signum` is a SHELL abstraction for a process killed BY a signal. It is not POSIX, and not what a process that traps and exits cleanly reports. |

### Decision

**One graceful shutdown contract in all four frameworks.** On SIGTERM or
SIGINT: stop background tasks, close live WebSockets with RFC 6455 code 1001,
close the listeners, drain in-flight requests within the budget, close the
database, exit 0.

- **`TINA4_SHUTDOWN_TIMEOUT`, default 30 seconds, all four.** Ruby's existing
  spelling and default; Python, PHP and Node adopt it. The authorities split
  (Gunicorn bounds at 30, Puma waits forever), so the tiebreak is operational:
  30 matches the Kubernetes default grace period, so the drain finishes just
  before SIGKILL. An unbounded wait does not avoid truncation, it only means
  SIGKILL truncates with no clean exit and no log line naming what was still in
  flight. An invalid or negative value warns and falls back to 30, never 0.
- **Exit 0 on a clean drained shutdown, WHEN THE FRAMEWORK OWNS THE SOCKET.**
  Three frameworks already did; Node reported 143 only because nothing handled
  the signal. Gunicorn and Puma both halt 0 on a handled TERM. Operationally
  decisive: 143 is recorded as signal-killed and counts as failure for a
  Kubernetes Job or `restartPolicy: OnFailure`.

  **AMENDED 2026-07-31, and this clause was wrong as first written.** It said
  "exit 0" flat. Measured on the production path, uvicorn exits `-15`/143 BY
  DESIGN - `Server.capture_signals` restores the default handler and re-raises
  the signal, so a supervisor sees "terminated by SIGTERM", and uvicorn's own
  log confirms the drain completed first. Puma behaves the same way unless
  `raise_exception_on_sigterm` is turned off.

  Forcing 0 there would mean overriding what the production server deliberately
  does, which the mechanism-vs-outcome split below explicitly forbids. So the
  contract is:

  | who owns the socket | exit code |
  | --- | --- |
  | the framework's own server | **0** |
  | a third party (uvicorn, Puma, hypercorn, granian) | **`128 + signum`**, whatever it chooses |

  This is the one clause where the OUTCOME is genuinely not shared, and saying
  so is better than asserting a number that misreports what happened. The
  drain, the timeout and the resource close ARE shared - only the exit code
  follows the owner. Tests assert `-signal.SIGTERM` on the production path and
  state why, rather than being written to the flat rule and quietly skipped.
- **RFC 6455 close code 1001 ("going away") to every live WebSocket.** This is
  conformance: s7.4.1 defines 1001 for a server going down. A client told 1001
  reconnects on a schedule; a vanished socket looks like a network fault and
  errors. A WebSocket never "finishes" the way a request does, so it is not
  drained - the close frame goes first, then the listeners close.
- **The listener closes FIRST, so a late connection gets a clean refusal.**
  Three frameworks did three different things and they cannot all be right.
  PHP's accept-then-RESET is the worst: the client sees a transport error
  indistinguishable from a network fault. Ruby's 503 is more informative but
  keeps the listener open. All four converge on Python's refusal, which is what
  a load balancer already handles correctly.
- **SIGHUP stays untrapped**, terminating the process by default disposition.
  Puma uses it to reopen logs and Gunicorn to reload config; neither is a Tina4
  need, because the Rust CLI owns file watching and production logs go to
  stdout. Adding it would be a new feature, not a parity fix. Pinned by a test
  in all four so it is not restored by accident.

**One owner per signal, in every framework.** Where a framework registered the
same signal twice, the duplicate registration is DELETED rather than made
coherent.

### Rationale

Two implementations of one lifecycle is the shape that produced every defect
found here.

Node had three. `startServer()` registered nothing. `background.ts` registered
`process.on("SIGTERM", clearTimers)` and its comment called it "additive - it
does not call `process.exit()`". That comment was the bug: registering ANY
listener REPLACES Node's default disposition, so a handler that does not exit
does not add to the default, it CANCELS it. A server with one background task
ignored SIGTERM completely and ran until SIGKILL, burning the whole Kubernetes
grace period on every rolling deploy. The CLI's `serve.ts` had the third:
`server.close(); process.exit(0)`, which kills the very requests the
asynchronous close was waiting to drain.

PHP had the same shape with a far worse symptom, found after this ADR was
first drafted. `Tina4\App` registered SIGTERM/SIGINT from its CONSTRUCTOR
(`App.php:293`, inside `__construct` at line 194 - not from `start()`, line
469). PHP dispatches a `pcntl_signal` handler only when
`pcntl_signal_dispatch()` runs or `pcntl_async_signals(true)` is set, and
neither happens without a server loop. So an App constructed WITHOUT running
the server suppressed SIGTERM's default terminate action while never running
the handler body: measured, the process SURVIVED SIGTERM, ran its full loop and
exited 0 on its own. For an embedder, `kill` and `docker stop` were no-ops.
That is not a shutdown gap, it is an unkillable process.

The milder second half: `bin/tina4php` constructs the App (line 1028) then
calls `$server->start()` (line 1073), which rebinds both signals to
`Server::stop()`. `pcntl_signal` replaces rather than chains, so on the serve
path Server won and App's handlers were dead code. The pair never fought, which
is exactly why it survived unnoticed.

### Consequences

- Four suites with identical case names, each proven red against the unfixed
  code: `SIGTERM lets the in-flight request finish`, `SIGTERM stops accepting
  new connections`, `SIGTERM exits with code 0`, `SIGTERM releases the
  listening port`, `SIGINT lets the in-flight request finish`, `SIGINT exits
  with code 0`, `SIGHUP is not trapped and terminates the process`, `a
  registered background task does not block shutdown`,
  `TINA4_SHUTDOWN_TIMEOUT bounds the drain`.
- Signal handling cannot be tested without a real process. Calling a handler
  directly proves the function runs; it proves nothing about whether the signal
  reaches it, whether the listener stops accepting, or what the process exits
  with. Every case spawns a real detached child and signals its process GROUP.
- **Breaking, low blast radius:** Python and PHP go from an unbounded drain to
  a 30-second bound. A request still running at 30s is now force-closed instead
  of waiting forever. Under any orchestrator it was already being SIGKILLed at
  that point. Set `TINA4_SHUTDOWN_TIMEOUT` higher to restore the old behaviour.
- **Breaking:** Ruby stops answering 503 during shutdown and refuses the
  connection instead. A caller that distinguished 503-shutting-down from a
  connection failure loses that signal.
- Operators must set `terminationGracePeriodSeconds` ABOVE
  `TINA4_SHUTDOWN_TIMEOUT`. At the Kubernetes default both are 30 and a drain
  using its full budget would race SIGKILL.
- Results are macOS-measured. Exit-code behaviour under a container init (PID 1
  does not get default signal dispositions) and PHP's accept-then-RESET are
  kernel- and init-specific, and need re-measuring on Linux.

**Related:** ADR-0012, and `plan/v3/features/009-graceful-shutdown.md`.

### Amendment (2026-07-31): the contract applies on the PRODUCTION server too

The decision above was measured against each framework's BUILT-IN server. Two
of the four hand the socket to a third-party production server, and everything
above lived after the handoff, so none of it ran where operators actually
deploy.

| Framework | production server | feature 9 contract |
| --- | --- | --- |
| Python | hands to uvicorn / hypercorn / granian when `not is_debug` (`core/server.py:3219-3226`) | LOST |
| Ruby | hands to Puma when `!is_debug` (`lib/tina4.rb:437-462`) | LOST |
| PHP | own server throughout | applies |
| Node | own `node:http` + cluster | applies |

Ruby's case is the sharper one: `tina4ruby.gemspec:22` declares
`spec.add_dependency "puma", "~> 6.0"`, so Puma is ALWAYS installed and the
`rescue LoadError` fallback to WEBrick is unreachable in production.

**Correction, recorded deliberately.** An earlier draft of this amendment said
Ruby's Puma handoff was "not debug-gated at all" and that an operator with Puma
installed had "no way to reach WEBrick". Both are FALSE. `lib/tina4.rb:438`
gates the entire Puma block behind `if !is_debug`, and the only other `Puma`
reference in `lib/` (line 291) is inside `print_banner` choosing a banner
string, also debug-gated. `TINA4_DEBUG=true` reaches WEBrick today. The error
came from reading the comment "Try Puma first (production-grade), fall back to
WEBrick" and inferring control flow from it instead of reading the `if` around
it - the same mistake as trusting a stale docblock. The production gap is real;
that framing of it was not.

### Decision

**The feature 9 OUTCOMES are the framework's contract regardless of which
server owns the socket. The MECHANISM is per-server.** This is ADR-0011's
shape (HEAD keeps its per-runtime mechanism; parity is in the outcome) applied
to shutdown. Split the work by who owns each piece:

**The production server already does it - CONFIGURE it, never reimplement it:**

- **Draining in-flight requests.** uvicorn and Puma both do this properly.
  Wrapping or second-guessing them would add a second lifecycle, which is the
  exact shape that produced every defect in this ADR.
- **The drain deadline.** Map `TINA4_SHUTDOWN_TIMEOUT` onto the server's own
  knob: uvicorn's `timeout_graceful_shutdown`, Puma's `force_shutdown_after`.
  A documented env var that means one thing on the built-in server and nothing
  on the production one is a lie on the path operators actually run. Puma's
  default is `:forever`, so unmapped it silently meant "no bound" in production.

**Tina4 owns it - the production server cannot know these exist:**

- **ORM-bound database connections. P0.** Nothing outside Tina4 knows about
  them. Closed in a `finally` / `ensure` around `starter(...)` and around the
  Puma launcher run, covering the default connection and every named one. A
  leaked connection per shutdown is a real resource leak and the cheapest thing
  here to get right.
- **WebSocket RFC 6455 1001.** The production server closes sockets; it does
  not know to send a close frame first. Where this needs a per-server hook (an
  ASGI lifespan shutdown handler, a Puma `on_stopped`) and that proves
  expensive, it is SPECIFIED AND NOT BUILT rather than half-done. The database
  close and the timeout mapping rank above it.

### `TINA4_DEFAULT_WEBSERVER`, implemented in all four

Documented at `tina4_python/CLAUDE.md:1652` with a stale reference in
`tests/test_ws_auth.py:107`, and ZERO occurrences in code - Python-only doc
drift. Implemented rather than deleted, keeping the documented name and
semantics: `TINA4_DEFAULT_WEBSERVER=TRUE` pins the built-in server, unset or
FALSE keeps existing behaviour. Non-breaking.

Implemented in all four so the env surface stays uniform, including PHP and
Node where it is a genuine no-op (both always use their own server) and must
simply be accepted and documented as such.

The justification is determinism, NOT reachability. `TINA4_DEBUG=true` already
reaches the built-in server, so this is not the only route to it. But debug also
changes toolbar injection, error overlays, log level and the AI port, so "turn
on debug" is not an answer for anyone diagnosing a production shutdown, and it
is not something CI should have to do to exercise the built-in path
deterministically instead of depending on which server the runner happens to
have installed.

**It is explicitly NOT the fix for the handoff gap.** An operator must not have
to give up uvicorn or Puma to get their databases closed.

**Follow-up, specified not done:** the var should be registered in the Rust
CLI's `known_vars()` (tina4stack/tina4). That repo is outside this audit's
worktree set, so it is recorded here rather than faked.

### Consequences of the amendment

- Tests must boot a child under the REAL production server - uvicorn for
  Python, Puma for Ruby - send a real signal, and observe the real outcome.
  Where the server is absent the test SKIPS LOUDLY naming what is missing, and
  never passes silently.
- A child booted from a venv or a gem path must ASSERT it loaded the worktree
  copy, not an installed one. A Ruby probe in this project once silently loaded
  an installed `tina4ruby 3.13.92` gem and the run looked fine.
- The headline measurement table in
  `plan/v3/features/009-graceful-shutdown.md` is labelled as built-in-path for
  Python and Ruby rather than left looking like full coverage.
---

## ADR-0018: CORS denies by default, and never pairs the wildcard with credentials

**Date:** 2026-07-31
**Status:** Accepted
**Context:** Feature 10 (CORS middleware)

### Context

The feature 10 audit measured all four CORS implementations through their real
dispatch paths. Four defects came out of it, and they share one shape: a thing
that quietly does not work.

| Behaviour | Python | PHP | Ruby | Node `cors()` | Node `CorsMiddleware` |
| --- | --- | --- | --- | --- | --- |
| Default `TINA4_CORS_ORIGINS` | `*` | `*` | `*` | `*` | `*` |
| ACAO on a normal response | yes | yes | **never** | yes | yes |
| `TINA4_CORS_CREDENTIALS` honoured | yes | yes | yes | **ignored** | yes |
| `ACAO: *` with `ACAC: true` | guarded | guarded | **emitted** | n/a | guarded |
| `Vary: Origin` on an allow-list match | **no** | yes | **no** | yes | yes |
| `Vary: Origin` on an allow-list miss | **no** | yes | **no** | **no** | **no** |

PHP was the only implementation close to correct, so it became the reference
shape rather than a fifth design.

**Ruby could not do CORS at all.** `CorsMiddleware.apply_headers` was never
called from the dispatch path. Only the preflight was answered. A browser sent
its preflight, got a 204 saying yes, sent the real request, and received no
`Access-Control-Allow-Origin`. The browser blocked it. The preflight promised
something the response never delivered.

**Ruby also shipped the pair the Fetch Standard forbids.** With
`TINA4_CORS_CREDENTIALS=true` and the default wildcard origin, the preflight
carried `Access-Control-Allow-Origin: *` and
`Access-Control-Allow-Credentials: true` together. The other three guarded it.

**Node ran two implementations of one feature.** The always-on `cors()` function
never read `TINA4_CORS_CREDENTIALS`. The opt-in `CorsMiddleware` class did. A
documented environment variable did nothing in the default pipeline.

### What the standard says

**The wildcard and credentials.** Be precise about what is being cited here.
Fetch is a WHATWG Living Standard, so it is genuinely normative, and the rule
lives in its **CORS check algorithm** rather than in a prose MUST sentence. The
algorithm is the normative text. Paraphrasing its steps: once the request's
credentials mode is `include`, the check stops treating `*` as a wildcard and
compares it to the request origin as a literal string. That comparison fails,
and the response is rejected.

So this is an algorithm citation, not a quoted MUST, and it is not weaker for
that. A server emitting the pair produces a response no browser will accept,
and no browser will tell the operator why.

**Vary.** This is a caching requirement, so RFC 9111 and RFC 9110 govern it, not
Fetch. RFC 9110 s12.5.5 defines Vary as a description of "what parts of a
request message, aside from the method and target URI, might have influenced the
origin server's process for selecting the content of this response", and a field
name list serves "To inform cache recipients that they MUST NOT use this
response to satisfy a later request unless the later request has the same values
for the listed header fields as the original request".

That scoping decided two things. When an allow-list computes the ACAO from the
request Origin, the response varies by Origin and needs the header. When the
policy is a constant `*`, the response is identical for every caller and must
not carry it, because a Vary there fragments a CDN cache per origin and buys
nothing.

It also settled a question we nearly got wrong. Spring's CORS processor adds
`Access-Control-Request-Method` and `-Request-Headers` to Vary. Tina4's
`Access-Control-Allow-Methods` and `-Allow-Headers` are static configured lists.
The code never reads the request's `Access-Control-Request-*` headers when
building them, so those fields influence nothing and listing them would be a
false statement to every cache downstream. Spring lists them because Spring's
preflight echoes the request. Ours does not. We measured rather than copied.

### What the mainstream does

Django, Rails and ASP.NET all require an explicit policy before any CORS header
appears. None of them ship a permissive default. Under the ADR-0012 authority
order the standard is silent on what the DEFAULT should be, so the frameworks
decide, and they are unanimous.

### Decision

**1. CORS denies by default.** With `TINA4_CORS_ORIGINS` unset, no
`Access-Control-Allow-Origin` is emitted at all. Not an empty one. Not a
rejected one. The browser's own CORS check does the blocking, which produces the
error message developers already recognise.

`*` remains settable. An operator who writes `TINA4_CORS_ORIGINS=*` has made a
choice and gets the old behaviour. Only the default moved.

The status code of a denied preflight does not change. It stays 204. Adding a
403 would be a second behaviour change, and the browser blocks it either way.

Non-browser clients are unaffected and must stay that way. CORS is a browser
mechanism. curl and server-to-server calls never consult it.

**2. The wildcard and credentials never ship together.** When
`TINA4_CORS_ORIGINS` is `*` and credentials are enabled, the wildcard wins and
`Access-Control-Allow-Credentials` is dropped. This matches what Python, PHP and
Node already did and fixes Ruby.

**3. `Vary: Origin` whenever the ACAO is computed from the request.** On an
allow-list match and on an allow-list miss. Never for a constant `*`. The miss
case matters most: without it a shared cache can store the no-ACAO response for
one origin and serve it to another.

**4. Every rejection logs an actionable warning.** Naming the rejected origin,
naming the environment variable, and giving the fix. Once per distinct reason
per process, so a scripted probe cannot flood the log. The whole audit found the
same disease four times over, and silence was the symptom every time.

**5. One implementation per framework.** Node's `cors()` and `CorsMiddleware`
now share a single `CorsPolicy`. Ruby's `CorsClassMiddleware` became an adapter
over `Tina4::CorsMiddleware`. PHP's `beforeCors` delegates to `getHeaders`. Two
copies of one policy is how the credentials bug survived.

### Consequences

**BREAKING.** An app that relied on the permissive default loses cross-origin
access on upgrade. The fix is one line:

```
TINA4_CORS_ORIGINS=https://app.example.com
```

Or `TINA4_CORS_ORIGINS=*` to keep the old behaviour, with credentials still
refused alongside it.

Ruby gains CORS headers on normal responses for the first time. Node's default
pipeline starts honouring `TINA4_CORS_CREDENTIALS`. Both are new headers on
responses that previously carried none, and both are the feature working as
documented rather than a change of contract.

Four conformance suites carry the same case names and each was proven red
against the unfixed code: `deny by default emits no allow origin`, `explicit
wildcard still allows any origin`, `wildcard never pairs with credentials`,
`allow list match reflects origin and credentials`, `allow list miss emits no
allow origin`, `allow list always varies on origin`, `constant wildcard does not
vary on origin`, `preflight status is unchanged when denied`.

`Access-Control-Expose-Headers` remains unimplemented in all four. Nothing
documents it, so nothing is lying. It is a gap, recorded and not built here.

**Related:** ADR-0012, ADR-0013, and
`plan/v3/features/010-cors-middleware.md`.

---

## ADR-0022: The queue promises at-least-once, and each backend keeps that promise the way its protocol allows

**Date:** 2026-08-01
**Status:** Accepted
**Context:** Feature 48 (queue backends), `plan/v3/features/048-queue-backends.md`

### Context

The queue offers one API over four backends: file/lite, RabbitMQ, Kafka and
MongoDB. What that API promises when a job fails or a consumer dies had never
been written down, so each backend answered it differently, and three of the
answers lost work.

Measured against live brokers (RabbitMQ 3.13.7, Kafka, MongoDB 7.0.39), not read
from source:

| | file/lite | RabbitMQ | Kafka | MongoDB |
| --- | --- | --- | --- | --- |
| python | at-least-once | poison job never dead-letters | failed job destroyed | at-least-once |
| php | at-least-once | duplicates, original never acked | no ack at all, full replay | at-least-once |
| ruby | at-least-once | failure never recorded | no commit, full replay | at-least-once |
| node | at-least-once | at-most-once, loses work | cannot drain, replays record 0 | at-least-once |

Only MongoDB and the file backend behaved the same everywhere. The two brokers
that most users reach for behaved differently in all four frameworks, and in no
framework did they behave the way the docs describe.

### Per ADR-0012, the standard first

**AMQP 0-9-1 s1.8.3.13 (`basic.nack` / `basic.reject`).** A message requeued with
`requeue=1` returns to the queue UNMODIFIED. The protocol carries no delivery
counter; `redelivered` is a boolean, not a count. So an attempt count cannot ride
on a requeue. This is not a Tina4 limitation, it is the wire format.

**AMQP 0-9-1 s1.8.3.12 (delivery-tag).** A delivery tag identifies one delivery
on one channel. `basic.ack` with `multiple=0` acknowledges exactly that delivery.
Keeping a single "last tag" and acking it therefore acknowledges whichever
message happened to arrive last, which is a different message from the one the
caller named.

**Kafka commits a consumer-group OFFSET, not a record.** There is no per-record
nack. A record cannot be returned to its position without replaying every record
after it. Committing past a record is irreversible for that group.

Then, what the ecosystem does with those constraints:

| | how a failed message is retried |
| --- | --- |
| Celery (AMQP) | acknowledges and republishes with updated headers |
| Spring AMQP | `RepublishMessageRecoverer` republishes to a retry or dead-letter queue |
| laravel-queue-rabbitmq | republishes with an incremented `attempts` property |
| Spring for Apache Kafka | `DefaultErrorHandler` retries, then `DeadLetterPublishingRecoverer` produces to a dead-letter topic |
| Confluent's documented pattern | re-produce to a retry topic and commit past the original |

Unanimous, across both protocols: **acknowledge the original and republish a new
message carrying the new state.** Nobody counts attempts on a requeue, because
the protocols do not let them.

### Decision

1. **The queue promises at-least-once delivery on every backend.** A job that has
   been popped and not completed is redelivered. Duplicates are possible and are
   the caller's problem; lost work is the framework's problem and is a bug.

2. **A retry is an acknowledge plus a republish, never a bare requeue.** On
   RabbitMQ, `fail()` below `max_retries` acknowledges the original delivery and
   publishes a body carrying the incremented `attempts`. On Kafka it re-produces
   the record and commits past the original. The republish happens BEFORE the
   acknowledge, so a crash in between duplicates rather than loses.

3. **An acknowledgement names its message.** Delivery tags and in-flight Kafka
   records are keyed by message id, never held in a single slot.

4. **`complete()` is terminal on every backend.** After it, the job is gone and
   is never redelivered, including across a consumer restart.

5. **Where a backend genuinely cannot offer a guarantee, record it rather than
   fake it.** Named exceptions, which are correct behaviour and not bugs:
   - Kafka `size()` returns 0. A log has no queue depth, and computing one means
     an admin round-trip per call.
   - Kafka reclaims a dead consumer's work after the consumer-group session
     timeout, about 45s with librdkafka's defaults, not after the framework's
     `TINA4_QUEUE_VISIBILITY_TIMEOUT`. That timeout applies to the file and
     MongoDB backends only, which is already documented.
   - Kafka and RabbitMQ have no native priority ordering in the shape the file
     backend offers.

6. **An argument that cannot be honoured must be rejected, not swallowed.**
   `priority` and `delay_seconds` are currently accepted and discarded by every
   external backend in all four frameworks. Silent acceptance of a no-op argument
   is the `TINA4_CORS_CREDENTIALS` mistake. Either implement it or refuse it
   loudly. This ADR does not settle which, because it is a behaviour change that
   needs the maintainer; it settles that the current silence is wrong.

7. **`size(status)` never answers a different question than the one asked.**
   Returning the pending count when asked for the dead count, which PHP and Node
   both do, is worse than returning 0 or raising, because the caller cannot tell.

8. **A backend that cannot keep decision 1 is REFUSED, not documented.** Node's
   RabbitMQ and Kafka backends now THROW on construction, naming the cause and
   pointing here. They are not deprecated, not warned about, and carry no opt-in
   escape hatch.

   Documenting them as at-most-once was considered and rejected. A data-loss
   footgun with a paper trail is still a data-loss footgun: nobody reads the
   backend caveat before their consumer gets OOM-killed. This project already
   settled the same question the same way for the `redis-npm` session backend,
   which raises rather than falling through to disk, precisely because a silent
   demotion looks like it is working while the operator believes otherwise.
   Anyone "successfully" running Node with these backends today is already
   losing jobs and does not know it, so breaking them loudly is a service.
   Breaking changes are acceptable in v3.

   No escape hatch: somebody may one day have a legitimate fire-and-forget use
   case, but nobody has asked, and a knob for a hypothetical user contradicts
   the north star. If a real request arrives, add it deliberately.

   **This refusal is a HOLDING POSITION, not the settled design.** The fix is a
   persistent connection held on the backend instance, the way Python, PHP and
   Ruby already do it. That is not an enhancement to schedule someday; it is
   what makes the backend correct, and the refusal stands only until it lands.

### The testing lesson: no-mock is necessary, and not sufficient

Worth stating separately because it generalises well beyond queues.

Every queue test in all four frameworks is real. Zero mocks, stubs, fakes,
spies or monkeypatches; no test asserts on a generated script's shape; the
mock-based classes that let the original MongoDB redelivery bug ship were
deleted, and each replacement says so in a comment. By the standard this
project set after that incident, the queue was compliant.

**And all three data-loss bugs still sat in one untested gap.** The live tests
drove the CONNECTORS -- `enqueue`, `dequeue`, `acknowledge` against a real
broker -- and not one of them drove `Job.fail()` through a real RabbitMQ or a
real Kafka in ANY framework. A green suite that never calls the method under
suspicion is not evidence about that method.

So "we test against real services" is not a coverage claim. The rule to add:
**name the code path, not the dependency.** For each public operation that can
lose data, point at the test that exercises THAT operation against the real
thing. Two failure modes seen here that a real-service suite does not catch on
its own:

- **A fresh fixture per test hides a stateful bug.** Node's Kafka assertions
  each create a new topic and pop once, so a backend that always re-reads
  offset 0 passes every time. Popping twice would have caught it instantly.
- **A cache can answer an assertion instead of the service.** PHP asserts
  `size() === 0` after an acknowledge, while `declareQueue()` returns a
  hardcoded `0` on a cache hit -- so the assertion passes whether or not the
  acknowledge did anything.

### Rationale

At-least-once is the only promise all four backends can actually keep. At-most-
once is achievable but nobody wants it from a job queue, and exactly-once is not
available over either protocol without transactional outbox machinery that would
dwarf the rest of the queue.

Acknowledging before republishing would be simpler and is what a first draft
reaches for. It is also the one ordering that loses work, so it is forbidden
rather than merely discouraged.

### Consequences

- **Breaking:** on RabbitMQ, `job.fail()` with retries remaining now acknowledges
  the original delivery and republishes. A consumer that relied on the broker
  redelivering the identical body with `attempts` still at 0 sees the incremented
  value instead. That is the point: it is what makes dead-lettering possible at
  all. Migration: nothing to change in app code. If you were reading `attempts`
  off the payload to detect a redelivery, read `job.attempts` instead, which is
  now accurate rather than always 0.
- **Breaking:** on Kafka, `job.fail()` with retries remaining now re-produces the
  record. Consumers see a new record with the same payload and a higher
  `attempts` rather than nothing at all. Offsets now advance past failed records,
  so a restarted consumer no longer replays them.
- Python moved first and is currently ahead of PHP, Ruby and Node on these three
  fixes. That drift is recorded in
  `plan/v3/features/048-queue-backends.md` and closing it is the follow-up.
- **Breaking:** `new Queue({ backend: "rabbitmq" })` and `{ backend: "kafka" }`
  now throw in tina4-nodejs, including via `TINA4_QUEUE_BACKEND` and the legacy
  string constructor. Migration: switch to `backend: "mongodb"` (at-least-once,
  with a real reservation and visibility timeout) or the default `"file"`
  backend. The other three frameworks are unaffected and still offer both
  brokers. `RabbitMQBackend` and `KafkaBackend` remain exported so the
  persistent-connection rewrite has something to build on; only the `Queue`
  facade refuses them.

**Related:** ADR-0012 (the decision procedure), and
`plan/v3/features/048-queue-backends.md`.
