# Feature 41: Static asset serving

## Identity and status

- Matrix identity: 41 - Static asset serving
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source (correcting a prior-session doc whose security
  finding was INVERTED - it called PHP's guard "blunt" when PHP is the ONLY one that confines a symlink
  escape; Python/Ruby/Node do not). Python `core/server.py:2851` `_try_static` + `core/response.py:365`
  (`ebbab30`); PHP `Tina4/StaticFiles.php:72` (`6faabac5`); Ruby `lib/tina4/rack_app.rb:188` (`6d5b1de`);
  Node `packages/core/src/static.ts:25` (`27cf0f4`).
- Dependencies: the router (static runs after routing), the response builder, the ETag path (40).
- Dependants: any app serving CSS/JS/images from a public dir.
- Existing ADRs: ADR-0050 (file confinement); ADR-0010 (routes beat files).

- Catalog phase: Routing and middleware

## Why this feature exists

Serving a file from a public directory must NEVER let a crafted path read a file outside that directory. The
audit question is whether the traversal guard actually confines in all four. It does not: PHP resolves the
real path and confines it; Python, Ruby, and Node use a bare lexical `..` check that a symlink (and, in Node,
a sibling-prefix) defeats. The prior doc had this exactly backwards.

## Existing implementation evidence

- HANDLERS: Python `_try_static` (`server.py:2851`); PHP `StaticFiles::tryServe` (`StaticFiles.php:72`); Ruby
  `try_static`/`serve_static_file` (`rack_app.rb:188`, NOT `api.rb` as the prior doc said); Node
  `tryServeStatic` (`static.ts:25`). Static runs AFTER dynamic routing in all four (ADR-0010).
- TRAVERSAL GUARD - diverges, and only PHP is robust:
  - PHP (`StaticFiles.php:75,130-141`): lexical `..` reject PLUS `realpath()` + `str_starts_with($realPath,
    $realDir . DIRECTORY_SEPARATOR)` - resolves symlinks and confines under the root (the trailing separator
    defeats the sibling-prefix escape). Blocks `../`, absolute, AND symlink. Reference quality.
  - Python (`response.py:365`): only `".." in raw.parts` (the realpath containment at `:395` is gated on a
    `root` that static serving never passes). `raw.resolve()` follows symlinks with no containment. Blocks
    `../`, NOT symlink.
  - Ruby (`rack_app.rb:189`): only `path.include?("..")`; `File.file?` follows symlinks. Blocks `../`, NOT
    symlink.
  - Node (`static.ts:53`): only `filePath.startsWith(staticDir)` (no trailing separator, no realpath);
    `statSync` follows symlinks. Blocks `../` (incidentally, via URL normalization + `join`), NOT symlink,
    and a sibling-prefix (`/app/publicsecret`) is latent via the malformed-URL fallback.
- MIME: a hardcoded map in PHP/Ruby/Node; Python uses stdlib `mimetypes` (so its Content-Type differs, e.g.
  no `; charset=utf-8`).
- CACHING: `Cache-Control: no-cache, must-revalidate` in all four; ETag format diverges four ways (see 40 -
  Python strong md5; PHP `W/"mtime-size"` dec; Ruby hex; Node `W/"size-mtimeMs"`).
- `TINA4_PUBLIC_DIR` override is read only by Python and PHP; Ruby and Node ignore it. The search-dir SET and
  ORDER differ across all four (Ruby adds `src/assets`/`assets`).
- No auto directory listing anywhere. No hidden/dotfile block anywhere (a `public/.env`, if present, serves).

## Public surface contract

A GET for a file under the public dir returns the file with a MIME Content-Type, `Cache-Control`, and an ETag,
and 304s on a match. A path that escapes the public dir must be refused - and today only `../` is refused
everywhere; a symlink escape is refused only by PHP.

## Inputs and outputs

- Input: a GET/HEAD path + conditional headers. Output: the file bytes + headers, a 304, or a 404.

## Lifecycle and operation graph

1. Routing misses -> static handler. 2. Reject `..`; resolve candidate under the public dir(s). 3. (PHP only)
realpath-confine. 4. Set MIME + Cache-Control + ETag; 304 on a match; else send (HEAD strips the body).

## Configuration and precedence

- Public dir: `TINA4_PUBLIC_DIR` (Python `server.py:2883`, PHP `StaticFiles.php:104`); Ruby/Node do NOT read
  it. Search order differs per language. Routes beat static (ADR-0010).

## Failures, side effects and security

- SECURITY (the crux): static serving does NOT confine a symlink escape in Python/Ruby/Node - a symlink placed
  inside the public dir that targets outside is served. Only PHP confines (realpath + separator). Node
  additionally has a latent sibling-prefix escape. No language blocks a dotfile (`public/.env` serves). This
  is the real, inverted ST-01. See the register.
- A missing file 404s; no directory listing is ever produced.

## Wire and persistence contract

The file bytes + `Content-Type` + `Cache-Control` + an ETag. The wire is NOT identical across the four (ETag
format, some Content-Types, and 304 comparison all differ - see the register and feature 40).

## Providers and substitutability

Transport-level. A future runtime must resolve the real path and confine it under the public root (PHP's
model), block dotfiles, and use the agreed ETag format.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| ST-SYMLINK-ESCAPE | SECURITY, Python/Ruby/Node: static serving does NOT confine a symlink inside the public dir that targets outside - Python `response.py:372` resolves with no containment (the `root` guard is never passed by static), Ruby `rack_app.rb:206` `File.file?` follows, Node `static.ts:49` `statSync` follows behind a lexical guard. PHP alone confines (`StaticFiles.php:130-141` realpath + separator). The prior doc INVERTED this (called PHP's guard "blunt"). | Adopt PHP's realpath + separator confinement as the reference (ADR-0050) and port it to Python (pass `root=` into `file()` or confine in `_try_static`), Ruby (`File.realpath` under-root check), and Node (`realpathSync` + `startsWith(staticDir + sep)`). |
| ST-NODE-SIBLING-PREFIX | SECURITY (latent), Node: the guard `filePath.startsWith(staticDir)` has NO trailing separator, so `/app/publicsecret` matches the `/app/public` root; reachable via the malformed-URL fallback (`request.ts:69-80`) that passes the raw target unnormalized. | Confine with `staticDir + path.sep` (folded into ST-SYMLINK-ESCAPE's realpath fix). |
| ST-DOTFILE-UNBLOCKED | All four: no hidden/dotfile block - a `public/.env`, `.git`, or `.htpasswd` served if present (only PHP's `.php` refusal exists). | Block a leading-dot path segment (or an allow-list of extensions) in all four. |
| ST-ETAG-DIVERGENCE | The static ETag format diverges four ways and the 304 comparison differs (Python strong-exact vs weak-comparison in the other three) - the prior doc's "identical wire contract" is false. Cross-refs feature 40 CE-STATIC-ETAG-DIVERGENCE. | Pin ONE static ETag format + 304 semantics across the four (with feature 40's CE-DEC-02). |
| ST-PUBLICDIR-ENV-PARTIAL | `TINA4_PUBLIC_DIR` is honoured only by Python and PHP; Ruby and Node ignore it (grep-empty), so the documented override silently does nothing in two languages. | Read `TINA4_PUBLIC_DIR` in Ruby and Node. |
| ST-SEARCHDIR-DIVERGE | The public search-dir SET and ORDER differ four ways (Python `public,src/public,fw`; PHP `src/public,public,fw`; Ruby adds `src/assets,assets`; Node `public,src/public,builtin`), so the same relative path can resolve to different files per language. | Agree ONE search set + order. |
| ST-INDEX-DIVERGE | An extensionless `/foo` resolves to `foo/index.html` in PHP/Ruby/Node but NOT Python (`server.py:2881` only treats `""`/trailing-slash as an index). | Unify the index-resolution rule. |
| ST-DELEGATE-FALSE | The prior doc claimed static "delegates confinement to Feature 30 `file()` (ADR-0050)"; FALSE - only Python static calls `Response.file()`, and it passes NO `root`, so `file()`'s containment is inactive; PHP/Ruby/Node have standalone handlers. | Correct the boundary text; make static actually use the confinement (ST-SYMLINK-ESCAPE). |
| ST-NO-FIXTURE | No shared `static_assets_contract.json` exists. | Add it once ST-DEC-01/02 land. |

## Owner decisions

> **RATIFIED 2026-08-11 - OWNER-DECIDED.** The DEC-* below are ratified by the owner (Andre); see [../OWNER-DECISIONS.md](../OWNER-DECISIONS.md) for the exact call. Next phase: implementation in all four frameworks with real (no-mock) tests.

- ST-DEC-01 (proposed, SECURITY - top priority, and INVERTED from the prior doc): adopt PHP's realpath +
  separator confinement (`StaticFiles.php:130-141`) as the reference and port it to Python/Ruby/Node so a
  symlink and sibling-prefix escape is blocked (ST-SYMLINK-ESCAPE, ST-NODE-SIBLING-PREFIX); block dotfiles
  (ST-DOTFILE-UNBLOCKED). PHP is the model here, not the problem.
- ST-DEC-02 (proposed): pin one static ETag format + 304 semantics (with feature 40), honour
  `TINA4_PUBLIC_DIR` in all four (ST-PUBLICDIR-ENV-PARTIAL), agree the search-dir set + order
  (ST-SEARCHDIR-DIVERGE), and unify extensionless-index resolution (ST-INDEX-DIVERGE).

## Proposed conformance fixture

A shared fixture (real files): a `../` escape is refused (all four); a SYMLINK inside the public dir pointing
outside is refused (catches ST-SYMLINK-ESCAPE - fails today in Python/Ruby/Node); a sibling-prefix path is
refused (Node); a `public/.env` dotfile is refused (ST-DOTFILE-UNBLOCKED); the same file yields the same
Content-Type, Cache-Control, and ETag in all four; `TINA4_PUBLIC_DIR` relocates the root in all four.

## Integration map

- Consumers: any static asset request. Composes: the router (ADR-0010 routes-beat-files), the ETag path (40),
  the response builder. The confinement rule is shared with feature 30 `file()` (ADR-0050).

## Breaking changes and migration

- Adding realpath confinement can refuse a previously-served symlink (a security fix - note it). Blocking
  dotfiles can 404 a previously-served hidden file (a security fix). Honouring `TINA4_PUBLIC_DIR` in Ruby/Node
  changes resolution where that env is set. Pinning the ETag format changes cache keys (a revalidation storm).

## Porting capsule

Serve a file under a public root ONLY after resolving its REAL path and confirming it is confined under the
root (realpath + a trailing-separator prefix check - PHP's model; a bare `..` string check is NOT enough,
it misses symlinks). Block dotfiles. Set a MIME Content-Type (agreed source), `Cache-Control`, and the agreed
ETag format; 304 on a weak-comparison match; strip the body on HEAD. Honour `TINA4_PUBLIC_DIR`. Never produce
a directory listing. Prove it with a `../` refusal, a symlink-escape refusal, and a dotfile refusal.

## Audit closure checklist

- [x] Boundary and public surface complete (handlers + confinement x four).
- [x] Lifecycle and producer/consumer edges complete (route-miss -> confine -> serve).
- [x] Configuration (TINA4_PUBLIC_DIR partial), failure and SECURITY (symlink/dotfile) rules complete.
- [x] Wire (MIME/Cache-Control/ETag) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (PHP is the reference guard; py/ruby/node miss symlinks) -
  correcting the prior INVERTED finding.
- [x] Owner ambiguities decided (ST-DEC-01 security, ST-DEC-02 unify).
- [x] Conformance fixture (symlink + dotfile + wire parity) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
