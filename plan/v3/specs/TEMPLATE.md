<!--
  Copy this file to plan/v3/specs/NNN-<feature-slug>.md and fill it in.
  NNN is the feature number (same as the fixture's `feature`). This is the
  CANONICAL spec for the feature: the human-readable source of truth that the
  ADR (why), the contract fixture (executable form) and the four implementations
  all answer to. See ADR-0098 and the `tina4-maintainer` skill's Spec-Driven
  Development section.

  The gate `scripts/audit-spec-coverage.py` reads two things from this file:
    1. the `Fixture:` line below, and
    2. every `**AC-N**` entry and the `Cases:` ids on its line.
  It fails the build if an AC has no case, names a case the fixture lacks, or
  leaves a fixture case claimed by no AC. Keep them in step.
-->

# Spec NNN: <Feature name>

- Status: Draft | Accepted | Shipped
- ADR: ADR-NNNN (the decision this spec implements; cite the governing one)
- Fixture: <feature>_contract.json

## Intent

Two or three lines: what this feature does and why, for a human. Name the user
goal, not the implementation. Link the governing ADR for the decisions behind it.

## Acceptance criteria

Each `AC-N` is one behaviour a single test can make red or green, written
given/when/then, and tagged with the fixture case id(s) that prove it. One AC
per case is the goal; an AC may cite several cases when one behaviour genuinely
needs them. Every fixture case must be claimed by some AC.

- **AC-1** — given <state>, when <action>, then <observable result>. Cases: XXX-S01
- **AC-2** — given <state>, when <bad input>, then <graceful result, never a 500>. Cases: XXX-S02
- **AC-3** — given <state>, when <edge case>, then <result>. Cases: XXX-S03, XXX-S04

## Non-goals

What this feature deliberately does NOT do, so scope cannot creep in later.

- <non-goal 1>
- <non-goal 2>

## Tasks

Python is the reference; the others mirror its proven behaviour. Each links its
own repo's task plan.

- [ ] Python — [tina4-python/plan/<task>.md](...)
- [ ] PHP — [tina4-php/plan/<task>.md](...)
- [ ] Ruby — [tina4-ruby/plan/<task>.md](...)
- [ ] Node.js — [tina4-nodejs/plan/<task>.md](...)
