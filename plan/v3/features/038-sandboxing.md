# Feature 38: Sandboxing (restrict template access)

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 3, row 7. **Planning only.**

**Status: CLOSED. Contains the most serious finding in the audit so far.** All four probed
by execution with a live XSS payload, both inside and outside the sandbox.

Audited directly after row 37 because it is the second security row, and because
`project_release_3_13_72` records a "Frond sandbox filter-gate bypass fix" already shipped
here. A control that has been fixed once is worth re-testing rather than trusted.

## P1: the sandbox cannot revoke the escaping opt-outs

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

## P1b: `{% autoescape false %}` bypasses the tag gate in ALL FOUR

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

## What IS uniform, verified

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

## The tag gate covers a hardcoded subset, different per framework

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

## Method note: my first probe was wrong, and the payload was why

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

## Surface divergence

| concept | python | php | ruby | node |
| --- | --- | --- | --- | --- |
| enable | `sandbox(allowed_filters=, allowed_tags=, allowed_vars=)` | `sandbox(?array $filters, ?array $tags, ?array $vars)` | `sandbox(filters:, tags:, vars:)` | `sandbox(filters?, tags?, vars?)` |
| disable | `unsandbox()` | `unsandbox()` | `unsandbox` | `unsandbox()` |
| chainable | returns self | returns self | (last assignment) | returns Frond |

Two divergences. **Python names the parameters `allowed_*` and the other three name them
`filters` / `tags` / `vars`**, so Python is the odd one out on a keyword argument that is part
of its public call. And **Python and Ruby take keywords while PHP and Node take positionals**,
which is a category 3 runtime-idiomatic difference and fine. The naming is category 4.

## Verdict: PROMOTE php on the filter gate, GAP on tags

Decided on **correctness of a security control**, which outranks every other axis.

**Filter gate: PROMOTE php.** It is the only framework that revokes `raw` and `safe`
correctly, and it does so by deciding escaping from what actually ran rather than from what
was written. That is the right mechanism, not a lucky outcome.

**Tag gate: GAP in all four.** Nobody has a general gate. Node's four hardcoded names are the
closest thing to one and still miss `autoescape`.

**Ordinary filter and var gates: UNIFORM.** Keep exactly as they are.

All category 4. Nothing about a runtime prevents any of this.

### Governance note, and it is the point of ADR-0004

3.13.72's PHP commit reads `fix(frond): converge blocked-filter sandbox semantic on the
master (skip, not empty)`. PHP was moved toward Python on the skip-versus-empty axis, which
was correct. But Python is the **broken** implementation on the axis that decides whether XSS
escaping can be revoked, and PHP was already right there.

A release converged the correct framework onto the master without anyone checking whether the
master was right on the more important axis. That is precisely what
`feedback_python_master_governance` exists to prevent: if Python is broken, fix Python, do not
mirror it. This row is the evidence that the rule needs the audit to enforce it, because the
convergence commit looked like good parity work.

## Pattern

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

## Methodology

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

## Tests to write

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

## Risks

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

## Open items

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

## Parked

Not implemented, per the planning-only constraint. The recommendation above is the exception I
am flagging rather than acting on.
