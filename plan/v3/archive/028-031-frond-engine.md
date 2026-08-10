# Historical bundle: Features 28-31 Frond engine

> Archived when the feature inventory moved to one numbered file per feature.
> Current packets: `../features/047-frond-lexer.md`,
> `../features/048-frond-parser.md`, `../features/049-frond-compiler.md` and
> `../features/050-frond-runtime.md`.

Audited 2026-07-28. Part of `98-feature-audit.md`. Phase 3, rows 1-4. **Planning only.**

**Status: CLOSED as one row, deliberately.** The matrix lists lexer (28), parser (29),
compiler (30) and runtime (31) as four features. They are four separable files in
**Python only**. Auditing them separately in the other three is impossible today, and
making them separable is the first item of work (ADR-0009).

## Files, and why the shapes matter

| | layout |
| --- | --- |
| python | `tina4_python/frond/` - `engine.py`, `parser.py`, `compiler.py` |
| php | `Tina4/Frond.php` + `Tina4/FrondCompiler.php` - flat |
| ruby | `lib/tina4/frond.rb` - one file |
| node | `packages/frond/src/engine.ts` - one file |

Python separates parse from compile from execute. PHP separates compile. Ruby and Node
hold all four concerns in one file each. So rows 28-31 have four boundaries in Python,
two in PHP, and one in Ruby and Node.

## Measurements: the worst in the audit, by a distance

| | LOC | fns | CC total | CC avg | worst fn | MI | flags |
| --- | --- | --- | --- | --- | --- | --- | --- |
| python | 2823 | 113 | 796 | 7.04 | `_expr_descriptor` (**58**) | 3.9 | **10 error**, 18 warn |
| php | 2573 | 115 | 916 | 7.97 | `findMathOp` (**50**) | 1.7 | **11 error**, 19 warn |
| ruby | 1998 | 104 | 728 | 7.00 | `default_filters` (**63**) | **0.0** | 9 error, 14 warn |
| node | 2455 | 204 | 1095 | 5.37 | `evalVarInner` (**74**) | **0.0** | **12 error**, 15 warn |

Set against the rest of the programme:

- **42 scanner errors across the four** - more than every other audited feature combined.
- **CC average 5.37 to 7.97**, the highest of any feature. The ORM (feature 13, itself
  the worst until now) ran 3.79 to 4.66.
- **Two frameworks at maintainability 0.0**, the other two at 1.7 and 3.9, against the
  scanner's floor of 40.
- **Node's 1095 total complexity is the single highest number in the audit**, and its
  204 functions are twice Ruby's 104 for 1.2x the lines - many small functions plus one
  74-complexity monster.
- **Four different worst functions**, at 58, 50, 63 and 74. As with the dispatch
  pipeline (feature 6), each framework independently grew its own god-function, in a
  different place.

Two of those functions are worth naming, because their names say what is wrong:

- **Ruby's `default_filters` at CC 63.** A filter registry is a **data table** -
  name to implementation. Sixty-three decision points means it is being built with
  control flow instead of declared as data.
- **Node's `evalVarInner` at CC 74.** Expression evaluation done as one branching
  function rather than a dispatch over node types. This is the highest single
  complexity measured anywhere in the framework.

## What does NOT differ, and this reframes the whole phase

**Correctness parity is already established, and I verified it rather than assuming.**
All four frameworks ship `frond_expression_corpus.txt` and it is byte-identical:

```
931ed20b114c97e48f184759d4b3ee6b   tina4-python/tests/fixtures/
931ed20b114c97e48f184759d4b3ee6b   tina4-php/tests/fixtures/
931ed20b114c97e48f184759d4b3ee6b   tina4-ruby/spec/fixtures/
931ed20b114c97e48f184759d4b3ee6b   tina4-nodejs/test/fixtures/
```

82 cases, one shared answer key, same bytes. That is the enforced-contract pattern this
audit has been *recommending* for other features, already in place here.

So Phase 3 is not a correctness hunt. Expression behaviour is pinned. **The axis for
Frond is structure and performance**, which is a different kind of row from anything in
Phase 1 or 2 and should be read as such.

## The performance context, dated and attributed

Prior measurement (recorded in `plan/v3` benchmark work, output-verified at the time,
**not re-run in this audit**): Frond is slower than the incumbent template engine in
**all four** languages - roughly PHP 3.7x vs Twig, Node 8.9x, Python 14.5x, Ruby ~55x
vs ERB.

I am citing that rather than re-deriving it; a competitor benchmark run is its own task.
It matters here because it is the same subsystem that measures worst structurally, and
those two facts are plausibly the same fact: a 74-complexity expression evaluator and a
63-complexity filter registry built from control flow are not shapes that run fast.

**Do not treat that link as proven.** The honest statement is: Frond is the least
maintainable subsystem measured and the slowest relative to its competitors, and the
structural work below is the prerequisite for finding out whether the second follows
from the first.

## Verdict: PROMOTE python (structure), then split before optimising

Decided on **SOLID (separation of concerns)** with LOC/CC as the evidence.

Python's `frond/` folder is the only layout where lexer, parser, compiler and runtime
are distinguishable, which makes it the reference - and it is now the framework-wide
convention per **ADR-0009** (one folder per feature, so a feature can be deleted).

No framework wins on the internals: all four are at or near the maintainability floor,
and each has its own god-function.

## Pattern

**Split first, measure, then optimise. In that order.**

1. **Adopt ADR-0009's layout for Frond in all four**, Python's shape:

```
   <feature-folder>/
     lexer      tokenise source into tokens          (row 28)
     parser     tokens into an AST                   (row 29)
     compiler   AST into a callable or closure tree   (row 30)
     runtime    execute a compiled template + context (row 31)
     filters    the filter registry, as DATA          (row 32)
     index      the public entry point, unchanged
```

   Public API does not move: `Frond` stays importable exactly as today, from a barrel.
   This is a physical reorganisation.

2. **The filter registry becomes data, not control flow.** A map from name to a small
   function, declared once. This alone should take Ruby's `default_filters` from 63 to
   near zero, and it is mechanical.
3. **Expression evaluation becomes a dispatch over AST node types**, one small handler
   per node kind, replacing the single branching evaluator. That is Node's
   `evalVarInner` (74), Python's `_expr_descriptor` (58) and PHP's `findMathOp` (50) -
   three names for the same missing abstraction.
4. **No function above CC 12** when the split is done, asserted from
   `tina4 metrics --json` so the gate cannot rot.
5. **Only then look at performance.** Optimising a 74-complexity function means
   optimising something nobody can safely change; splitting first makes the hot path
   visible and the change reviewable.

## Methodology

The corpus is the safety net that makes this tractable, and it already exists.

1. **Confirm the corpus is green in all four at HEAD** before touching anything. It is
   the characterisation suite; unlike feature 6, it does not need writing.
2. **Extend the corpus first**, not the code. 82 cases cover expressions. Add cases for
   tags, inheritance, macros, whitespace control, auto-escaping and fragment caching -
   the parts rows 33-40 own - so the split is protected across all of Frond and not just
   expressions.
3. **Split per framework, one concern per commit**, re-running the corpus after each.
   Order: **PHP first** (it already has a compiler split, so it is the shortest
   distance), then Node, then Ruby (biggest move, single file), Python last (already
   compliant - it only gains `lexer`, `runtime` and `filters` boundaries).
4. **Filter registry to data** in all four - the cheapest large complexity win.
5. **Expression dispatch** in all four - the largest and riskiest change, and the one
   the corpus most directly protects.
6. **Re-measure and publish before/after.** Record the numbers in this file. If MI does
   not move off the floor, say so: the Python AST adoption already moved complexity
   -15.5% while **MI stayed flat**, so a complexity win does not automatically buy
   maintainability, and this plan should not promise it.
7. **Then re-run the competitor benchmarks** and find out whether the structural work
   moved throughput. That is the honest experiment; predicting the answer now would be
   guessing.

## Tests to write

The corpus does the behavioural work. These are the structural and boundary tests it
cannot express.

| pair | positive | negative |
| --- | --- | --- |
| corpus holds | `the_expression_corpus_passes_in_all_four` - the pre-existing gate | `no_split_commit_changes_a_single_corpus_answer` |
| corpus is broader | `the_corpus_covers_tags_inheritance_macros_and_escaping` | `no_frond_feature_is_absent_from_the_corpus` |
| folder layout | `frond_exposes_lexer_parser_compiler_runtime_as_separate_units` | `no_framework_holds_two_of_the_four_concerns_in_one_file` |
| removability (ADR-0009) | `deleting_the_frond_folder_leaves_a_bootable_framework` | `no_other_module_imports_a_frond_internal_directly` |
| entry point unchanged | `frond_is_importable_from_its_documented_path` | `the_split_does_not_change_any_public_import` |
| filters are data | `the_filter_registry_is_a_map_from_name_to_function` | `the_filter_registry_declares_no_control_flow` - the Ruby 63 reproduction |
| complexity gate | `no_frond_function_exceeds_complexity_twelve` (from `tina4 metrics --json`) | `no_god_function_returns` |
| escaping survives | `auto_escaping_is_applied_after_the_split` | `the_split_does_not_introduce_an_unescaped_path` |

The last pair is the one to be careful about: auto-escaping (row 37) is a **security**
control, and moving code that decides what gets escaped is the highest-risk part of this
plan. Its corpus cases go in before any file moves.

## Risks

- **This is the largest physical change the audit has proposed** and it touches a
  security control (auto-escaping). The corpus makes it survivable; extending the corpus
  first is not optional.
- **Node's `exports` map has broken importability before** (nodejs#32/#353). The
  import test added by that fix must be part of the Node split's gate.
- **PHP's PSR-4 autoload** has already caused a fatal once via eager `files` loading.
  Moving classes into a namespace folder touches the same machinery.
- **The performance payoff is a hypothesis, not a plan deliverable.** If the split lands
  and throughput does not move, the split was still worth it for maintainability - but
  this plan must not be sold on a speed promise it has not measured.

## Rows 32-40 status

Not yet audited. This row deliberately covers 28-31 only. Rows 32 (filters), 33 (tags),
34 (tests), 35 (functions), 36 (extensibility API), 37 (auto-escaping), 38 (sandboxing),
39 (template caching) and 40 (fragment caching) each need their own pass - and several
of them become separately measurable only after the ADR-0009 split, which is the
argument for doing the split early in Phase 3 rather than at the end.

## Parked

Not implemented. The ADR-0009 split is the prerequisite for the rest of Phase 3.
Order within the programme is unchanged (6, 4, 5, 3, 13, 14, 15, 16, 17, 18, 19, 20),
with this row's split slotting in wherever Frond work is scheduled.
