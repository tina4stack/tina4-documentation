# tina4 doctor - check global AI skills currency (CLI feature)

## Goal
`tina4 doctor` gains a "Tina4 AI skills" section that reports whether the
globally-installed skills in `~/.claude/skills` are current with the latest
published skills, so a developer knows when to re-run `install-skills`.

Owner request (2026-07-13): "on tina4 doctor - it must be able to check if
global ai skills are current."

## Context (how skills work today)
- `install-skills.sh` / `.ps1` (hosted at raw.githubusercontent.com/tina4stack/tina4/main/)
  pull each `SKILL.md` (+ references) from the framework repos at a pinned tag
  `ref="${TINA4_SKILLS_REF:-<ver>}"` into `~/.claude/skills/<skill>/SKILL.md`.
- Skills installed: tina4-maintainer, tina4-developer-{python,php,ruby,nodejs}, tina4-js.
- SKILL.md carries NO embedded version, and install writes NO on-disk marker.
  So "is it current" cannot be read locally - it must be compared to the
  published content at the current ref.

## Design (chosen: content-comparison, no install-side change needed)
`doctor` adds a `check_skills_currency()`:
1. Resolve the CURRENT ref: fetch the hosted `install-skills.sh`, parse the
   `ref=` default line (single small curl). Fall back to the CLI's own crate
   version's matching tag if the fetch shape changes.
2. For each skill dir present under `~/.claude/skills`, fetch the published
   `SKILL.md` at that ref and byte/hash-compare to the installed file.
3. Report per skill: current (ok), stale (diff -> "run: curl -fsSL .../install-skills.sh | sh"),
   or missing.
4. Graceful degrade: offline / fetch failure -> "could not check (offline)",
   an info line, NOT a red failure. Never make doctor exit non-zero on this.
- Rationale: truest definition of "current" (actual bytes vs published), works
  for ALL installs including pre-existing ones, and needs no marker/manifest
  plumbing. doctor is interactive so a few network calls are acceptable.

## Scope
- [ ] `src/doctor.rs`: add the Skills section + `check_skills_currency()` (reqwest/
      ureq? - check existing deps; the repo has no HTTP client yet, so prefer a
      tiny curl subprocess to keep the zero-heavy-dep stance, matching how
      install is shelled out).
- [ ] Handle: no `~/.claude/skills` dir (skills not installed -> hint install), offline.
- [ ] `tina4 doctor --help` / CLAUDE.md: doctor now also reports skills currency.
- [ ] Tests: the currency comparator is pure (installed-hash vs published-hash ->
      status enum); unit-test that pure function (no network in the test).

## Related drift to fix in the same CLI change
- [ ] `tina4/install-skills.sh` + `.ps1` pin is STALE: `ref=3.13.71` while 3.13.72
      shipped. Bump to the current release and confirm `bump-skills-ref.sh`
      covers this repo's copy (it appears to have missed it - the docs-site copy
      was bumped to 3.13.72 but this one was not).

## Sequencing
AFTER the 3.13.73 framework release ships (owner: "do b, then release").
This is a CLI-only feature -> its own CLI release (v3.8.56), separate from the
framework registries.

## Status: SHIPPED in CLI 3.8.56 (2026-07-13)

- doctor.rs: `check_skills_currency()` + pure `classify_skills`/`parse_ref_from_installer`
  + `.tina4-skills-ref` marker read + curl fetch from tina4.com/install-skills.sh.
  8 pure unit tests green; live-verified current/stale/not-recorded paths.
- PROVEN read-only: `tina4 doctor` from a project dir leaves CLAUDE.md byte-identical,
  creates no files. Output states the guarantee explicitly.
- install-skills.sh/.ps1 (tina4 repo): pin 3.13.71 -> 3.13.73 + write the marker.
- Committed bba098b; owner chose "ship agent branch + doctor" -> merged
  feature/independent-coding-agent (12 commits) to main, tagged 3.8.56, pushed.
  Push CI green; crates.io publish via release.yml (tag) in flight.

### Release correction + CI repair (2026-07-13, later)
- MIS-TAG FIXED: first tag was bare `3.8.56` but the CLI release workflow triggers on
  `v*` only, so nothing built/published. Deleted the bare tag, pushed `v3.8.56` ->
  Release Binaries green, crates.io tina4 3.8.56 LIVE, draft release has all 5 binaries
  + provisional SHA256SUMS. (Framework repos correctly use bare tags; only the CLI is v-prefixed.)
- WINDOWS SIGN = local human EV-2FA step (NOT me): `pwsh scripts/sign-release.ps1 -Tag v3.8.56`
  (SimplySign) or `sh scripts/sign-release.sh v3.8.56` from macOS (jsign). It signs the
  Windows .exe, regenerates SHA256SUMS over signed bytes, and publishes the draft.
- DOCS CI REPAIR (both gates were red for ~4 releases, pushed to tina4-documentation main):
  - Link Check (audit-links.py): recognise raw-HTML `id=`/`name=` anchors + strip HTML from
    heading text -> 201 false "missing-anchor" gone; fixed 2 real links + de-linked 2 dead
    GitBook placeholders. CI now GREEN.
  - Doc Truth (audit-truth.py): FORWARDED_SUBCOMMANDS set (migrate/generate/test/routes/
    metrics/queue/seed/console) unioned into real top-level + skip their second-token check.
    Verified green locally; CI in-flight.
  - Mirror synced (docs/public/install-skills.{sh,ps1} -> 3.13.73 + marker). docs:build green.

### HELD / follow-ups
- tina4.com install-skills MIRROR bump (tina4-documentation/docs/public/install-skills.{sh,ps1}
  -> 3.13.73 + marker): edited but NOT pushed. Held because the docs "Doc Truth"
  (audit-truth) CI gate is RED (see below) - do not push docs into a red truth-gate;
  land the mirror WITH the audit-truth fix.
- **Doc Truth CI has been RED for ~4 releases (3.13.70..73).** Root cause: audit-truth.py
  builds the tina4 CLI from source and extracts clap-declared subcommands (16), so the 8
  BLIND-FORWARDED commands (migrate/generate/test/routes/metrics/queue/seed/console -
  real, forwarded to the framework via the self-describing CLI) are flagged "fake". Local
  runs showed false-green against a stale 3.8.53 binary. FIX belongs in audit-truth.py:
  recognise forwarded commands as real (e.g. via `tina4 commands --json` manifest or a
  forwarded-set), NOT delete the docs. Unblocks the mirror push.
- Link Check CI red (pre-existing, separate): 2 legacy-v2 broken links + 201 --strict-anchors.
