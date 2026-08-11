# Feature 133: Carbonah benchmark contract

## Identity and status

- Matrix identity: 133 - Carbonah benchmark contract (`benchmarks/` and `plan/v3/CARBONAH.md`)
- Audit state: decision-ready
- Audit note: a CROSS-FRAMEWORK benchmark + reporting contract, not a runtime feature. Self-measured
  2026-08-11 from the four `benchmarks/` directories (`carbon_benchmarks.{py,php,rb,ts}`,
  `benchmark_results.json`, `template_comparison.json`), the `carbonah/` Rust SCI tool, and the report
  `plan/v3/CARBONAH.md`. The benchmark JSONs are dated 2026-04-01 (PHP/Ruby/Node) and 2026-04-02 (Python);
  `CARBONAH.md` is dated 2026-03-20.
- Dependencies: the `carbonah` Rust CLI (Software Carbon Intensity, ISO/IEC 21031:2024), each framework's
  runtime, and the template rivals (Jinja2/Mako, Twig, ERB) the template comparison benchmarks against.
- Dependants: the green-benchmark report, the CO2 accounting, and any release/marketing claim of
  cross-framework parity and efficiency.
- Existing ADRs: none dedicated. Related: the DRY-detector / metrics work (the `carbonah lint` engine
  shares that lineage) and the Carbonah signing pipeline.

- Catalog phase: cross-cutting (benchmarking + reporting)

## Why this feature exists

Tina4 makes two public claims that need evidence: the four frameworks behave identically (parity), and the
stack is efficient (green). The Carbonah benchmark contract is that evidence. Each framework ships a
benchmark harness that measures the same workloads and writes a common-shaped result JSON; the `carbonah`
tool measures the real carbon intensity of a run; and `CARBONAH.md` reports it all. The contract is only as
good as its consistency - a stale or self-contradicting report undermines the very claim it exists to
support.

## Boundary

This packet owns the benchmark contract: the per-framework harnesses, the shared result-JSON shape, the
template comparison, and the `CARBONAH.md` report. It does NOT own the `carbonah` Rust tool's internals
(its `lint`/`analyse`/`measure`/`session` commands are a separate product) - it owns the CONTRACT by which
the harnesses invoke it and the report presents it.

## Existing implementation evidence

- Harness: each framework has `benchmarks/carbon_benchmarks.<ext>` plus `bench_frameworks.<ext>` and
  `bench_templates.<ext>`. The Python harness docstring declares "9 workload categories" (json, db_single,
  db_multi, template, json_large, plaintext, crud, paginated, startup). By default it reports wall-clock
  throughput; `--carbon` shells out to the REAL `carbonah` CLI for SCI; `--startup` spawns fresh
  interpreters to measure import cost (honest - an in-process loop cannot see it because modules cache).
- Result JSON shape (CONSISTENT across all four): `{date, machine, config, results, templates}`, with
  `config = {runs: 3, requests: 5000, concurrency: 50, warmup: 500}` identical in all four. Each `results[]`
  entry is `{framework, language, json_runs[], list_runs[], json_median, list_median, warmup_time_ms, deps,
  features, server}` - throughput medians per workload, plus `deps: 0` (zero-dependency) and a `features`
  count.
- Template comparison (`templates` / `template_comparison.json`): per language `{measured, runtime,
  output_equivalence: "verified", engines: {Frond, <rivals>}, fastest_rival, frond_slower_by,
  frond_faster_by}`. Consistent shape; it records that Frond is slower than the fastest rival (e.g.
  `frond_slower_by: 37.14` vs Mako in Python) - an honest, unflattering number kept in the contract.
- `carbonah` tool: a real Rust SCI CLI (`lint` with tree-sitter across 12 languages and rules like E002
  N+1-query, `analyse` for dependencies, `measure "<cmd>"`, `session`). The harnesses integrate it via
  `--carbon`; the tool is not vaporware.
- `CARBONAH.md`: a hand-written report (no generator found in `benchmarks/` or `carbonah/`) summarising
  test counts, per-module breakdowns, a feature-parity table, and a CO2 report computed by a formula
  (`CO2 = TDP x time x carbon_intensity`, assuming 15W Apple Silicon and 475g CO2/kWh).

## Public surface contract

The contract has three surfaces: (1) each harness is runnable (`python benchmarks/carbon_benchmarks.py`
and siblings) and writes `benchmark_results.json` + `template_comparison.json` in the shared shape; (2) the
`--carbon` path invokes the `carbonah` CLI for SCI; (3) `CARBONAH.md` presents the aggregate. The contract
is that all four harnesses measure the SAME workloads and emit the SAME JSON shape, and the report reflects
the current reality.

## Inputs and outputs

- Input: the framework under test, the workload set, the run config (runs/requests/concurrency/warmup), and
  (for `--carbon`) the `carbonah` CLI. Output: `benchmark_results.json`, `template_comparison.json`, and the
  `CARBONAH.md` report.

## Lifecycle and operation graph

1. Run each framework's harness -> wall-clock medians per workload -> `benchmark_results.json`.
2. Run the template comparison -> `template_comparison.json`.
3. Optionally run `--carbon` -> `carbonah` CLI -> SCI numbers.
4. Aggregate into `CARBONAH.md` (currently a manual step).

## Configuration and precedence

- The run config is embedded in each result JSON (`runs/requests/concurrency/warmup`), identical across the
  four. There is no env configuration; the harnesses take CLI subcommands (`json`, `--startup`, `--carbon`).

## Failures, side effects and security

- No security surface (a developer tool over the project's own code). The failure mode is CLAIM DRIFT: a
  report that mis-states parity, test counts, or efficiency. That is the whole risk here, and it is
  currently realised (see the findings register): `CARBONAH.md` is stale and self-contradictory, and the
  workload set is not identical across the four harnesses.

## Wire and persistence contract

The persisted artifacts are `benchmark_results.json`, `template_comparison.json`, and `CARBONAH.md`. The
JSON shape is the machine contract (consistent). `CARBONAH.md` is the human contract (drifted).

## Providers and substitutability

The SCI provider is the `carbonah` CLI (substitutable in principle for any SCI measurer; the harnesses shell
out to it). The template rivals (Jinja2/Mako/Twig/ERB) are the comparison baselines. The workload set is the
substitution axis for what is measured.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| CARBON-REPORT-STALE | `CARBONAH.md` is dated 2026-03-20 and the benchmark JSONs 2026-04-01/02 - roughly five months old as of this audit. Its test counts (6,183 total; 1,165-1,669 per framework) are far below the current suites (the v3 audit work alone has grown them well past 3,000 per framework). A "green benchmark report" that is five months stale mis-states the current state, and the four JSONs are not even from one run (Python 2026-04-02 vs the others 2026-04-01). | Regenerate the report and the JSONs from a single fresh run on each release; date-stamp the report and treat a stale date as a CI warning. |
| CARBON-REPORT-INCONSISTENT | `CARBONAH.md` carries THREE contradictory test totals - the summary says 6,183, the per-module section headers sum differently (~4,912), and the rating-criteria line says "4,912 tests" - and THREE feature counts: the benchmark JSON `features` field is 38, `CARBONAH.md` says "78 features", and the matrix catalog is 133. Because the report is hand-written (no generator found), these drift independently. | GENERATE `CARBONAH.md` from the benchmark JSONs plus the real suite counts, so the totals are computed once and cannot disagree. Single-source the feature count (the catalog is the authority: 133). |
| CARBON-WORKLOAD-PARITY | The `results[]` array is NOT the same length across frameworks: Python has 11 workload entries, PHP/Ruby/Node have 13 - so the harnesses do not measure the same workload set, undermining the parity claim the benchmark exists to prove. The Python harness docstring says "9 workload categories", matching neither 11 nor 13. | Align the workload set across all four harnesses (same categories, same count) and fix the docstring to match; add a check that the four `results[]` cover identical workload names. |
| CARBON-CO2-HANDCALC | The CO2 report in `CARBONAH.md` is computed by a hand formula (TDP 15W x time x 475g/kWh) rather than the `carbonah` tool's actual SCI measurement - even though the harnesses already wire the real tool via `--carbon`. The "green" numbers are an estimate presented as a result. | Use the `carbonah` CLI's real SCI output for the CO2 section (the integration already exists), or clearly label the formula-based numbers as an estimate. |

## Owner decisions

- CARBON-DEC-01 (proposed): make `CARBONAH.md` a GENERATED artifact (from the benchmark JSONs + the real
  suite counts + the `carbonah` SCI output), regenerated per release and date-stamped - this closes
  CARBON-REPORT-STALE, CARBON-REPORT-INCONSISTENT, and CARBON-CO2-HANDCALC at once.
- CARBON-DEC-02 (proposed): align the workload set across the four harnesses and the docstring
  (CARBON-WORKLOAD-PARITY), with a parity check that the four cover identical workloads.

## Proposed conformance fixture

1. Shape parity: assert all four `benchmark_results.json` have the same top-level keys and the same `config`
   (they do today - lock it).
2. Workload parity: assert the four `results[]` cover the SAME set of workload names (currently fails - 11
   vs 13).
3. Report freshness: assert `CARBONAH.md`'s date is within N days of the benchmark JSON dates (currently
   fails - it is older and the JSONs disagree by a day).
4. Report consistency: assert the report's total equals the sum of its per-module counts and equals the
   suite counts (currently fails - three totals), and that the feature count equals the catalog's (133).

## Integration map

- Harnesses: `benchmarks/carbon_benchmarks.*` (+ `bench_frameworks.*`, `bench_templates.*`) per framework.
- Tool: the `carbonah` Rust CLI, invoked via `--carbon` for SCI.
- Report: `plan/v3/CARBONAH.md` (currently manual).
- Related: the template comparison (feature family: Frond, feature 111-era), and the `audit-truth` doc gate
  (which should, but currently does not, catch the report's internal inconsistency).

## Breaking changes and migration

- None to code. Making the report generated changes how it is produced (and will change the numbers to the
  current, larger, correct ones) - document the regeneration step in the release process.

## Implementation backlog

1. CARBON-DEC-01: write the `CARBONAH.md` generator (JSON + suite counts + SCI), regenerate on release,
   date-stamp; retire the hand-written report.
2. CARBON-DEC-02: align the four harnesses' workload set + docstring, add the workload-parity check.
3. Add the four conformance checks (shape, workload, freshness, consistency).

## Porting capsule

The Carbonah benchmark contract needs: four harnesses that measure the SAME workload set and emit ONE shared
JSON shape (`{date, machine, config, results, templates}` with an identical `config`); a `--carbon` path that
invokes a real SCI tool rather than a hand formula; a template comparison that keeps honest numbers (Frond
slower where it is slower); and a report that is GENERATED from those artifacts, not hand-maintained, so its
totals and feature count cannot drift from the JSONs, the suites, or the feature catalog. Date-stamp the
report and fail CI when it is stale. The lesson mirrors the framework's own First Principle: a benchmark
report must match measured reality, or it is worse than no report.

## Audit closure checklist

- [x] Boundary and public surface complete (harnesses, JSON contract, tool integration, report).
- [x] Lifecycle and every producer/consumer edge complete (run -> JSON -> SCI -> report).
- [x] Configuration, failure (claim drift), side-effect and security rules complete.
- [x] Wire/storage (the result JSONs + the report) and provider contracts complete.
- [x] Cross-framework behaviour + divergences recorded (shape consistent; workload count 11 vs 13; report
  drift).
- [x] Owner ambiguities decided and recorded (CARBON-DEC-01/02 proposed).
- [x] Proposed conformance fixture (shape, workload, freshness, consistency) complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule sufficient.
