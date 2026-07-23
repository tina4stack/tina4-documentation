# Task: Static-asset cache-control (all 4 frameworks)

## Goal
The built-in static file handler (serving `public/` / `src/public/`) must let browsers
cache assets but force revalidation, so a redeployed asset reaches users on the next load
without a manual hard refresh.

## Context
The frameworks served static assets inconsistently: Node set NO cache headers at all (pure
heuristic caching -> stale JS/CSS after deploy -> "I already reported this" re-reports);
Python already had an ETag->304 pipeline but no explicit Cache-Control on static; PHP/Ruby
set cache headers only on the SSE path, not general static serving. Owner approved a
framework-level fix (2026-07-14). This is a real gap for front-end assets (tina4-js apps,
the dev dashboard bundle, any app's public/ JS/CSS) - NOT the cause of recent backend-bug
reports.

## Policy (identical across all 4 - the parity contract)
A static asset response carries:
- `Cache-Control: no-cache, must-revalidate`
- a validator: `ETag` (and/or `Last-Modified`)
And the handler answers a conditional request: `If-None-Match` match (or `If-Modified-Since`
>= mtime) -> `304 Not Modified`, no body. Net: redeploy reaches the browser next load;
unchanged assets cost a cheap 304, not a re-download. Zero new deps (stdlib only).

## Scope
- [x] Python master: `_try_static` sets `Cache-Control: no-cache, must-revalidate`; pipeline
      already computes an md5 ETag + honors If-None-Match -> 304 (server.py, response.py)
- [x] Python: no-mock test (real file via _try_static; asserts Cache-Control + ETag) GREEN
- [x] PHP parity + no-mock test (worker)
- [x] Ruby parity + no-mock test (worker)
- [x] Node parity (worst case - add ETag+Last-Modified+Cache-Control+304 to tryServeStatic) + test (worker)
- [x] Independent verify: re-run each full suite myself at HEAD
- [x] Docs + release notes (all 4), version bump, tag 3.13.75, publish

## Parity (all verified by me, independent re-run)
| Feature                              | Python | PHP | Ruby | Node |
|--------------------------------------|--------|-----|------|------|
| Cache-Control: no-cache on static    | ✅     | ✅  | ✅   | ✅   |
| ETag validator                       | ✅ md5 | ✅ weak | ✅ weak | ✅ weak |
| Last-Modified                        | ✅     | ✅  | ✅   | ✅   |
| If-None-Match -> 304                 | ✅     | ✅  | ✅   | ✅   |
| If-Modified-Since -> 304             | ✅     | ✅  | ✅   | ✅   |
| No-mock test (real file, real 304)   | ✅     | ✅  | ✅   | ✅   |
| Suite re-run by me                   | 3495   | 37+173 | 24 | 14+typecheck |

## Tests (real files, no mocks, positive + conditional-304)
- [x] Python: static response has Cache-Control: no-cache, must-revalidate + ETag (real file)
- [ ] PHP / Ruby / Node: same + a real If-None-Match -> 304 assertion

## Bugs
- (none yet)

## Commits
- 42d06eb  Python master: cache-control + ETag/Last-Modified + 304
- eb11c4c8 PHP parity (StaticFiles + Router header pass-through)
- d11a96e  Ruby parity (rack_app serve_static_file)
- d95ee33  Node parity (tryServeStatic - was worst case, no headers)
- f919eab/001fb94b/6d407e2/2856ed3  chore(release): 3.13.75 (4 frameworks)
- docs 4a0c499 / book eae9452 / CLI 096519e

## Status: SHIPPED 3.13.75 (2026-07-14) - all 4 registries live; docs+book+CLI pushed;
##   docs:build + audit-truth --strict + audit-links all GREEN before docs push
