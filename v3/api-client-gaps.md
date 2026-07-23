# Task: Api client — close the Guzzle-gap set across all 4 frameworks

## Goal
Add the four `Api` HTTP-client capabilities the owner approved (multipart uploads,
streaming downloads, an injectable transport seam, redirect-following + a cookie
jar) to all four frameworks, Python-master-first, with real no-mock tests — while
keeping the zero-dependency promise.

## Context
The `Api` client is a deliberate zero-dep client (Python urllib, PHP
`file_get_contents` stream context, Ruby `Net::HTTP`, Node `node:http`/`https`).
Owner question this session was "what are we missing vs Guzzle + should it be
mockable"; owner approved building all four gaps and asked for a plan first.

**Grounded current state (read the source 2026-07-10 — NOT uniform):**

| Capability            | Python (master)                          | PHP            | Ruby                         | Node           |
|-----------------------|------------------------------------------|----------------|------------------------------|----------------|
| Multipart / uploads   | ❌ (json/str/bytes only)                 | ❌             | ✅ `upload()` already exists | ❌             |
| Streaming download    | ❌ buffers `resp.read()`                 | ❌ buffers     | ❌ buffers                   | ❌ buffers     |
| Transport seam (inject)| ⚠️ module-level `_open` (not injectable) | ❌            | ❌                           | ⚠️ `transport` = http/https only |
| Redirect follow       | ✅ + cross-origin auth strip             | ⚠️ verify\*    | ❌ (Net::HTTP no auto-follow)| ❌ (http.request no auto-follow) |
| Cookie jar            | ❌                                       | ❌             | ❌                           | ❌             |
| Retry + backoff       | ✅                                       | ✅             | ✅                           | ✅             |
| kwarg/opts ctor sugar | ✅                                       | ✅             | ✅                           | ✅             |

\* PHP's http stream wrapper defaults `follow_location=1`, so `file_get_contents`
may already follow redirects **without** the cross-origin Authorization strip that
Python has — a potential token-leak. `tina4-php/CLAUDE.md` currently claims PHP
"does not auto-follow"; that claim must be empirically verified against real PHP,
not trusted (it may be wrong). See Open Questions.

## Governance decisions this surfaces (need owner sign-off)
1. **Multipart canonical shape.** Ruby already ships `upload(path, file_path,
   field_name: "file", extra_fields: {}, headers: {})`. Per [[feedback_python_master]]
   Python defines the canonical API; per [[feedback_no_aliases]] we do NOT leave
   Ruby with an alias. Proposed: adopt Ruby's shape as the canonical design
   (it's clean), implement it in Python master + PHP + Node, and rename/align
   Ruby's signature to match exactly if it diverges. Breaking-change to Ruby's
   `upload()` is acceptable for v3 ([[feedback_breaking_changes]]).
2. **Redirect parity target.** Bring PHP/Ruby/Node up to Python's behavior:
   follow redirects AND strip `Authorization` on a cross-origin hop. This is a
   security fix, not just a feature — flag it as such in release notes
   ([[feedback_contract_change_changelog]]) if PHP was leaking.

## Design (contract — identical across all 4, language-idiomatic names)
- **Multipart:** `upload(path, file_path, field_name="file", extra_fields={}, headers={})`
  builds a `multipart/form-data` body with a random boundary; also accept an
  in-memory bytes variant (no temp file). Returns the standard result dict.
- **Streaming download:** `download(path, dest_path)` (or `stream=True` on `get`)
  writes the response body to a file/stream in chunks instead of buffering — closes
  the OOM risk on large payloads. Returns `{http_code, headers, error, path}`.
- **Transport seam:** constructor `transport=` (callable/interface) returning
  `{http_code, body, headers, error}`. Default transport = the real network call.
  Tina4's own suite NEVER injects it (no-mock rule stands, [[feedback_no_mock_testing]]);
  it exists only so *users* can unit-test their own code. Formalizes Python's
  existing `_open` indirection into a public, injectable seam.
- **Redirect + cookie jar:** follow redirects with cross-origin auth strip (match
  Python); optional in-client cookie jar (accumulate `Set-Cookie` -> send `Cookie`)
  for session APIs, off by default.

## Scope checklist
### Python (master) — define the canonical contract first
- [x] multipart `upload()` + in-memory variant + real test (real local http.server, exact bytes+fields)
- [x] streaming `download()` chunked-to-file + real test (3MB body, 64KB chunks, no full buffer)
- [x] injectable `transport=` seam + real test (own suite injects a REAL alt transport, never a fake; canned-fake shown out-of-suite)
- [x] cookie jar (opt-in, off by default) + cross-origin auth/cookie strip on redirect confirmed by real test
### PHP / Ruby / Node parity (per framework: verify-then-build, real tests)
- [x] PHP: all four; **verified + fixed redirect auth-strip** via a manual redirect loop (`follow_location=0`, per-hop `Location`), zero new dep (stream wrapper; ext-curl NOT required). Committed to v3 (local, not pushed). PHP-idiomatic camelCase: `upload()`, `download()`, ctor `transport:`/`cookies:`. Real no-mock tests in `tests/ApiTransferTest.php` (two real `php -S` origins). PHP suite green at HEAD: 3735 tests / 9372 assertions, 0 failures (112 skipped = unprovisioned services locally).
- [x] Ruby: reconciled `upload()` to the canonical shape (BREAKING: `file_path:` now a keyword) + guessed part Content-Type + now sends default/auth headers; added `download()` (64 KB streamed), ctor `transport:`/`cookies:`, and a bounded redirect loop with cross-origin Authorization/Cookie strip. Zero new gems. Real no-mock tests in `spec/api_transfer_spec.rb` (raw-TCPServer loopback + two real origins for redirect). Committed to v3 (local, not pushed) — tina4-ruby d5916d3. Verified macOS/Ruby 4.0.2: api specs 49/0; full suite green minus PostgreSQL specs (no local `pg` gem: 14 nil-connection failures, identical on baseline, unrelated).
- [x] Node: all four (upload/download/transport seam/cookie jar + redirect follow with cross-origin Authorization+Cookie strip). Zero new deps (node:http/https/crypto/fs/path/stream). TS-idiomatic camelCase opts: `upload(path, { filePath|fileBytes, fieldName, extraFields, headers, filename })`, `download(path, destPath, params?)`, ctor `transport:`/`cookies:`. Result-dict keys stay snake_case (`http_code`) for parity with the existing ApiResult + Python/PHP/Ruby. Real no-mock tests in `test/apiTransfer.test.ts` (52 assertions, real local http.Server origins; transport-seam test injects a REAL alternate transport doing real socket I/O). Committed to v3 (local, not pushed): commit a40b672. Node suite green at HEAD: 5332 passed / 9 failed (the 9 are pre-existing service-gated Postgres+Valkey files, verified identical on baseline via stash) + i18n vitest 44/44; `npm run typecheck` clean.
### Cross-cutting
- [ ] Docs: `Api` sections in all relevant CLAUDE.md + book/docs chapter ([[feedback_doc_writing]], ASCII-only)
- [ ] Release notes incl. any "Breaking:" (Ruby upload rename, PHP redirect security)
- [ ] Independent verification: re-run all 4 suites at HEAD myself ([[feedback_independent_verification]])
- [ ] Merge locally to v3, no PR ([[feedback_release_branching]]); hold for a coordinated release

## Tests (written first, real — no mocks, positive + negative)
- [x] (PY) upload posts a real file to a real local server; server receives correct bytes + fields
- [x] (PY) upload with missing file / no source errors cleanly (negative; nothing sent)
- [x] (PY) download streams a 3MB body to disk; file bytes == source; not fully buffered
- [x] (PY) transport seam: framework suite injects a REAL alt transport (real socket I/O, no mock);
      canned-fake user pattern proven in a dedicated scratchpad example, NOT the framework suite
- [x] (PY) redirect: 302 cross-origin drops Authorization AND Cookie (absent at target); same-origin keeps it
- [x] (PY) cookie jar: Set-Cookie on response sent as Cookie on next request; NOT sent when cookies=False (negative)

## Open questions
- [x] **ANSWERED (2026-07-10, empirical, real two-origin localhost probe):** PHP's http stream
      wrapper (`file_get_contents`/`fopen`) **DOES auto-follow redirects by default** (`follow_location`
      defaults to 1) **AND forwarded both `Authorization` and `Cookie` to the cross-origin 302 target**
      — i.e. PHP **WAS LEAKING** a bearer token / session cookie on a cross-origin hop. The prior
      `tina4-php/CLAUDE.md` claim ("does not auto-follow ... auth-strip is Python-only") was FALSE and
      is corrected. Fix: manual redirect loop with `follow_location=0`, reading `Location` per hop and
      dropping `Authorization`+`Cookie` on a cross-origin hop (same rule as Python). Ships as a
      **Breaking/Security:** note in 3.13.69. (`follow_location=0` + `ignore_errors=1` reliably exposes
      the `Location` via `wrapper_data`, so the manual loop stays zero-dep — no curl.)
- [ ] Cookie jar default: off (opt-in) confirmed? Any persistence, or in-memory per-client only?
- [ ] `download()` API shape: separate method vs `get(..., stream=dest)` — owner preference?

## Bugs
- [ ] (log here as [ ], tick when a real test proves it fixed)

## Commits
- (Python master) tina4_python/api/__init__.py + tests/test_api_transfer.py — upload()/download()/
  transport seam/cookie jar; committed to v3 (local, not pushed). Canonical contract for the ports:
  - `upload(path="", file_path=None, field_name="file", extra_fields=None, headers=None, file_bytes=None, filename=None) -> dict`
  - `download(path="", dest_path=None, params=None) -> dict`  (returns {http_code, headers, error, path}; no body)
  - ctor kwargs `transport=None` (callable `(method,url,headers,body,timeout)->{http_code,body,headers,error}`) and `cookies=False`
  - boundary: `----Tina4Boundary` + `secrets.token_hex(16)` (32 hex); parts = text fields FIRST then file, `\r\n` delims, closing `--boundary--`
  - part Content-Type guessed via mimetypes (fallback application/octet-stream) — Ruby currently hardcodes octet-stream; align it
  - download chunk size 64KB; cookie parse = leading `name=value` of each Set-Cookie, last-wins; cross-origin redirect strips Authorization AND Cookie
- (PHP) Tina4/Api.php + tests/ApiTransferTest.php + tests/fixtures/api_transfer_server.php — upload()/download()/
  transport seam/cookie jar/manual redirect loop w/ cross-origin strip; committed to v3 (local, not pushed).
  PHP-idiomatic camelCase, external behavior identical to Python. Boundary `----Tina4Boundary` + `bin2hex(random_bytes(16))`
  (32 hex). Part Content-Type via a small zero-dep extension map (no ext-fileinfo). `attempt()` 4-arg protected seam
  preserved (ScriptedApi retry tests unchanged); retry loop refactored to a shared `withRetry(callable)`. CLAUDE.md Api
  section corrected (redirect leak). Empirical redirect finding recorded in Open questions.
- (Ruby) lib/tina4/api.rb + spec/api_transfer_spec.rb — upload()/download()/transport seam/cookie jar/
  bounded redirect loop w/ cross-origin Authorization+Cookie strip; committed to v3 (local, not pushed) — d5916d3.
  Ruby-idiomatic snake_case + keyword args, external behavior identical to Python. BREAKING: `upload()` `file_path`
  is now a keyword (was a required positional); no alias. Boundary `----Tina4Boundary` + `SecureRandom.hex(16)`
  (32 hex). Part Content-Type via a small zero-dep extension map (Ruby core has no mimetypes; guess-with-fallback
  to application/octet-stream). download() returns an APIResponse carrying `path` (body nil) — Ruby-consistent vs a
  bare Hash. upload() now also sends the client default/auth headers (old Ruby upload omitted them — a latent bug).
  `execute(uri, request)`/`attempt_request` retry structure preserved (existing api_spec retry/verify_ssl tests
  unchanged). Ruby CLAUDE.md Api section NOT yet updated (still says redirect auth-strip is "Python-only" + old
  upload sig) — deferred to the cross-cutting Docs item so all 4 land coordinated (feedback_doc_writing).

## Status: SHIPPED in 3.13.69 (2026-07-10). Published + verified live on all 4 registries. Tags 3.13.69 on v3. Commits: Py 394eb6b, PHP 04ec84ec, Ruby d5916d3, Node a40b672 (+ per-repo 3.13.69 bump commits). PHP redirect leak = Security fix; Ruby upload() = Breaking. Docs + release notes shipped (docs 55b5a11). See [[project_release_3_13_69]].

### Resolved decisions (owner, 2026-07-10)
- Governance 1 ACCEPTED: adopt Ruby's `upload()` shape as the canonical multipart API; align Ruby's signature to it (no alias), implement in Python master + PHP + Node.
- Governance 2 ACCEPTED: redirect parity = follow + cross-origin Authorization strip in PHP/Ruby/Node; ships with a "Breaking/Security:" note if PHP was leaking.
- OQ1: verify PHP redirect+auth behavior empirically against real PHP; correct CLAUDE.md either way.
- OQ2: cookie jar OFF by default, in-memory per-client (no persistence).
- OQ3: streaming download is its OWN method `download(path, dest_path)`, not a `stream=` flag on `get`.
