# Feature 063: Frond and Tina4 browser helpers

## Identity and status

- Matrix identity: 63 - Frond and Tina4 browser helpers
- Audit state: NOT A FRAMEWORK FEATURE - client asset vendored by the framework (2026-08-10)
- Audit note: the browser-side JavaScript (`frond.js` and the tina4-js helpers) is authored and
  BUILT in the client (the `tina4-js` repo). The frameworks vendor the COMPILED bundles byte-for-byte
  and serve them as static assets. There is no four-language framework parity contract to audit here.
- Owner: the `tina4-js` repo (source in `tina4-js/src`, build via esbuild to the IIFE/`frond.js`
  bundle)
- Catalog phase: Front-end (client asset)

## Decision: the browser helpers live in the client, not the framework

`public/js/` holds the client's compiled JavaScript, not framework runtime code. Every file there is
a BUILD product of `tina4-js`:

- `frond.js` / `frond.min.js` - the Frond reactive browser runtime (esbuild output; never
  hand-edited - the `.js` is generated).
- `tina4.min.js` / `tina4js.min.js` - the tina4-js core browser helpers.
- `tina4-dev-admin.min.js` - the dev-admin UI bundle.

The tina4-js repo owns the source and the build. Each framework VENDORS the compiled bundles into
its own `public/js/` so the built-in server can serve them as static assets (Feature 41), and the
dev-admin UI can load its reactive front-end with zero external dependencies.

## Measured evidence (2026-08-10)

The vendored JavaScript is one client build, copied byte-for-byte into every framework:

| Check | Result |
| --- | --- |
| `public/js/frond.js` across Python, PHP, Ruby, Node | md5-identical (`733bc95a35f1c67296e67c2bb78b5ed1`) |
| Per-language JS behaviour | none - the bundles are language-agnostic |
| Build provenance | esbuild output from `tina4-js`, rebuilt and committed per release |

Because the bundles are identical in all four, there is nothing per-language to keep in parity: a
compiled browser bundle is the same file wherever it is served.

## The vendored asset STAYS (this is not the SCSS removal)

Unlike Feature 61 (the `scss/` source folder, which was dead and was removed), `public/js/` is LIVE.
The framework serves `frond.js` to the browser, and running apps depend on it: the dev-admin UI is
built on the Frond reactive runtime, and the CSRF flow rides on it (the server reads the form token
that `frond.js` sends and returns a `FreshToken` header that `frond.js` consumes -
`core/server.py:1602` and `:1611`). Deleting `public/js/` would break the dev-admin UI and the CSRF
token refresh. So the reclassification is a matrix and ownership change only; the compiled bundles
remain where the server can serve them.

## Where a real contract does live (and where it does not)

The ASSET is a client build with no per-language framework behaviour. But the CSRF handshake that
`frond.js` speaks IS a client-to-server contract: the browser sends the form token in the request
body, and the server issues a fresh token in a response header. That contract is owned by the CSRF
feature (Feature 37) on the server side and by `tina4-js` on the browser side; the two must agree.
It is audited there, not here. This packet only records that the browser bundle is a vendored client
artifact.

## Why there is no framework parity contract

A per-language parity contract exists when four frameworks must implement the same behaviour. Here
they implement none: they serve identical compiled bundles that the client produced. There is no
cross-language fixture, no defect register, and no per-language surface to gate. The one thing worth
watching is drift between the vendored bundles and the current `tina4-js` build (see the owner
decision).

## Owner decisions

Proposed for owner ratification:

1. The browser helpers are a CLIENT asset: the `tina4-js` repo owns the source and the build; the
   frameworks only vendor and serve the compiled bundles. No four-language parity contract is owed.
2. Decide the vendoring policy: keep committing the built `frond.js` and tina4-js bundles into each
   framework's `public/js/` per release (current), OR pull them from the `tina4-js` package at
   build/release time. The risk in the current approach is silent drift - a framework copy can fall
   behind the tina4-js build; a release-time sync (or a checksum gate) closes that gap.
3. The `frond.js` <-> server CSRF token contract stays owned by Feature 37 (server) and `tina4-js`
   (browser); this packet does not re-audit it.

## Audit closure checklist

- [x] Decision recorded: the browser helpers are a client asset, not a framework feature.
- [x] Source and build ownership (`tina4-js`, esbuild) recorded.
- [x] Vendored-bundle byte-identity measured across all four frameworks.
- [x] Recorded that the vendored `public/js/` STAYS (served; dev-admin + CSRF depend on it).
- [x] The one real cross-boundary contract (CSRF token handshake) pointed to its owner (Feature 37).
- [x] No four-language framework parity contract is owed here.
- [x] Vendoring-drift owner decision recorded for ratification.
