# Feature 041: Static assets and cache revalidation

## Identity and status

- Matrix identity: 41 - Static assets and cache revalidation
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (PHP `StaticFiles.php`, Node
  `static.ts`, Python/Ruby static serving in their servers). No framework code changed.
- Dependencies: Feature 40 (ETag/compression/304 revalidation), Feature 30 response model
  (its `file()` confinement is the same traversal rule), Feature 31 router (static routes fall
  through after dynamic ones)
- Dependants: every SPA/Vite build, every JS/CSS/image asset, the Swagger UI assets
- Existing ADRs: ADR-0050 (response model, including `file()` root confinement and traversal
  rejection)
- Shared fixtures: `static_assets_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

An application ships JavaScript, CSS, images and an `index.html`, and the framework serves them
from a public directory with the right content type, a revalidation policy, and a path guard
that a request cannot escape - the same way in all four languages.

## Boundary

This feature owns public-directory resolution, extension-to-MIME mapping, the `Cache-Control`
policy, directory-traversal protection, and index-file resolution. It DELEGATES the ETag, the
304 revalidation and compression to Feature 40, the response carriage to Feature 30, and the
same-file traversal confinement rule to Feature 30's `file()` (ADR-0050). It does not own
dynamic routing.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Handler | server static path | `StaticFiles.php` | `api.rb` static | `static.ts` |
| Public dir | app public | `TINA4_PUBLIC_DIR` override, app public | app public | `staticDir` |
| Traversal guard | (to confirm) | string `str_contains($path, '..')` | (to confirm) | prevent traversal |
| MIME by extension | yes | yes | yes | `MIME_TYPES[ext]`, fallback `application/octet-stream` |
| Cache-Control | `no-cache, must-revalidate` | `no-cache, must-revalidate` | same | `no-cache, must-revalidate` |
| Index resolution | `/`,`/foo/` -> index.html | same (SPA/Vite) | same | join(dir, path, index.html) |
| ETag / 304 | via Feature 40 | via Feature 40 | via Feature 40 | `W/"size-mtime"` (Feature 40) |

The static handlers agree on the important behaviour: serve a file from the public directory,
set the content type from the extension (falling back to `application/octet-stream`), send
`Cache-Control: no-cache, must-revalidate` so the browser revalidates via the Feature 40 ETag
rather than serving blindly from cache, and resolve `/` or `/foo/` to `index.html` so a SPA or
Vite build serves at its URL. The one place to scrutinize is the traversal guard: PHP rejects
any path containing `..` with a string check (`str_contains($path, '..')`), which is blunt and
must be confirmed as robust and identical in the other three (a string check can miss an
encoded or symlink escape that a realpath-confinement check catches).

## Public surface contract

Static serving is automatic: a GET whose path maps to a file under the public directory returns
that file with its content type and `Cache-Control: no-cache, must-revalidate`; a directory or
root path resolves to `index.html`; a path that would escape the public directory is rejected.
The ETag and 304 revalidation come from Feature 40. The public directory is the app's public
folder, overridable by `TINA4_PUBLIC_DIR`.

## Inputs and outputs

- Input: a request path, the public directory (and its `TINA4_PUBLIC_DIR` override), and the
  request's `If-None-Match` (for revalidation).
- Output: the file bytes with its content type and `Cache-Control: no-cache, must-revalidate`,
  a 304 when the ETag matches, or a 404 when no file resolves, or a rejection when the path
  escapes the directory.
- A directory or root path outputs `index.html` when present.
- The content type is the extension's MIME type, else `application/octet-stream`.

## Lifecycle and operation graph

1. A request falls through to static serving after dynamic routing finds no match.
2. The path is resolved against the public directory (TINA4_PUBLIC_DIR override, then app
   public), and confined so it cannot escape the directory.
3. `/` or a trailing-slash path resolves to `index.html`.
4. The file's content type is set from its extension; `Cache-Control: no-cache, must-revalidate`
   is set.
5. Feature 40 computes the `W/"size-mtime"` ETag and returns 304 when `If-None-Match` matches;
   otherwise the bytes are sent (compressed when negotiated).

## Configuration and precedence

- `TINA4_PUBLIC_DIR` overrides the public directory; otherwise the app's public folder is used,
  searched in a defined order.
- `Cache-Control: no-cache, must-revalidate` is the fixed policy for a served asset, so the
  browser always revalidates via the ETag rather than trusting a stale cache.
- Static serving runs AFTER dynamic routing, so an application route wins over a same-path file.

## Failures, side effects and security

- SECURITY: the traversal guard must CONFINE the resolved path to the public directory, so no
  request can read outside it. A robust guard resolves the real path and checks it is within the
  directory (matching Feature 30's `file()` confinement, ADR-0050); a bare string `..` check is
  weaker and must be proven equivalent or replaced. This is the security surface of the feature.
- A path that resolves outside the public directory is rejected (404 or 403), never served.
- `no-cache, must-revalidate` prevents a browser from serving a stale asset without checking the
  ETag, so a deploy's new bytes are picked up on the next revalidation.
- A directory listing is never produced; a directory resolves to `index.html` or 404s.
- The MIME fallback `application/octet-stream` means an unknown type downloads rather than
  executing inline, which is the safe default.

## Wire and persistence contract

There is no persistence; the wire contract is the file bytes, the `Content-Type`, the
`Cache-Control: no-cache, must-revalidate` header, and the Feature 40 ETag/304. These are
identical across the four for the same file and request.

## Providers and substitutability

Static serving is transport-level and engine-agnostic. A future runtime resolves the same public
directory with the same override, applies the same confinement, the same MIME mapping, the same
`Cache-Control`, and the same index resolution.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| ST-01 | The traversal guard differs (PHP string `..` check; others to confirm); a weak guard is a path-escape vulnerability. | Pin ONE robust confinement (resolve the real path, confirm it is inside the public directory, matching Feature 30's `file()`); gate an escape attempt (`../../etc/passwd`, encoded, and a symlink) rejected in all four. |
| ST-02 | The `Cache-Control: no-cache, must-revalidate` policy is converged but not gated. | Gate the header on a served asset in all four. |
| ST-03 | Index resolution (`/`, `/foo/` -> index.html) is converged but not gated. | Gate root/dir-to-index resolution in all four. |
| ST-04 | Public-directory resolution (`TINA4_PUBLIC_DIR` override + app public + order) is not gated as parity. | Gate the override and the default in all four. |
| ST-05 | The extension-to-MIME map (and the `application/octet-stream` fallback) is not gated. | Gate a representative MIME set and the fallback in all four. |
| ST-06 | The ETag/304 revalidation is Feature 40's; its interaction with static serving is not gated here. | Gate a 304 on a matching `If-None-Match` for a static asset in all four (with Feature 40). |
| ST-07 | No shared fixture exists. | Add `static_assets_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. ONE robust traversal confinement in all four: resolve the real path and confirm it is inside
   the public directory (the same rule as Feature 30's `file()`, ADR-0050). A bare string `..`
   check is replaced or proven equivalent. This is the security decision this row exists to
   settle.
2. A served asset carries `Cache-Control: no-cache, must-revalidate`, so the browser always
   revalidates via the Feature 40 ETag.
3. `TINA4_PUBLIC_DIR` overrides the public directory; otherwise the app public folder is used in
   a defined search order.
4. `/` and a trailing-slash path resolve to `index.html` (SPA/Vite support); a directory is
   never listed.
5. The content type is the extension's MIME type, with `application/octet-stream` as the safe
   fallback.

## Proposed conformance fixture

Add `static_assets_contract.json` with stable ids for: serving a CSS/JS/image with the right
content type and `Cache-Control: no-cache, must-revalidate`; a root and a trailing-slash path
resolving to `index.html`; a traversal attempt (`../../etc/passwd`, a percent-encoded variant,
and a symlink pointing outside) REJECTED; `TINA4_PUBLIC_DIR` overriding the directory; an unknown
extension falling back to `application/octet-stream`; a dynamic route winning over a same-path
file; and a 304 on a matching `If-None-Match`. Every case serves a real file over a real request
from a real directory; no mock can claim conformance (a mocked filesystem would not prove the
traversal confinement).

## Integration map

- Feature 31 routes dynamic requests first; static serving is the fallthrough. Feature 40
  supplies the ETag/304/compression; Feature 30's `file()` shares the confinement rule.
- The Swagger UI assets are served through this path (gated by `TINA4_SWAGGER_ENABLED`).
- Central fixtures, four runners, the CI matrix and the static/deployment docs update together.

## Breaking changes and migration

- If a framework's traversal guard is found weaker than the confinement rule, hardening it is a
  security fix; a legitimate asset path is unaffected. `Breaking:` only if an app relied on a
  path that a robust guard now rejects (which would itself have been an escape).
- No change to the served content or the Cache-Control policy (converged).

## Implementation backlog

1. Add `static_assets_contract.json` and wire four runners against a real public directory.
2. Pin and gate the robust traversal confinement (ST-01) in all four, including an escape and a
   symlink case.
3. Gate the Cache-Control policy (ST-02), index resolution (ST-03), public-dir config (ST-04)
   and the MIME map/fallback (ST-05).
4. Gate the static 304 revalidation with Feature 40 (ST-06).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Serve files from the public directory (resolved with a `TINA4_PUBLIC_DIR` override) after
dynamic routing. Confine the resolved real path inside the public directory and reject any
escape (matching Feature 30's `file()`). Set the content type from the extension with an
`application/octet-stream` fallback, send `Cache-Control: no-cache, must-revalidate`, and
resolve `/` or a trailing-slash path to `index.html`. Let Feature 40 add the ETag and the 304.
Prove the port with a served asset, an index resolution, a rejected traversal (including a
symlink), and a 304.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (ST-01..07).
- [x] Owner ambiguities recorded (5 proposed; the traversal-confinement security call is key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
