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
| Served-asset byte-identity FIXTURE | ABSENT - no `frondjs_served`-style contract exists (CSS has one, JS does not) |

Because the bundles are identical in all four, there is nothing per-language to keep in parity: a
compiled browser bundle is the same file wherever it is served. But note the gap in the last row:
the CSS half of this asset pair IS gated (`tina4css_contract.json`, ADR-0004, asserts all four serve
byte-identical `tina4.css`), and the JS half is NOT. Four packages ship an identical `frond.js` today
purely by discipline; nothing fails if one falls behind.

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

## The only cross-language contract is served-asset byte-identity (and it is NOT yet gated)

A per-language BEHAVIOUR contract exists when four frameworks must each implement the same logic.
Here they implement none: they serve identical compiled bundles that the client produced. So there
is no per-language JS surface to gate.

There IS one cross-language invariant: all four must serve the SAME `frond.js` (and the other
bundles) at one URL. Unlike the CSS side, that invariant is currently UNGATED - there is no
`frondjs_served` fixture the way `tina4css_contract.json` (ADR-0004) gates the stylesheet. The four
copies are byte-identical today (md5 `733bc95a...`) by convention alone. The natural gate is the JS
parallel of the CSS fixture: a served-asset contract that asserts every framework answers
`GET /js/frond.js` with identical bytes. See the owner decision.

## Owner decisions

Proposed for owner ratification:

1. The browser helpers are a CLIENT asset: the `tina4-js` repo owns the source and the build; the
   frameworks only vendor and serve the compiled bundles. No per-language BEHAVIOUR contract is
   owed; the one cross-language invariant is served-asset byte-identity.
2. Close the fixture gap. The CSS side of this vendored-asset pair is gated by
   `tina4css_contract.json` (ADR-0004); the JS side is not. Add the parallel served-asset fixture
   (a `frondjs_served`-style contract) asserting all four frameworks answer `GET /js/frond.js` (and
   the other bundles) with byte-identical content, wired into all four suites with a build-half
   checksum check. That closes the silent-drift risk the CSS fixture already closes for the
   stylesheet. The vendoring MECHANISM (commit per release vs pull-from-`tina4-js`-at-build) is the
   sub-decision.
3. The `frond.js` <-> server CSRF token contract stays owned by Feature 37 (server) and `tina4-js`
   (browser); this packet does not re-audit it.

## Audit closure checklist

- [x] Decision recorded: the browser helpers are a client asset, not a framework feature.
- [x] Source and build ownership (`tina4-js`, esbuild) recorded.
- [x] Vendored-bundle byte-identity measured across all four frameworks.
- [x] Recorded that the vendored `public/js/` STAYS (served; dev-admin + CSRF depend on it).
- [x] The one real cross-boundary contract (CSRF token handshake) pointed to its owner (Feature 37).
- [x] No per-language BEHAVIOUR contract is owed; the served-asset byte-identity invariant is
  recorded as currently UNGATED (unlike the CSS side), with the fixture to add.
- [x] Fixture-gap and vendoring-mechanism owner decision recorded for ratification.
