# Feature 061: SCSS compiler

## Identity and status

- Matrix identity: 61 - SCSS compiler
- Audit state: NOT A FRAMEWORK FEATURE - moved to the tina4 client (2026-08-10)
- Audit note: SCSS compilation is NOT a runtime framework concern. It belongs to the tina4
  client (the Rust CLI). This packet records that decision; there is no four-language framework
  parity contract to audit here.
- Owner: the tina4 CLI (`tina4/src/scss.rs`) and the canonical `tina4-css` design-system repo
- Catalog phase: Front-end (client tooling)

## Decision: SCSS lives in the client, not the framework

SCSS is a BUILD concern, not a request-time runtime concern, so it belongs to the tooling the
developer runs at build time - the tina4 CLI - not to each language framework.

- The COMPILER lives in the tina4 Rust CLI: `tina4/src/scss.rs` compiles the non-partial SCSS
  files in an input directory to CSS, and the CLI's watcher recompiles on change. `tina4 init`
  scaffolds a project's `src/scss` directory.
- The canonical tina4css design-system SOURCE lives in the `tina4-css` repo
  (`tina4-css/src/scss`), which is the single authoritative copy.
- The frameworks previously BUNDLED a byte-identical duplicate of the tina4css source
  (`tina4_python/scss/tina4css`, `lib/tina4/scss/tina4css`, `packages/core/scss/tina4css`, 17
  files each, md5-identical). That copy was source-only (no compiler), never compiled or served
  at runtime (the router skips the `scss` dir), and unreferenced by any framework code - pure
  dead weight.

## What was done (2026-08-10)

The bundled duplicate was REMOVED from all three frameworks that carried it (PHP never did):

| repo | removed | commit |
| --- | --- | --- |
| tina4-python | `tina4_python/scss/` | `386cd6d` (v3) |
| tina4-ruby | `lib/tina4/scss/` | `c61250c` (v3) |
| tina4-nodejs | `packages/core/scss/` | `26be920` (v3) |

Smoke-verified after removal: `import tina4_python` and `require 'tina4'` load cleanly; Node has
no reference to the folder in `src`, `package.json` or `tsconfig`. A scaffolded project's own
`src/scss` (compiled by the CLI) is unaffected - the framework's `src/scss` skip-set, the
metrics stylesheet count, and the project scaffold list are about the USER project, not the
removed bundle, and are correct as-is.

## Boundary (for the client, not this audit)

The tina4 CLI owns: discovering `.scss` in the project's `src/scss`, compiling non-partial files
to CSS (skipping `_partials`), watch-mode recompilation, and scaffolding `src/scss` on `init`.
The `tina4-css` repo owns the canonical design-system source. Neither is a four-language
framework parity concern.

## Why there is no framework parity contract

A Frond template renders at request time; SCSS compiles at BUILD time. The frameworks serve the
COMPILED `.css` as a static asset (Feature 41), which is language-agnostic bytes. There is no
per-language SCSS runtime behaviour to keep in parity, because no framework compiles SCSS at
runtime. So this row has no cross-language fixture, no defect register, and no owner decision
beyond the one recorded above.

## Audit closure checklist

- [x] Decision recorded: SCSS is a client (CLI) feature, not a framework feature.
- [x] The bundled framework duplicate removed in all three carrying frameworks, with commits.
- [x] Removal smoke-verified (imports load; no references remain).
- [x] Canonical source (tina4-css) and compiler (CLI scss.rs) locations recorded.
- [x] No four-language framework parity contract is owed here.
