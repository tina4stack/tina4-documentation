# Internal planning and decisions

Working documents for the Tina4 framework family: feature specs, gameplans per language,
audits, release plans, and the architecture decision log.

**This directory is NOT published.** It lives at the repository root, outside `docs/`, and
both of the things that read this repo are scoped to `docs/`:

- `pnpm docs:build` (tina4press) builds only what is under `docs/`. The page count is the
  `.md` count under `docs/`; adding files here does not change it.
- `scripts/audit-truth.py` globs exactly `docs/**/*.md` (`DOC_GLOBS`), so plan documents are
  never checked against the CLI, the env vars, or the Python API.

That separation is deliberate. Plan documents describe work that is proposed, in progress,
or abandoned, so they contain APIs that do not exist and commands that were never built.
Running the doc-truth gate over them would fail, and publishing them to tina4.com would
present intentions as documentation.

**Do not move this directory under `docs/`.** If you want a plan document to be public,
rewrite it as a real chapter in `docs/<language>/` and let the truth gate check it.

## Layout

- `v3/DECISIONS.md` - the architecture decision log (ADR-0001 onward). Consult it before
  changing a cross-framework contract, and supersede an ADR explicitly rather than silently.
- `v3/*.md` - specs, gameplans, audits and per-release plans.
- `v3/spikes/`, `v3/tools/`, `v3/tina4press/` - supporting material.

## History

This was a standalone local-only git repository at `IdeaProjects/plan` with no remote, so
the decision log existed on exactly one machine. It was grafted in with `git subtree` on
2026-07-27, preserving all 20 commits back to 2026-05-15.
