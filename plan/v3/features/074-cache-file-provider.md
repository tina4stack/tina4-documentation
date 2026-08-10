# Feature 074: File cache provider

## Identity and status

- Matrix identity: 74 - File cache provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the file backend in each cache module) at
  Python `386cd6d`, PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: Feature 72 (interface + factory), the filesystem
- Dependants: any deployment on `TINA4_CACHE_BACKEND=file`; the graceful-fallback target for every
  networked cache backend
- Existing ADRs: ADR-0024 (interface), ADR-0032 (sweep returns count)
- Shared fixtures: `cache_contract.json` (8/8 PROVEN) exercises the file backend for every invariant.
- Catalog phase: Cache (providers)

## Why this feature exists

The file backend is the persistent cache that needs no service, and it is the graceful-fallback target
when a networked backend is unreachable (Feature 72). It writes each entry to a JSON file under
`TINA4_CACHE_DIR`, expires on read and on sweep, and survives a restart.

## Boundary

This feature owns the file backend's `get`/`set`/`delete`/`clear`/`sweep`: the on-disk file per entry,
the envelope shape, and the expiry. It DELEGATES selection and fallback to Feature 72. It is the cache
sibling of the session file provider (Feature 66) but stores CACHE entries (already-hashed keys), not
session records.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Filename | hashed cache key `.json` | same | same | same |
| Storage dir (`TINA4_CACHE_DIR`) | `data/cache` | same | same | same |
| Stored shape | `{key, value, expires_at}` envelope | same | same | same |
| Cached null (envelope unwrap) | HIT | HIT | HIT | HIT |
| `sweep()` unlinks expired, returns count | yes | yes | yes | yes |
| `clear()` unlinks every `*.json` | yes | yes | yes | yes |
| Atomic write | no (direct write) | no | no | no |
| File permissions | umask default | umask default | umask default | umask default |

The file cache backend is at parity and proven for the interface invariants. It shares two shared gaps
with the session file provider (Feature 66): no atomic write and no restrictive file permissions.

## Public surface contract

`get(key) -> value | miss` (read the JSON envelope, return `value`, a stored null is a HIT; a past
`expires_at` is a miss); `set(key, value, ttl)` (write `{key, value, expires_at}` to a file named for
the hashed key); `delete(key)` (unlink); `clear()` (unlink every `*.json` in the dir); `sweep() ->
evicted` (unlink expired files, return the count). The envelope distinguishes a stored null from a
miss.

## Configuration and precedence

`TINA4_CACHE_DIR` (default `data/cache`) is the storage directory. TTL is seconds. There is no service,
no credentials. Unlike the session file provider, the cache key is already a hash (the interface's
query key), so the filename derivation is a hash of a hash - no traversal surface from a raw id.

## Failures, side effects and security

- CRASH-TORN WRITE (FC-74-01, shared with Feature 66): no framework does a temp-file + atomic rename,
  so a crash mid-write can corrupt a cache file. A corrupt cache file is less severe than a corrupt
  session (a cache miss re-computes), but a torn write still surfaces as a parse error the read must
  treat as a miss.
- FILE PERMISSIONS (FC-74-02): the cache file is written at the default umask (world-readable). Cache
  data can be sensitive (a cached query result), so restrictive (0600) permissions are worth pinning -
  though the sensitivity is lower than a session credential.
- No injection surface: the filename is a hash of the already-hashed key.

## Wire and persistence contract

Each entry is a JSON file `{key, value, expires_at}` named for the hashed key. A stored null round-trips
via the envelope; a past `expires_at` is a miss (and the file is unlinked). The store survives a
restart, which is why it is the graceful-fallback target. The envelope shape is uniform across the
four.

## Providers and substitutability

The file backend is the persistent fallback and a first-class cache backend behind the Feature 72
interface. It substitutes any networked backend (with lower throughput but no service). It is the cache
analog of the session file provider (Feature 66); the two share the atomic-write and permissions gaps.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| FC-74-01 | No atomic write (temp+rename); a crash mid-write can corrupt a cache file (shared with the session file provider FP-01). | Temp-file + rename in all four (resolve together with Feature 66 FP-01). |
| FC-74-02 | The cache file is world-readable (umask default); cache data can be sensitive. | Create cache files 0600 in all four (resolve together with Feature 66 FP-02). |

Everything else is proven parity (cached-null, sweep-count, clear, ttl-seconds via
`cache_contract.json`).

## Owner decisions

Proposed for owner ratification:

1. ATOMIC WRITE + 0600 (FC-74-01, FC-74-02): resolve together with the session file provider (Feature
   66) - temp-file + rename and mode 0600 across both file backends in all four.

No other open questions - the file cache backend is proven parity.

## Proposed conformance fixture

`cache_contract.json` already gates the file backend for every invariant. Add the two shared file cases
(shared with Feature 66): a crash-torn write does not corrupt a prior good entry (temp+rename); a cache
file is created 0600.

## Integration map

- Feature 72 selects this backend and uses it as the fallback target.
- Feature 66 is the session file sibling; the atomic-write and permissions fixes land together.
- `cache_contract.json` proves the interface invariants for this backend.

## Breaking changes and migration

- Atomic write and 0600 are internal; no app breaks (a redeploy re-creates cache files, which are
  disposable).

## Implementation backlog

1. Resolve FC-74-01/FC-74-02 alongside Feature 66 FP-01/FP-02 (one atomic-write + 0600 change per file
   backend).
2. Run locally and on the root lab; the CONTRACT-MAP row stays proven.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the file cache backend: write each entry as `{key, value, expires_at}` JSON to a temp file
and rename it atomically with mode 0600, named for the hashed cache key under `TINA4_CACHE_DIR`. `get`
reads the envelope and returns `value` (a stored null is a hit; a past `expires_at` is a miss and
unlinks); `clear` unlinks every entry; `sweep` unlinks expired files and returns the count. Prove the
port with a cached-null hit, an expiry, a clear, a sweep count, a torn-write case, and a 0600 check.

## Audit closure checklist

- [x] Boundary and public surface complete (file per entry + envelope + expiry).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (torn write, permissions).
- [x] Wire/storage and provider contracts complete (envelope, hashed filename).
- [x] Existing-language contradictions recorded (FC-74-01/02, shared with Feature 66).
- [x] Owner ambiguities recorded (1 proposed; atomic-write + 0600, shared with the session file provider).
- [x] Proposed shared cases and mutation witnesses complete (proven + torn-write + 0600).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
