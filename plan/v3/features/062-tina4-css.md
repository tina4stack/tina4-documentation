# Feature 062: Tina4 CSS

## Identity and status

- Matrix identity: 62 - Tina4 CSS
- Audit state: NOT A FRAMEWORK FEATURE - client asset vendored by the framework (2026-08-10)
- Audit note: the tina4css design system is authored and BUILT in the client (the `tina4-css`
  repo). The frameworks vendor the COMPILED `.css` byte-for-byte and serve it as a static asset.
  There is no four-language framework parity contract to audit here.
- Owner: the `tina4-css` design-system repo (source `tina4-css/src/scss`, build `tina4-css/dist`)
- Catalog phase: Front-end (client asset)

## Decision: Tina4 CSS lives in the client, not the framework

The stylesheet is a BUILD product, not a request-time runtime concern. Its source and its
compiler both live in the client:

- The tina4css SOURCE is `tina4-css/src/scss` (the SCSS moved there with Feature 61).
- The tina4css BUILD is `tina4-css/dist/tina4.css` and `tina4-css/dist/tina4.min.css`, produced
  by the tina4 CLI's SCSS compiler (`tina4/src/scss.rs`).
- Each framework VENDORS that compiled output into its own `public/css/` (`tina4.css`,
  `tina4.min.css`) so the built-in server can serve it as a static asset (Feature 41).

## Measured evidence (2026-08-10)

The vendored CSS is one client build, copied into every framework:

| Check | Result |
| --- | --- |
| `public/css/tina4.css` across Python, PHP, Ruby, Node | md5-identical (`12086b6894947deb23f6f0cd26c1456e`) |
| `public/css/tina4.min.css` across the four | md5-identical (28487 bytes each) |
| Framework `public/css/tina4.css` vs client `tina4-css/dist/tina4.css` | md5-identical |
| Framework `public/css/tina4.min.css` vs client `tina4-css/dist/tina4.min.css` | DIVERGED: framework 28487 bytes, client dist 28472 (client dist is stale) |
| Per-language CSS behaviour | none - the bytes are language-agnostic |

Because the bytes are identical in all four frameworks, there is nothing per-language to keep in
parity: a compiled stylesheet is the same file wherever it is served. The unminified file also
matches the client `tina4-css/dist`, but the MINIFIED file does not right now: the frameworks ship
28487 bytes while `tina4-css/dist/tina4.min.css` is 28472. See the owner decision - the minified
artefact lost its producer when the per-framework SCSS compiler was deleted (Feature 61), and the
Rust CLI is now its only authoritative producer.

## The vendored asset STAYS (this is not the SCSS removal)

Unlike Feature 61 (the `scss/` source folder, which was dead - never compiled or served - and was
removed), `public/css/` is LIVE: the framework serves it as the default stylesheet for the
dev-admin UI and scaffolded pages. Deleting it would strip the styling from a running app. So the
reclassification is a matrix and ownership change only; the compiled files remain where the server
can serve them.

## The only cross-language contract is served-asset byte-identity (already gated)

A per-language BEHAVIOUR contract exists when four frameworks must each implement the same logic.
Here they implement none: they serve identical compiled bytes that the client produced. So there is
no per-language CSS surface to gate.

There IS one cross-language invariant, and it is already gated: all four must serve the SAME bytes at
one URL. `plan/v3/fixtures/tina4css_contract.json` (ADR-0004, decided 2026-08-06) pins that every
framework answers `GET /css/tina4.css` and `GET /css/tina4.min.css` with `text/css`, that the served
body equals the shipped file, and that the four shipped files are byte-identical. It is wired into
all four suites (`tests/test_tina4css_served.py`, `tests/Tina4CssServedTest.php`,
`spec/tina4css_served_spec.rb`, `test/tina4cssServed.test.ts`), and `scripts/build-tina4css.py
--check` is the build-half checker that fails on drift. That fixture is a packaging invariant (one
asset, four packages), not a per-language behaviour contract - which is exactly what a vendored
client asset should have.

## Owner decisions

Proposed for owner ratification:

1. Tina4 CSS is a CLIENT asset: the `tina4-css` repo owns the source and the build; the frameworks
   only vendor and serve the compiled output. No per-language BEHAVIOUR contract is owed; the one
   cross-language invariant (all four serve byte-identical bytes at `/css/tina4.css`) is already
   gated by `tina4css_contract.json` (ADR-0004) and `scripts/build-tina4css.py --check`.
2. Settle the minified-build producer and the client-dist sync. Two drifts are live: (a) the four
   frameworks ship `tina4.min.css` at 28487 bytes while `tina4-css/dist/tina4.min.css` is 28472, so
   the client dist is now the stale copy; (b) the per-framework SCSS compiler that used to produce
   the minified file was deleted with Feature 61, leaving the Rust CLI as its only authoritative
   producer. Decide: the Rust CLI regenerates `tina4.min.css` from `tina4-css/src/scss`, that output
   is committed to both `tina4-css/dist` AND each framework's `public/css/`, and
   `build-tina4css.py --check` gates that the three stay identical. The vendoring MECHANISM (commit
   per release vs pull-from-package at build) is the sub-decision; the byte-identity GATE already
   exists.

## Audit closure checklist

- [x] Decision recorded: Tina4 CSS is a client asset, not a framework feature.
- [x] Source (`tina4-css/src/scss`) and build (`tina4-css/dist`) ownership recorded.
- [x] Vendored-asset byte-identity measured across all four frameworks and against the client build
  (tina4.css matches; tina4.min.css diverges from the stale client dist - recorded).
- [x] Recorded that the vendored `public/css/` STAYS (served), unlike the removed SCSS source.
- [x] The one cross-language invariant (served-asset byte-identity) is gated by the existing
  `tina4css_contract.json` (ADR-0004); no per-language BEHAVIOUR contract is owed.
- [x] Minified-producer + client-dist-sync owner decision recorded for ratification.
