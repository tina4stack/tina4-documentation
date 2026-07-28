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
