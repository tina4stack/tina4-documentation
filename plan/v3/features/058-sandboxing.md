# Feature 058: Frond sandboxing

## Identity and status

- Matrix identity: 58 - Frond sandboxing
- Audit state: decision-ready
- Audit note: probed by execution 2026-07-28 with a live XSS payload, inside and outside the
  sandbox - the most serious finding in the audit. The two P1 bypasses shipped fixes (Python
  `bef0c6d`, PHP `cbe31184`, Ruby `167fe78`, Node `1eb1c4a`, plus escape lock-in tests). Not
  released (owner holding releases). Prose completed from that evidence 2026-08-10. No framework
  code changed here.
- Dependencies: Feature 57 auto-escaping (the escape decision the sandbox must be able to
  enforce), Feature 52 filters, Feature 53 tags, Feature 51 runtime
- Dependants: any application rendering a template written by an untrusted author
- Existing ADRs: ADR-0004 (best implementation prevails), the python-master-governance rule (if
  Python is broken, FIX it, do not mirror it); ADR-0009
- Shared fixtures: sandbox escaping cases added to `frond_expression_corpus.txt` BEFORE the
  ADR-0009 split
- Catalog phase: Frond template engine

## Why this feature exists

An application sometimes renders a template written by someone it does not trust. The sandbox
restricts what such a template can do to an allow-list of filters, tags and variables, so an
untrusted author cannot reach arbitrary data or emit XSS. It is the ONLY thing standing between
a user-supplied template and an attack, so it must actually hold that line in all four.

## Boundary

This feature owns the sandbox allow-list gates (filters, tags, variables), the ability to REVOKE
the escaping opt-outs (`raw`/`safe`/`autoescape`), and the single tag gate at dispatch. It
DELEGATES the escape mechanism to Feature 57, the filter/tag behaviour to Features 52/53, and the
runtime to Feature 51. Its guarantee is negative: a capability NOT on the allow-list cannot be
used, INCLUDING the ones that disable escaping.

## Existing implementation evidence

| Evidence (probed by execution, both inside/outside the sandbox) | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Deny `raw`/`safe` revokes escaping (P1) | BROKEN (unescaped) | correct | BROKEN | BROKEN |
| Deny `autoescape` tag (P1b) | BROKEN | BROKEN | BROKEN | BROKEN |
| Escaping decided from | filter DETECTED in chain (wrong) | filter that RAN (right) | detected | detected |
| Tag gate coverage | subset | subset | ONE tag (`include`) | four tags (literal) |
| Empty `[]` allow-list | allow-all (falsy bug) | permit-nothing | permit-nothing | permit-nothing |
| Ordinary filter/var gate | uniform | uniform | uniform | uniform |
| P1/P1b fixed + lock-in tests | shipped `bef0c6d` | `cbe31184` | `167fe78` | `1eb1c4a` |

Two P1 bypasses of a documented security control were found by execution. P1: denying `raw`/
`safe` (the two filters that turn OFF HTML escaping) had NO effect in Python, Ruby and Node -
`{{ x|raw }}` with `raw` denied still rendered unescaped - because they SKIP a denied filter but
decide escaping by DETECTING the filter in the chain; skip it and detection still fires, marking
the value safe. PHP is correct because it decides escaping from what actually RAN. P1b:
`{% autoescape false %}` bypassed the tag gate in ALL FOUR (a denied tag whose whole job is
disabling escaping ran anyway), because the tag gate is a per-name conditional at a few call sites
(Node four names, Ruby one), not a single check at dispatch. And an empty `[]` allow-list meant
"allow all" in Python (`if allowed_filters` treats `[]` as falsy) while the other three read it as
permit-nothing - the same intent, three immunities and one hole, purely from language falsy rules.
All were fixed and lock-in-tested (not yet released).

### Retained introductory record

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 3, row 7. **Planning only.**

**Status: CLOSED. Contains the most serious finding in the audit so far.** All four probed
by execution with a live XSS payload, both inside and outside the sandbox.

Audited directly after row 37 because it is the second security row, and because
`project_release_3_13_72` records a "Frond sandbox filter-gate bypass fix" already shipped
here. A control that has been fixed once is worth re-testing rather than trusted.

### P1: the sandbox cannot revoke the escaping opt-outs

The sandbox takes a filter allow-list. `raw` and `safe` are the two filters that turn OFF
HTML escaping. Denying them has no effect in three of the four frameworks.

Payload `<script>alert(1)</script>`, allow-list `filters=["upper"]` (so `raw` and `safe`
are both denied):

| template | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| `{{ x }}` (baseline) | escaped | escaped | escaped | escaped |
| `{{ x\|raw }}`, raw DENIED | **UNESCAPED** | escaped | **UNESCAPED** | **UNESCAPED** |
| `{{ x\|safe }}`, safe DENIED | **UNESCAPED** | escaped | **UNESCAPED** | **UNESCAPED** |
| `{{ x\|raw }}`, raw ALLOWED | UNESCAPED | UNESCAPED | UNESCAPED | UNESCAPED |

Read the Python column as a pair. Denying `raw` and allowing `raw` produce **byte-identical
output**. The allow-list entry that governs XSS escaping is inert.

**Why it happens.** All four block a denied filter by *skipping* it (`continue` in Python and
Node, `next` in Ruby). But the escaping decision is not made by executing `raw`; it is made by
**detecting `raw` in the filter chain**. Skip the filter and the detection still fires, so the
value is marked safe and never escaped. PHP is correct because it decides escaping from what
actually ran.

**Why it is P1 and not a curiosity.** `tina4-nodejs/CLAUDE.md:872` documents the feature, in
its own comment, as restricting "capabilities for user-supplied templates":

```
frond.sandbox(["upper"], ["if"], ["x"]);
```

The documented purpose is rendering templates written by someone you do not trust. An
untrusted author writes `{{ evil|raw }}`, and in Python, Ruby and Node they get unescaped
output through a control that was configured to forbid exactly that. The sandbox is the only
thing standing between a user-supplied template and XSS, and in three of four frameworks it
does not stand there.

### P1b: `{% autoescape false %}` bypasses the tag gate in ALL FOUR

The same payload, tag allow-list `tags=["if"]`, so `autoescape` is denied:

```
{% autoescape false %}{{ x }}{% endautoescape %}

python  <script>alert(1)</script>
php     <script>alert(1)</script>
ruby    <script>alert(1)</script>
node    <script>alert(1)</script>
```

A denied tag whose entire job is disabling escaping runs anyway, in every framework. PHP is
correct on the filter axis and still fails here, so no framework currently holds the line.

Two independent routes to the same outcome, and a third (`|safe`), all through a control
built to close them.

### The tag gate covers a hardcoded subset, different per framework

Read from source, then confirmed by execution. Node gates four tag names by literal
comparison (`engine.ts:2087-2120`): `has("if")`, `has("for")`, `has("set")`, `has("include")`.
Ruby gates **one** (`frond.rb:748`): `include`.

Denied-tag results with `tags=["if"]`:

| tag | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| `for` | **RAN** | blocked | **RAN** | blocked |
| `set` | blocked | - | - | - |
| `macro` | blocked | - | - | - |
| `autoescape` | **RAN** | **RAN** | **RAN** | **RAN** |

The gate is a per-tag-name conditional bolted on at four (or one) call sites, not a single
check at tag dispatch. So the allow-list silently governs whichever tags somebody remembered,
and every tag added since is ungated by default. That is the structural cause of P1b.

Python's own docstring says the list takes "tag names (if, for, set, include, **etc.**)". The
"etc." is not true in any of the four.

### Method note: my first probe was wrong, and the payload was why

My first run used `ok = "yes"` and reported the filter gate as inconclusive-looking-fine, and
`{% for %}` as blocked. Both readings were wrong:

- `"yes"` is already lowercase, so `|lower` blocked and `|lower` applied both return `yes`.
  The payload could not distinguish them. `MiXeD` fixed it.
- `{% for i in [1,2] %}{{ i }}{% endfor %}` returned `''`, which I read as the tag being
  blocked. The loop ran twice; `i` was not in `allowed_vars`, so the **var** gate blanked each
  iteration. Changing the body to a literal exposed `RANRAN`.

Recording it because both are the same mistake: a probe whose expected-pass and expected-fail
outputs are identical proves nothing. **A security probe needs a payload whose blocked and
unblocked outputs cannot be confused.** That is now a rule for the remaining rows.

## Public surface contract

### Surface divergence

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| enable | `sandbox(allowed_filters=, allowed_tags=, allowed_vars=)` | `sandbox(?array $filters, ?array $tags, ?array $vars)` | `sandbox(filters:, tags:, vars:)` | `sandbox(filters?, tags?, vars?)` |
| disable | `unsandbox()` | `unsandbox()` | `unsandbox` | `unsandbox()` |
| chainable | returns self | returns self | (last assignment) | returns Frond |

Two divergences. **Python names the parameters `allowed_*` and the other three name them
`filters` / `tags` / `vars`**, so Python is the odd one out on a keyword argument that is part
of its public call. And **Python and Ruby take keywords while PHP and Node take positionals**,
which is a category 3 runtime-idiomatic difference and fine. The naming is category 4.

## Inputs and outputs

- Input: `sandbox(filters, tags, vars)` allow-lists (a list permits exactly those; `None`/`null`/
  `nil` allows everything; `[]` permits NOTHING) and a template plus context.
- Output: the rendered template with any capability outside the allow-list unavailable - a denied
  filter/var skipped (empty), a denied tag not run, and CRUCIALLY escaping NOT revocable by a
  denied `raw`/`safe`/`autoescape`.
- A denied escape-opt-out leaves the value ESCAPED; the sandbox holds the XSS line.
- `unsandbox()` restores full capability with no partial gate left behind.

## Lifecycle and operation graph

1. `sandbox(filters, tags, vars)` records the allow-lists (empty means permit-nothing).
2. At render, each filter is checked against the filter allow-list; a denied filter is skipped
   AND cannot suppress escaping (escaping is decided from filters that RAN).
3. Each tag is checked against the tag allow-list at DISPATCH (one gate), so every tag - including
   `autoescape` - is gated; a denied `autoescape` cannot disable escaping.
4. Each variable is checked against the var allow-list; a denied var renders empty.
5. A security-relevant denial (a template reaching for `raw` inside a sandbox) is logged.
6. `unsandbox()` clears the gates.

## Configuration and precedence

- An allow-list of names permits exactly those; `None`/`null`/`nil` allows everything; `[]`
  permits NOTHING (Python's `[]`-is-falsy allow-all bug is fixed). The two must never be confused.
- Escaping is decided by what RAN, not what was written; a denied opt-out cannot revoke it.
- The tag gate is one check at dispatch, so a tag added later is gated by construction, not left
  ungated because no one added it to a hardcoded list.

## Failures, side effects and security

- P1 (fixed): a denied `raw`/`safe` MUST re-escape the value; deciding escaping from a DETECTED
  filter rather than an EXECUTED one let a denied opt-out still suppress escaping. PHP's
  decide-from-what-ran mechanism is the fix, ported to the other three.
- P1b (fixed): a denied `autoescape` tag MUST NOT disable escaping; the per-name tag conditionals
  are collapsed into one gate at dispatch so `autoescape` (and every tag) is gated.
- EMPTY vs NULL: `[]` permits nothing, `None`/`null`/`nil` permits everything; a caller who
  computes an allow-list and gets an empty result must not silently receive an open sandbox.
- A denied filter/var stays SILENT (skip/empty) - failing closed while still rendering an
  untrusted template beats raising on a hostile input - BUT a security-relevant denial is LOGGED,
  because a template trying to reach `raw` in a sandbox is a signal.
- GOVERNANCE (ADR-0004): a prior release converged PHP onto Python's skip-not-empty semantic
  (correct) while Python was the BROKEN one on the escaping-revocation axis and PHP was already
  right. The rule this proves: if Python is broken, FIX Python, do not mirror it; the audit is
  what enforces it, because the convergence commit looked like good parity work.

## Wire and persistence contract

There is no persistence; the contract is the RENDERED OUTPUT under the allow-lists, byte-identical
across the four for the sandbox corpus. A denied escape opt-out never yields unescaped output, in
any of the four.

## Providers and substitutability

The sandbox is pure and engine-agnostic. A future runtime denies by REVOKING capability (not
skipping a step), decides escaping from executed filters, gates every tag at dispatch, and reads
`[]` as permit-nothing - proven by the sandbox corpus.

## Contradictions and defects

### What IS uniform, verified

The ordinary gates behave identically in all four. Value `MiXeD`, allow-list
`filters=["upper"]`, `vars=["ok"]`:

| case | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| allowed filter `\|upper` | `MIXED` | `MIXED` | `MIXED` | `MIXED` |
| denied filter `\|lower` | `MiXeD` | `MiXeD` | `MiXeD` | `MiXeD` |
| allowed var `ok` | `MiXeD` | `MiXeD` | `MiXeD` | `MiXeD` |
| denied var `secret` | `` | `` | `` | `` |

Four frameworks, byte-identical, including the choice to skip a denied filter silently rather
than raise. That convergence is real and worth keeping.

### Verdict: PROMOTE php on the filter gate, GAP on tags

Decided on **correctness of a security control**, which outranks every other axis.

**Filter gate: PROMOTE php.** It is the only framework that revokes `raw` and `safe`
correctly, and it does so by deciding escaping from what actually ran rather than from what
was written. That is the right mechanism, not a lucky outcome.

**Tag gate: GAP in all four.** Nobody has a general gate. Node's four hardcoded names are the
closest thing to one and still miss `autoescape`.

**Ordinary filter and var gates: UNIFORM.** Keep exactly as they are.

All category 4. Nothing about a runtime prevents any of this.

#### Governance note, and it is the point of ADR-0004

3.13.72's PHP commit reads `fix(frond): converge blocked-filter sandbox semantic on the
master (skip, not empty)`. PHP was moved toward Python on the skip-versus-empty axis, which
was correct. But Python is the **broken** implementation on the axis that decides whether XSS
escaping can be revoked, and PHP was already right there.

A release converged the correct framework onto the master without anyone checking whether the
master was right on the more important axis. That is precisely what
`feedback_python_master_governance` exists to prevent: if Python is broken, fix Python, do not
mirror it. This row is the evidence that the rule needs the audit to enforce it, because the
convergence commit looked like good parity work.

### Risks

- **This is a security fix in a shipped feature, so it changes behaviour for anyone relying on
  the current one.** The reliance is on a bypass, so breaking it is the point. It still needs a
  `Breaking:` entry saying plainly that templates which previously escaped the sandbox no
  longer do.
- **Fixing the escaping decision touches the non-sandboxed path**, which row 37 proved is
  byte-identical across four frameworks and is the framework's most valuable behaviour. The
  corpus cases in step 1 are not optional; they are what makes this survivable.
- **The tag-gate collapse touches every tag** and Ruby's is effectively a new gate rather than
  a repair.
- **Do not bundle the parameter rename with the security fix.** Two failure modes in one
  commit makes a security fix harder to review and to backport.

## Owner decisions

### Open items

- [x] **Does an empty allow-list (`[]`) deny everything or allow everything, per framework?**
      Both are defensible; silently differing is not.

      **ANSWERED by execution, and it was silently differing.** `[]` must mean
      **permit nothing**; only `None`/`null`/`nil` means "allow everything". Three of
      four already did that and Python did not:

      | | mechanism | `[]` behaved as |
      | --- | --- | --- |
      | Python | `if allowed_filters` | **allow all** - BUG, `[]` is falsy in Python |
      | Ruby | `filters ? ... : nil` | permit nothing (`[]` is truthy in Ruby) |
      | Node | `filters ? new Set(filters) : null` | permit nothing (`[]` truthy in JS) |
      | PHP | `!== null` | permit nothing (explicit null test) |

      Python's line became `if allowed_filters is not None else None`. Note the shape
      of this bug: the SAME intent expressed in four languages produced three
      immunities and one hole, purely because of what each language counts as falsy.
      A single-framework review could not have found it. Pinned in all four by
      `negative: an empty allow-list does not permit everything`.

- [x] **Should this jump the audit queue?** Every other finding in the programme is parked for
      planned implementation. This one is an exploitable bypass of a documented security
      control in three of four frameworks, and the fix is small and well understood. My
      recommendation is to ship steps 1 to 4 as their own release ahead of the rest of the
      audit. **Owner decision.**

      **YES - owner approved ("fix the two P1s first"), and it shipped.** Python
      `bef0c6d`, PHP `cbe31184`, Ruby `167fe78`, Node `1eb1c4a`, plus escape lock-in
      tests in all four. Not released: the owner is holding releases.

## Proposed conformance fixture

### Tests to write

Pure string rendering, no I/O. Every one of these is cheap and guards a security boundary.

| pair | positive | negative |
| --- | --- | --- |
| raw is revocable | `denying_raw_escapes_the_value` | `a_denied_raw_filter_never_produces_unescaped_output` - the exact P1 reproduction |
| safe is revocable | `denying_safe_escapes_the_value` | `a_denied_safe_filter_never_produces_unescaped_output` |
| deny differs from allow | `allowing_raw_renders_verbatim_and_denying_it_does_not` | `denying_a_filter_never_produces_the_same_output_as_allowing_it` - the byte-identical finding |
| autoescape is gated | `a_denied_autoescape_tag_does_not_disable_escaping` | `no_tag_can_disable_escaping_inside_a_sandbox` - the P1b reproduction |
| tag gate is general | `every_tag_is_gated_by_the_tag_allow_list` | `no_tag_is_ungated_because_it_was_omitted_from_a_hardcoded_list` - the Ruby one-tag and Node four-tag reproduction |
| ordinary filter gate | `a_denied_filter_leaves_the_value_unfiltered` | `a_denied_filter_never_runs` - needs a payload where run and skipped differ |
| var gate | `a_denied_var_renders_empty` | `no_context_value_outside_the_allow_list_is_reachable` |
| null allow-list | `a_null_allow_list_permits_everything` | `an_empty_allow_list_permits_nothing` - the two must not be confused |
| unsandbox | `unsandbox_restores_full_capability` | `unsandbox_does_not_leave_a_partial_gate_in_place` |
| parameter naming | `sandbox_accepts_filters_tags_and_vars_in_all_four` | `the_old_allowed_prefixed_keyword_raises_a_named_error` |
| cross-framework | `all_four_produce_identical_output_for_the_sandbox_corpus` | `no_framework_permits_what_another_denies` |

`denying_a_filter_never_produces_the_same_output_as_allowing_it` is the one to write first. It
is a one-line property, it fails in three frameworks today, and it would have caught this the
day the sandbox shipped.

The empty-versus-null pair matters more than it looks: `None` / `null` means "allow
everything" in all four implementations, so a caller who computes an allow-list and gets an
empty result must not silently receive an open sandbox. I have not verified which way each
framework treats `[]`. **Open probe item.**

## Integration map

- Feature 57 owns the escape mechanism the sandbox must enforce; Feature 52 filters and Feature
  53 tags are what the allow-lists gate; Feature 51 runs the render.
- The sandbox escaping cases join the corpus BEFORE the ADR-0009 split, so the split carries a
  correct implementation rather than a known bypass.
- The docs name the sandbox as a control for untrusted templates; they update with the fix.
- Central fixtures, four runners, the CI matrix and the Frond security docs update together.

## Breaking changes and migration

- The P1 fixes change behaviour for any template that previously ESCAPED the sandbox (through a
  denied `raw`/`safe` or `autoescape`); breaking that reliance is the point, but it needs a
  `Breaking:` entry stating plainly that such templates no longer bypass the sandbox.
- The empty-`[]`-permits-nothing fix changes Python callers who passed `[]` expecting allow-all
  (they were relying on a bug that opened the sandbox).
- The Python parameter rename (`allowed_*` -> `filters`/`tags`/`vars`) rejects the old keyword
  with a named error; it is NOT bundled with the security fix (two failure modes in one commit
  makes a security fix harder to review and backport).

## Implementation backlog

### Methodology

The order matters more here than in any other row, because the corpus is the safety net and
the escaping cases do not exist in it yet.

1. **Add the sandbox escaping cases to the corpus FIRST**, before any code moves. Row 37
   already establishes that HTML escaping is byte-identical in all four, so the answer key is
   unambiguous. The cases are the table at the top of this file: denied `raw`, denied `safe`,
   denied `autoescape`, each with the XSS payload, plus the allowed counterparts.
2. **Write the tests below and confirm red.** Expect: Python, Ruby and Node red on
   `raw`/`safe`; all four red on `autoescape`; all four green on the ordinary gates.
3. **Fix the filter gate in Python, Ruby and Node** by porting PHP's mechanism. Python first,
   since it is the master and the other two follow its shape.
4. **Fix the tag gate in all four** by collapsing the per-name conditionals into one check at
   dispatch. PHP and Node are smallest (they already gate something); Ruby is the largest move
   (one call site to a general gate).
5. **Re-run the corpus.** The escaping cases from step 1 are what prove the fix did not weaken
   the non-sandboxed path.
6. **Then the parameter rename**, which is cosmetic by comparison and must not be bundled with
   the security fix.

**Steps 3 and 4 are a security fix and should not wait for the ADR-0009 folder split.** The
split moves this code; shipping the fix first means the split has a correct implementation and
corpus coverage to preserve, rather than carrying a known bypass across a large refactor.

## Porting capsule

### Pattern

**A sandbox denies by revoking capability, not by skipping a step. Escaping is decided by
what ran, never by what was written.**

1. **Escaping is decided from executed filters.** The renderer tracks whether an
   escape-suppressing filter *actually ran*. A skipped filter cannot suppress escaping. This
   is PHP's mechanism and it is the fix for P1 in Python, Ruby and Node.
2. **One tag gate at tag dispatch, not per-tag conditionals.** A single check where a tag name
   is resolved, so every tag is gated by construction and a new tag is gated the day it is
   added. This deletes the hardcoded name lists and fixes P1b in all four.
3. **`autoescape` is gated like any other tag** and, when denied, cannot disable escaping.
4. **Denying a filter or var stays silent** (skip / empty). Verified identical in all four,
   and silence is defensible here: a sandbox renders untrusted input, and failing closed while
   continuing to render beats raising on a hostile template. **The exception is a
   security-relevant denial**, which must be observable: log it, because a template trying to
   reach `raw` inside a sandbox is a signal worth seeing.
5. **Parameter names converge on `filters` / `tags` / `vars`.** Three of four already use
   them; Python's `allowed_*` is renamed. Per the no-aliases rule, the old keyword raises a
   named error rather than being silently accepted.
6. **`sandbox()` and `unsandbox()` return the engine in all four**, so the documented chained
   form works everywhere.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (P1 raw/safe, P1b autoescape, tag-gate subset, []-bug).
- [x] Owner ambiguities decided and recorded ([]=permit-nothing; jump-the-queue - both answered).
- [x] Proposed shared cases and mutation witnesses complete (deny-differs-from-allow first).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.

### State

AUDIT decision-ready. The most serious finding in the audit: two P1 bypasses of a documented
security control (denied `raw`/`safe` did not re-escape; denied `autoescape` disabled escaping in
all four), plus a Python `[]`-allow-all bug. All were FIXED and lock-in-tested (Python `bef0c6d`,
PHP `cbe31184`, Ruby `167fe78`, Node `1eb1c4a`) - the owner approved fixing the two P1s first -
but NOT yet released (releases held). The 3.14 audit consolidates the contract (deny by revoking
capability, decide escaping from what RAN, one tag gate at dispatch, `[]`=permit-nothing) and
gates it with the sandbox corpus BEFORE the ADR-0009 split. The parameter rename is separate.
Decision-ready; fixes shipped to v3, not released.
