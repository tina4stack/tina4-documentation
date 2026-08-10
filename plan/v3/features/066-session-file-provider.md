# Feature 066: File session provider

## Identity and status

- Matrix identity: 66 - File session provider
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the file backend, inline in the session
  module for Python/PHP/Node and `session_handlers/file_handler.rb` in Ruby), at Python `386cd6d`,
  PHP `743b7469`, Ruby `c61250c8`, Node `26be920`. No framework code changed.
- Dependencies: Feature 65 (the lifecycle that calls `read`/`write`/`destroy`/`gc`), the filesystem
- Dependants: the default session deployment (file is the default backend)
- Existing ADRs: ADR-0021 (no-constructor-IO, loud-then-degrade), ADR-0027 (`ttl<=0` = default)
- Shared fixtures: `session_contract.json` (ADR-0024) already PROVES the shared invariants for this
  backend: ttl honoured, no-constructor-IO, loud-then-degrade, zero-dep. This packet audits the
  file-specific contract.
- Catalog phase: Sessions (providers)

## Why this feature exists

The default session store needs no service: it writes each session to a file on disk. It must name
the file safely (never from the raw id), store the data and its expiry, expire on read, and garbage-
collect - the same way in all four so a file written by one framework reads in another.

## Boundary

This feature owns the file backend's `read`/`write`/`destroy`/`gc`: the on-disk filename derivation,
the stored record shape, the expiry check, and the sweep. It DELEGATES id validation, adoption and
the cookie to Feature 65. It is one provider behind the Feature 65 provider interface.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Filename | `<sha256(id)>.json` | same | `sess_<sha256(id)>.json` | `<sha256(id)>.json` |
| Storage dir (`TINA4_SESSION_PATH`) | `data/sessions` | same | same | same |
| Stored shape | `{_data, _expires}` | flat data + `_meta.expires_at` | `{_data, _expires}` | `{_data, _expires}` |
| Deadline type | float epoch | int seconds | float epoch | int seconds |
| Write atomicity | direct write | direct write + `LOCK_EX` | direct write | direct write |
| fsync | no | no | no | no |
| File permissions | umask default | umask default (dir 0755) | umask default | umask default |
| Read error vs miss | I/O error -> miss | I/O error -> miss | I/O error PROPAGATES (outage) | I/O error -> miss |
| GC of a corrupt file | unlink | unlink | SKIP (left on disk) | unlink |
| `ttl<=0` -> default | in handler | in handler | in handler | in Session (handler stores 0) |

The SHA-256 filename (ADR-0021) closes the historical `../` traversal in all four. The divergences
are the stored shape (PHP), the read-error policy (Ruby), the corrupt-file GC (Ruby), and two shared
gaps: no atomic write and no restrictive file permissions anywhere.

## Public surface contract

`read(id) -> data | empty` (the stored data, or empty on a miss/expired entry, which is unlinked);
`write(id, data, ttl=0)` (store `{_data, _expires}` under the SHA-256 filename, `ttl<=0` resolving to
`TINA4_SESSION_TTL`); `destroy(id)` (unlink the file); `gc(max_lifetime)` (sweep expired files). The
observable contract: a session written under an id is readable under the same id until its deadline,
and the on-disk name is a hash, never the id.

## Configuration and precedence

- `TINA4_SESSION_PATH` (default `data/sessions`) is the storage directory.
- `TINA4_SESSION_TTL` (default 3600) is the write-time default deadline (ADR-0027).
- The stored deadline is absolute and baked at write time; a read never consults the handler's TTL,
  so a reader configured differently cannot misjudge another writer's record.

## Failures, side effects and security

- TRAVERSAL is closed: the filename is `sha256(id)`, and PHP/Node additionally refuse a malformed id
  before deriving the path. Python/Ruby hash whatever is passed (safe, but the id is not re-validated
  at the handler; Feature 65 validates at `start()`).
- CRASH-TORN WRITE (FP-01): no framework does a temp-file + atomic rename or fsync, so a crash mid-
  write can leave a truncated/corrupt session file in all four. PHP's `LOCK_EX` guards concurrent
  writers, not a torn write.
- WORLD-READABLE CREDENTIAL (FP-02): the session file is a bearer credential, but none of the four set
  restrictive (0600) permissions - it is written at the default umask (typically 0644, world-readable)
  in all four. Any local user can read another user's session.
- READ-ERROR-AS-OUTAGE (FP-03): Ruby propagates a real filesystem read error (only `JSON::ParserError`
  is rescued), so an unreadable-but-present file registers as a backend OUTAGE (preserves the id, per
  ADR-0021); Python/PHP/Node collapse an I/O error into a healthy miss (mint a fresh id). The two are
  observably different on a permissions/disk error.
- CORRUPT-FILE GC (FP-04): Python/PHP/Node unlink an unparseable file during `gc()`; Ruby skips it,
  leaving corrupt files to accumulate.

## Wire and persistence contract

The stored record is JSON. Python/Ruby/Node use `{_data: <data>, _expires: <deadline|0>}`; PHP stores
the user data flat with a `_meta` object carrying `created_at`/`last_accessed`/`expires_at`. A
deadline of 0 means never-expires; a present past deadline means expired (unlink -> miss). The shape
divergence (FP-05) means a PHP file does not round-trip through a Python reader and vice versa,
breaking the "written by one framework reads in another" goal for the file backend.

## Providers and substitutability

The file backend is one provider behind Feature 65's `read`/`write`/`destroy`/`gc` interface; any
backend (Redis, database) substitutes it by env var (ADR-0024). The file backend is the zero-service
default and the zero-dependency fallback the other backends' contract references.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| FP-01 | No atomic write (temp+rename) or fsync in any framework; a crash mid-write corrupts the session file. | Write to a temp file and rename atomically in all four; decide whether to fsync. |
| FP-02 | The session file (a bearer credential) is world-readable (umask default); no framework sets 0600. | Create session files 0600 in all four. Security. |
| FP-03 | Ruby treats a filesystem read error as an outage (preserves id); Python/PHP/Node treat it as a miss. | Pin one policy (recommend outage-preserves-id, matching ADR-0021's store-outage rule) in all four. |
| FP-04 | Ruby's `gc()` skips corrupt files; Python/PHP/Node unlink them. | Unlink corrupt files during gc in all four. |
| FP-05 | The stored record shape diverges: PHP uses `_meta.expires_at` + flat data; the other three use `{_data, _expires}`. A file is not cross-framework-readable. | Pin ONE stored shape (recommend `{_data, _expires}`, the 3-majority) so a file round-trips across frameworks. |
| FP-06 | Ruby names files `sess_<sha256>` and globs `sess_*`; the other three use `<sha256>.json`. | Pin one naming so a shared directory is consistent (cosmetic unless a dir is shared). |

## Owner decisions

Proposed for owner ratification:

1. ATOMIC WRITE + 0600 PERMISSIONS (FP-01, FP-02) in all four - the two security/durability gaps.
   Recommend temp-file + rename and mode 0600 everywhere.
2. STORED SHAPE (FP-05): pin `{_data, _expires}` (the 3-majority; PHP converges) so a session file is
   cross-framework-readable, honouring the file backend's own portability promise.
3. READ-ERROR POLICY (FP-03): a filesystem read error is an OUTAGE (preserve the id), matching
   ADR-0021's store-outage rule; Python/PHP/Node converge onto Ruby here.
4. GC unlinks corrupt files (FP-04) and the filename scheme is pinned (FP-06) in all four.

## Proposed conformance fixture

Extend `session_contract.json` (or the Feature 65 lifecycle fixture) with file-backend cases driving
four runners against a real temp directory (no doubles): a session written and read back under the
SHA-256 name; a `../`-laden id never escaping the directory; an expired entry unlinked on read; a
crash-torn write not corrupting a prior good file (temp+rename); a file created 0600; a corrupt file
unlinked by gc; a read error treated as the ratified outage; and a file written by one framework's
shape read by another (cross-shape).

## Integration map

- Feature 65 calls this backend via `read`/`write`/`destroy`/`gc`; the cookie and adoption are 65's.
- `session_contract.json` already proves ttl-honoured, no-constructor-IO, loud-then-degrade, zero-dep
  for this backend; the file-specific cases above are added there.
- The session docs describe the file layout, the 0600 permissions, and the storage path.

## Breaking changes and migration

- 0600 permissions and atomic write are internal; no session breaks (a redeploy re-creates files).
- Pinning the stored shape changes PHP's on-disk format: existing PHP session files (with `_meta`)
  miss after the change and users log in again once. `Breaking:` for PHP, and a portability fix.

## Implementation backlog

1. Add the file-backend cases to the session fixture and wire four runners against a real temp dir.
2. Atomic write + 0600 (FP-01, FP-02) in all four; pin the stored shape (FP-05).
3. Pin the read-error policy (FP-03), corrupt-file gc (FP-04) and naming (FP-06).
4. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Implement the file backend: derive the filename as `sha256(id)` (refuse a malformed id), write the
record as `{_data, _expires}` to a temp file and rename it atomically with mode 0600, where `_expires`
is an absolute deadline from `ttl` (or `TINA4_SESSION_TTL` when `ttl<=0`), 0 meaning never. On read,
return the data unless the deadline has passed (then unlink and miss); treat a real read ERROR as an
outage (preserve the id), not a miss. `gc()` sweeps expired AND corrupt files. Prove the port with a
write/read round-trip, a traversal attempt, an expiry, an atomic-write-under-crash case, a 0600 check,
and a cross-framework shape read.

## Audit closure checklist

- [x] Boundary and public surface complete (read/write/destroy/gc + filename + stored shape).
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete (traversal, torn write, perms).
- [x] Wire/storage and provider contracts complete (stored shape, deadline, provider interface).
- [x] Existing-language contradictions recorded (FP-01..06).
- [x] Owner ambiguities recorded (4 proposed; atomic-write+0600 and the stored shape are the key calls).
- [x] Proposed shared cases and mutation witnesses complete (real temp dir, no doubles).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
