# Feature 099: Local realtime attachment storage

## Identity and status

- Matrix identity: 99 - Local realtime attachment storage
- Audit state: decision-ready
- Audit note: measured 2026-08-10 as part of the realtime extractions (feature 098) at Python `386cd6d`,
  PHP `743b7469`, Ruby `c61250c`, Node `26be920`. LocalStorage is the zero-config default behind the
  `StorageBackend` seam. I verified the traversal guard in each. No framework code changed.
- Dependencies: feature 098 (the realtime file plane that uses it), the filesystem
- Dependants: every realtime deployment that has not configured S3 (this is the default)
- Existing ADRs: none specific; follows the cache/session/queue backend-selection pattern (a provider is
  an env var, ADR-0024)
- Shared fixtures: covered by the proposed `realtime_contract.json` (feature 098); no separate fixture
- Catalog phase: Integration providers

## Why this feature exists

A realtime deployment needs file attachments to work with ZERO configuration and ZERO dependency in
development. `LocalStorage` stores attachment blobs on the local filesystem behind the `StorageBackend`
interface, traversal-safe, so an app shares files immediately and switches to S3 (100) in production by
setting one env var - with no call-site change.

## Boundary

This packet owns the FILESYSTEM realization of the `StorageBackend` interface (feature 098): `put`/`get`/
`delete`/`exists` on disk, the traversal guard, and the opaque storage key. The interface + the file
routes belong to 098; the S3 backend is 100.

## Existing implementation evidence

LocalStorage implements the full `StorageBackend` surface in all four, traversal-safe:

| StorageBackend method | LocalStorage |
| --- | --- |
| put(key, data, mime) | full - writes the blob to `TINA4_STORAGE_DIR/<key>` |
| get(key) | full - reads the bytes, returns null on a missing/unsafe key |
| url(key, ttl) | returns null (served by the permissioned 098 download route, not a redirect) |
| delete(key) / exists(key) | full - no-op / false on a missing or unsafe key |
| traversal guard | rejects any key that escapes the directory (Python `os.path.commonpath`; PHP/Node `resolve` + `startsWith(dir + sep)`; Ruby `File.expand_path` + `start_with?`) |

The storage key is opaque random hex + a sanitized extension (no user path segment), so a traversal key
never even reaches the guard in normal use - the guard is defence in depth. `is_serverless()`-style: it
opens no network connection.

## Public surface contract

Selected by default (`TINA4_STORAGE_BACKEND` unset or `local`). It exposes exactly the `StorageBackend`
surface. `url()` returns null - a local attachment is served by the permissioned download route (098),
not a redirect. The store directory is `TINA4_STORAGE_DIR` (default `data/rt_storage`).

## Inputs and outputs

- Input: an opaque storage key, blob bytes, a mime type; a store directory.
- Output: the stored bytes on `get`; null/false on a missing or unsafe key (never a raise on read); a
  raise on an unsafe key at `put` (the traversal guard).

## Lifecycle and operation graph

`put` resolves the key against the directory (raising if it escapes) and writes the blob; `get`/`exists`/
`delete` resolve and read/test/remove, swallowing a missing-file or unsafe-key into null/false/no-op. The
098 upload route calls `put` after a membership check; the 098 download route calls `get` and streams the
bytes (since `url()` is null).

## Configuration and precedence

- `TINA4_STORAGE_BACKEND` = `local` (or unset) selects it. `TINA4_STORAGE_DIR` (default `data/rt_storage`)
  sets the directory. Explicit config wins.

## Failures, side effects and security

- TRAVERSAL SAFETY (the security core): a key that escapes the store directory is rejected in all four -
  Python `os.path.commonpath([dir, target]) != dir`, PHP/Node `resolve` then `startsWith(dir + sep)` (the
  `+ sep` guard defeats a sibling-prefix escape like `store-evil`), Ruby `File.expand_path` +
  `start_with?(dir + SEPARATOR)`. Combined with opaque random-hex keys, a traversal is unreachable from
  the file plane. Python's traversal test is real; the others' traversal-unit coverage is thin (feature
  098 RT-04).
- The store is a local file readable by the app user; attachments are plaintext on disk. No network
  surface.
- `get`/`exists`/`delete` never raise on a missing or unsafe key - they degrade to null/false/no-op, so a
  stale attachment reference is a clean miss, not a crash.

## Wire and persistence contract

Blobs on the filesystem under `TINA4_STORAGE_DIR`, named by the opaque storage key. The attachment
metadata (key, filename, mime, size) lives in the `tina4_rt_attachments` table (098). `url()` is null, so
delivery is the permissioned download route, not a presigned redirect - the difference from S3 (100).

## Providers and substitutability

The default provider behind `StorageBackend` and the imitation reference the S3 backend (100) is measured
against. Setting `TINA4_STORAGE_BACKEND=s3` swaps to S3 with no call-site change (the 098 upload/download
routes are backend-agnostic); the only behavioural difference is `url()` (null here, a presigned URL on
S3, which turns the download into a 302 redirect).

## Contradictions and defects

No open contract defects - LocalStorage is functionally correct and traversal-safe in all four. The
coverage gap (the traversal guard and the file routes are under-tested outside Python) is tracked as
feature 098 RT-04. A minor cosmetic drift: the storage-key extension sanitizer keeps `._-` in Python and
strips them in Ruby/PHP - both safe, extension-only.

## Owner decisions

None specific to LocalStorage. The cross-cutting coverage item (RT-04) and the fixture (RT-05) live in
098.

## Proposed conformance fixture

Covered by `realtime_contract.json` (098): a blob round-trips through LocalStorage (put -> get returns
the same bytes), a traversal key is rejected, and a missing key returns null - alongside the S3 leg. No
separate fixture is owed.

## Integration map

- Selected by default via `TINA4_STORAGE_BACKEND`; used by the 098 file routes; the counterpart to the S3
  backend (100).
- The traversal guard is the security-relevant seam; the opaque storage key is generated by the 098/
  storage layer.

## Breaking changes and migration

None. LocalStorage behaviour (traversal-safe filesystem, null `url()`) is stable across the four.

## Implementation backlog

1. Add a real traversal-guard unit test where missing (Ruby/PHP/Node) - tracked as feature 098 RT-04.
   Nothing on the backend itself.

## Porting capsule

Implement a filesystem `StorageBackend`: `put(key, data, mime)` writing the blob under `TINA4_STORAGE_DIR`
after resolving the key and RAISING if it escapes the directory (resolve + `startsWith(dir + separator)`,
or a canonical-path containment check); `get`/`exists`/`delete` resolving and reading/testing/removing,
returning null/false/no-op on a missing or unsafe key (never raising on read); and `url()` returning null
(local attachments are served by the permissioned download route, not a redirect). Use opaque random-hex
storage keys so a user path never reaches the guard. Prove it in `realtime_contract.json`: a round-trip,
a rejected traversal key, and a clean missing-key miss.

## Audit closure checklist

- [x] Boundary and public surface complete (the filesystem backend; interface + routes are 098).
- [x] Lifecycle and every producer/consumer edge complete (put/get/delete/exists on disk).
- [x] Configuration, failure, side-effect and security rules complete (traversal guard, degrade-not-raise, plaintext-on-disk).
- [x] Wire/storage and provider contracts complete (blobs on disk; metadata in tina4_rt_attachments; null url()).
- [x] Existing-language contradictions recorded (none open; coverage gap tracked in 098 RT-04).
- [x] Owner ambiguities recorded (none specific).
- [x] Proposed shared cases and mutation witnesses complete (the local leg of `realtime_contract.json`).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
