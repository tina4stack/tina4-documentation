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

The vendored CSS is one client build, copied byte-for-byte into every framework:

| Check | Result |
| --- | --- |
| `public/css/tina4.css` across Python, PHP, Ruby, Node | md5-identical (`12086b6894947deb23f6f0cd26c1456e`) |
| Framework `public/css/tina4.css` vs client `tina4-css/dist/tina4.css` | md5-identical (in sync) |
| Per-language CSS behaviour | none - the bytes are language-agnostic |

Because the bytes are identical in all four, there is nothing per-language to keep in parity: a
compiled stylesheet is the same file wherever it is served.

## The vendored asset STAYS (this is not the SCSS removal)

Unlike Feature 61 (the `scss/` source folder, which was dead - never compiled or served - and was
removed), `public/css/` is LIVE: the framework serves it as the default stylesheet for the
dev-admin UI and scaffolded pages. Deleting it would strip the styling from a running app. So the
reclassification is a matrix and ownership change only; the compiled files remain where the server
can serve them.

## Why there is no framework parity contract

A per-language parity contract exists when four frameworks must implement the same BEHAVIOUR. Here
they implement none: they serve identical compiled bytes that the client produced. There is no
cross-language fixture, no defect register, and no per-language surface to gate. The one thing worth
watching is drift between the vendored copy and `tina4-css/dist` (see the owner decision).

## Owner decisions

Proposed for owner ratification:

1. Tina4 CSS is a CLIENT asset: the `tina4-css` repo owns the source and the build; the frameworks
   only vendor and serve the compiled output. No four-language parity contract is owed.
2. Decide the vendoring policy: keep committing the built `tina4.css`/`tina4.min.css` into each
   framework's `public/css/` per release (current, and in sync today), OR pull it from the
   `tina4-css` package at build/release time. The risk in the current approach is silent drift -
   a framework copy can fall behind `tina4-css/dist`; a release-time sync (or a checksum gate)
   closes that gap.

## Audit closure checklist

- [x] Decision recorded: Tina4 CSS is a client asset, not a framework feature.
- [x] Source (`tina4-css/src/scss`) and build (`tina4-css/dist`) ownership recorded.
- [x] Vendored-asset byte-identity measured across all four frameworks and against the client build.
- [x] Recorded that the vendored `public/css/` STAYS (served), unlike the removed SCSS source.
- [x] No four-language framework parity contract is owed here.
- [x] Vendoring-drift owner decision recorded for ratification.
