# Feature specs (Spec-Driven Development)

One canonical spec per feature: `NNN-<feature-slug>.md`. The spec is the
human-readable **source of truth** for a feature; the contract fixture
(`../fixtures/<feature>_contract.json`) is its executable form, and the ADR in
`../decisions/` records the decisions behind it. Code is derived from the spec,
never the other way round (ADR-0098).

## What a spec carries

- **Intent** — what the feature does and why, citing the governing ADR.
- **Acceptance criteria** — numbered `AC-N` given/when/then lines, each tagged
  with the fixture case id(s) that prove it.
- **Non-goals** — what the feature deliberately does not do.
- **Tasks** — per-framework, Python reference first.

Start from [`TEMPLATE.md`](TEMPLATE.md).

## The gate

`scripts/audit-spec-coverage.py` (CI, in `audit-truth.yml`) enforces the link:

- every `AC-N` maps to a real case in the spec's fixture, and
- every case in that fixture is claimed by some `AC-N`.

So the spec and the executable contract can never drift. Adoption is **per
feature**: a feature with no spec here is simply not gated yet, and the gate
passes when `specs/` holds no feature spec at all (greenfield).

This sits on top of the existing ADR + contract-fixture backbone
(`../CONTRACT-MAP.md`, `scripts/audit-contract-fixtures.py`), it does not replace
it: the fixture still proves the four frameworks obey the contract; the spec adds
the human-readable, acceptance-criteria front-end that agents and people build from.

## Where the spec fits: Tina4-Driven Development (T4DD)

The spec is one layer of the wider method, **Tina4-Driven Development** (T4DD -
plan-driven development, [ADR-0099](../decisions/ADR-0099.md)). The plan is the spine
and nothing happens off-plan; four layers hang off it, each with its own gate:

- **ADR** (`../decisions/`) - the WHY, the locked decisions.
- **Spec** (here) - the WHAT, intent + `AC-N`, gated by `audit-spec-coverage.py`.
- **Contract fixture** (`../fixtures/`) - the EXECUTABLE form, gated by
  `audit-contract-fixtures.py`.
- **Task plan** (`<repo>/plan/<task>.md`) - the HOW and the tracking.

So a spec is where you write the WHAT; the ADR above it holds the WHY and the
fixture beside it holds the proof.
