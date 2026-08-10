# Feature 100: S3 realtime attachment storage

## Identity and status

- Matrix identity: 100 - S3 realtime attachment storage
- Audit state: decision-ready
- Audit note: measured 2026-08-10 as part of the realtime extractions (feature 098). S3Storage is the
  opt-in production backend behind the `StorageBackend` seam. Proven against a REAL MinIO in Python;
  UNVERIFIED (no real-object-store test) in PHP/Ruby/Node - the sharpest instance of feature 098 RT-04.
  No framework code changed.
- Dependencies: feature 098 (the realtime file plane), an S3-compatible object store, the S3 SDK
  (boto3 / aws-sdk), feature 099 (the LocalStorage fallback target)
- Dependants: production realtime deployments that store attachments in S3/MinIO
- Existing ADRs: none specific; follows the provider-is-an-env-var pattern (ADR-0024) and the
  graceful-fallback pattern shared with cache/session/storage
- Shared fixtures: covered by the proposed `realtime_contract.json` (feature 098); no separate fixture
- Catalog phase: Integration providers

## Why this feature exists

A production realtime deployment stores attachments in an S3-compatible object store, not on a single
server's disk. `S3Storage` is the opt-in `StorageBackend` that uploads blobs to S3/MinIO and serves them
via PRESIGNED URLs (so large blobs stream straight from the object store, not through the app). It is
opt-in - a missing SDK or incomplete config gracefully FALLS BACK to LocalStorage (099) rather than
crashing a boot.

## Boundary

This packet owns the S3 realization of the `StorageBackend` interface (feature 098): connecting to the
object store, `put`/`get`/`delete`/`exists`, the presigned `url()`, and the graceful fallback. The
interface + the file routes belong to 098; the local backend + the fallback target is 099.

## Existing implementation evidence

S3Storage implements the full `StorageBackend` surface and the presigned URL, opt-in, in all four:

| StorageBackend concern | S3Storage |
| --- | --- |
| selection | `TINA4_STORAGE_BACKEND=s3` + a bucket; a missing SDK/bucket FALLS BACK to LocalStorage with a `Log.warning` |
| put / get / delete / exists | full - against the S3-compatible store |
| url(key, ttl) | a PRESIGNED GET URL (expiring in `ttl`), so download 302-redirects to the object store |
| SDK | opt-in, lazily loaded (Python boto3; PHP `Aws\S3\S3Client`; Ruby `aws-sdk-s3`; Node `@aws-sdk/client-s3` + `s3-request-presigner`) |
| MinIO compat | path-style endpoint (PHP `use_path_style_endpoint`, Ruby `force_path_style`, endpoint via `TINA4_STORAGE_URL`) |
| verified against a real object store | Python (real MinIO) only - PHP/Ruby/Node UNTESTED (RT-04) |

The behaviour is at parity in source; the coverage is not - only Python drives a real MinIO round-trip
and a real presigned fetch. In PHP/Ruby/Node the whole backend (put/get/url/delete/exists) ships without a
real-object-store test.

## Public surface contract

Selected by `TINA4_STORAGE_BACKEND=s3` with a bucket configured and the SDK present. It exposes the
`StorageBackend` surface; the difference from LocalStorage (099) is `url()` - a presigned GET URL that
turns the 098 download route into a 302 redirect (the blob streams from S3, not through the app).

## Inputs and outputs

- Input: an opaque storage key, blob bytes, a mime type; the S3 config (`TINA4_STORAGE_URL`/`_KEY`/
  `_SECRET`/`_BUCKET`/`_REGION`).
- Output: the blob stored in S3 on `put`; a presigned GET URL on `url()`; the bytes on `get`. A missing
  SDK or incomplete config yields a LocalStorage instance (the fallback), not an error.

## Lifecycle and operation graph

1. SELECT: `select_storage` sees `TINA4_STORAGE_BACKEND=s3`, tries to construct `S3Storage`; the SDK is
   loaded lazily and the bucket is required.
2. FALLBACK: if the SDK is absent or the config incomplete, it logs a warning and returns a `LocalStorage`
   (099) - a real store, never a silent no-op.
3. PUT/GET: blobs go to the object store; `url()` returns a presigned GET URL.
4. DOWNLOAD (098): the download route calls `url()`; a presigned URL yields a 302 redirect (vs the local
   stream when `url()` is null).

## Configuration and precedence

- `TINA4_STORAGE_BACKEND=s3` selects it. `TINA4_STORAGE_URL` (endpoint, for MinIO/S3-compatible),
  `TINA4_STORAGE_KEY`/`_SECRET` (credentials), `TINA4_STORAGE_BUCKET` (required - empty raises, triggering
  the fallback), `TINA4_STORAGE_REGION` (default `us-east-1`). Explicit config wins.

## Failures, side effects and security

- GRACEFUL FALLBACK (the reliability core): a missing SDK, a missing bucket, or an unbuildable client
  logs a warning and degrades to LocalStorage (099) - a real persistent store, never a silent no-op. This
  is the same fail-soft posture as the cache/session backend selection. Uniform in all four in SOURCE.
- PRESIGNED URLS: `url()` returns a time-limited (`ttl`) presigned GET so a large blob streams from the
  object store and the app never proxies it; the presigned URL is the security boundary (it expires and
  is scoped to one key). The 098 download route still membership-gates BEFORE issuing the redirect.
- OPT-IN DEPENDENCY: the S3 SDK is a runtime dependency for this backend ONLY, lazily loaded. Python
  declares boto3 in its `s3`/`test` extra; Node does NOT declare `@aws-sdk/*` in `package.json` (it works
  only if the app installs it) - a packaging drift worth noting.
- The credentials/URL are the security surface; the transport uses the SDK's TLS.

## Wire and persistence contract

Blobs in an S3-compatible object store, keyed by the opaque storage key; the attachment metadata lives in
`tina4_rt_attachments` (098). Delivery is a presigned GET URL (302 redirect), the behavioural difference
from LocalStorage's null `url()` (099). The path-style endpoint makes it MinIO-compatible.

## Providers and substitutability

The opt-in production alternative to LocalStorage (099) behind the `StorageBackend` seam. Setting
`TINA4_STORAGE_BACKEND=s3` swaps from local to S3 with no call-site change (the 098 routes are
backend-agnostic); the fallback makes the swap safe even when the SDK/config is absent. LocalStorage is
the imitation reference; S3 adds the presigned-URL delivery.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| RT-04 (this backend) | S3Storage is UNVERIFIED against a real object store in PHP/Ruby/Node - the whole backend (put/get/url/delete/exists + the presigned URL) ships with no real MinIO test; only the no-SDK fallback is tested. Python has a real MinIO round-trip + presigned fetch (`test_realtime_files.py`). This is the sharpest instance of feature 098's coverage gap - a whole 099/100 provider unproven in three of four. | PHP/Ruby/Node add a real MinIO test exercising put/get/url (presigned fetch)/delete/exists, gated behind `TINA4_REQUIRE_SERVICES` (MinIO is already provisioned for the Python test). Prove the presigned URL actually fetches the blob. |
| RT-04b (Node packaging) | Node does not declare `@aws-sdk/client-s3`/`@aws-sdk/s3-request-presigner` in `packages/orm/package.json` (only mongodb/mysql2/pg/tedious are optional deps), so S3 works only if the app installs the SDK itself. Python declares boto3 in its `s3` extra. | Node declares the AWS SDK as an optional dependency (or documents that the app must install it), matching Python's opt-in-but-declared pattern. |

No open behavioural defects - the S3 backend and its fallback are correct in source across the four; the
gap is proof, not behaviour.

## Owner decisions

None behavioural. The cross-cutting items are RT-04 (verify against real MinIO) and RT-04b (Node
packaging), both tracked here and in 098. The fixture (RT-05) lives in 098.

## Proposed conformance fixture

Covered by `realtime_contract.json` (098): the S3 leg uploads a blob to a real MinIO, fetches it back via
the presigned `url()`, and asserts the download route 302-redirects; a second case removes the SDK/config
and asserts the fallback to LocalStorage with a warning (no silent no-op). Real MinIO only - no fake S3.

## Integration map

- Selected by `TINA4_STORAGE_BACKEND=s3`; used by the 098 file routes; falls back to LocalStorage (099);
  the presigned URL turns the 098 download into a 302 redirect.
- The AWS SDK is the one opt-in dependency (lazy); MinIO is provisioned for the Python test and must be
  for the others (RT-04).

## Breaking changes and migration

None. The S3 backend, the presigned delivery, and the graceful fallback are stable. Declaring the AWS SDK
as an optional dep in Node (RT-04b) is additive.

## Implementation backlog

1. RT-04: PHP/Ruby/Node add a real MinIO test (put/get/presigned-url/delete/exists) - the whole backend is
   currently unproven there.
2. RT-04b: Node declares the AWS SDK as an optional dependency.
3. Fold the S3 leg into `realtime_contract.json` against real MinIO (feature 098 RT-05).

## Porting capsule

Implement an S3 `StorageBackend`: select it on `TINA4_STORAGE_BACKEND=s3` with a bucket, lazily loading
the SDK and FALLING BACK to LocalStorage (with a logged warning) when the SDK or config is absent (never a
silent no-op); `put`/`get`/`delete`/`exists` against the S3-compatible store (path-style endpoint for
MinIO via `TINA4_STORAGE_URL`); and `url(key, ttl)` returning a time-limited PRESIGNED GET URL so the 098
download route 302-redirects and the app never proxies the blob. Declare the SDK as an opt-in dependency.
Prove it in `realtime_contract.json` against a real MinIO: a round-trip, a presigned fetch, and the
fallback when the SDK is absent.

## Audit closure checklist

- [x] Boundary and public surface complete (the S3 backend; interface + routes are 098; fallback is 099).
- [x] Lifecycle and every producer/consumer edge complete (select/fallback/put/get/presigned-url).
- [x] Configuration, failure, side-effect and security rules complete (graceful fallback, presigned URL, opt-in SDK).
- [x] Wire/storage and provider contracts complete (S3 blobs; presigned 302; MinIO path-style).
- [x] Existing-language contradictions recorded (RT-04 unverified in PHP/Ruby/Node; RT-04b Node packaging).
- [x] Owner ambiguities recorded (none behavioural; coverage + packaging tracked).
- [x] Proposed shared cases and mutation witnesses complete (the S3 leg of `realtime_contract.json`, real MinIO).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
