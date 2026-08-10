# Feature 044: File upload contract

## Identity and status

- Matrix identity: 44 - File upload contract
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (multipart parsing and the file
  descriptor in each request model). No framework code changed.
- Dependencies: Feature 29 request model (`files` lives on it), the multipart body parser, the
  request-size bound (`TINA4_MAX_UPLOAD_SIZE`)
- Dependants: any handler that accepts an upload; the messenger attachment path; AutoCrud file
  fields
- Existing ADRs: the request-model contract (Feature 29)
- Shared fixtures: `file_upload_contract.json` is required
- Catalog phase: Routing and middleware

## Why this feature exists

A form or an API client posts a file, and the handler receives it as one predictable object -
its filename, content type, size and bytes - the same shape in all four languages, with a size
bound and a filename that a handler cannot be tricked into writing outside its intended
directory.

## Boundary

This feature owns the multipart parse into the request's `files` map, the uploaded-file
descriptor shape, the size bound, and the filename-safety rule. It DELEGATES the `files`
attribute to Feature 29, the raw body to the request parser, and any persistence to the
application (through a safe save). It does not own AutoCrud's use of an upload, only the
descriptor it hands over.

## Existing implementation evidence

| Evidence | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| Files on the request | `files` map | `files` (normalised) | `files` | `files: UploadedFile \| UploadedFile[]` |
| Descriptor keys | (to confirm) | `filename`, `type`, `content` (base64), `size` | (to confirm) | `UploadedFile` (filename, type, size, data) |
| Bytes representation | (to confirm) | base64 STRING in memory | (to confirm) | Buffer |
| Size bound | (to confirm) | `TINA4_MAX_UPLOAD_SIZE` default 10 MB | (to confirm) | (to confirm) |
| Over-size | reject | reject (over content-length) | reject | reject |
| Multiple files per field | (to confirm) | array | (to confirm) | `UploadedFile[]` |
| Filename safety | (to confirm) | (client-provided in `filename`) | (to confirm) | (client-provided) |

Multipart parsing populates the request's `files` map with a per-file descriptor. PHP's
descriptor is `{filename, type, content (base64), size}` and it holds the bytes as a BASE64
STRING in memory; Node's `UploadedFile` holds a Buffer. So the BYTES REPRESENTATION diverges
(base64 string vs raw buffer), which matters for both the access pattern and memory (base64
inflates a 10 MB upload to ~13 MB in memory, with no stream-to-disk). PHP bounds the upload by
`TINA4_MAX_UPLOAD_SIZE` (default 10 MB), rejecting an over-size body; the same bound must be
confirmed in the other three. The `filename` is the client-provided name in every case, which
is the security surface.

## Public surface contract

A multipart request populates `files` with, per field, one uploaded-file descriptor or a list
of them. Each descriptor carries the client `filename`, the `content_type`, the `size`, and the
bytes. The upload is bounded by `TINA4_MAX_UPLOAD_SIZE`; an over-size body is rejected. A handler
reads the bytes through one representation and, if it saves the file, must NOT use the client
filename directly.

## Inputs and outputs

- Input: a `multipart/form-data` request body and the `TINA4_MAX_UPLOAD_SIZE` bound.
- Output: `files` mapping each file field to a descriptor (or a list): `filename` (client-
  provided, untrusted), `content_type`, `size`, and the bytes.
- Multiple files under one field name produce a list.
- An over-size upload produces a clear rejection (a 413-style error), not a truncated file.
- The bytes are one representation across the four (raw bytes), not base64 in one and a buffer
  in another.

## Lifecycle and operation graph

1. The request parser detects `multipart/form-data` and, before buffering the whole body, checks
   `Content-Length` against `TINA4_MAX_UPLOAD_SIZE`, rejecting an over-size upload.
2. It parses each part into a field value or a file descriptor.
3. Files are placed in `files`, keyed by field name, as a single descriptor or a list.
4. A handler reads `filename`/`content_type`/`size`/bytes; to persist, it derives a SAFE name
   (never the raw client filename) and writes to an intended directory.

## Configuration and precedence

- `TINA4_MAX_UPLOAD_SIZE` bounds the upload (PHP default 10 MB); the same variable and default
  apply in all four. It relates to but is distinct from the general request-body bound.
- There is no per-field configuration; the bound is global.

## Failures, side effects and security

- SECURITY (filename): the client `filename` is UNTRUSTED. A handler must never write to a path
  built from it directly (path traversal, `../`, null bytes, absolute paths); the framework
  provides the raw name for display but a save uses a sanitized or generated name confined to a
  target directory (the same confinement rule as Feature 30/41).
- SIZE: an over-size upload is rejected BEFORE the whole body is buffered, so a large upload
  cannot exhaust memory; the base64-in-memory representation (PHP) makes the bound especially
  important and argues for a raw-bytes-or-stream representation.
- A malformed multipart body fails cleanly (a 400), not a partial or misattributed file.
- The `content_type` is client-provided and advisory; a handler validates it against the actual
  bytes if it matters (an image handler checks magic bytes, not just the header).

## Wire and persistence contract

The wire input is the multipart body; the contract is the descriptor shape (`filename`,
`content_type`, `size`, bytes) and the size bound. There is no framework persistence; a save is
the application's, through a safe name. The bytes representation is one type across the four.

## Providers and substitutability

File upload is transport-level and engine-agnostic. A future runtime parses the same multipart
body into the same descriptor shape with the same bytes representation, the same size bound, and
the same untrusted-filename rule.

## Contradictions and defects

| ID | Finding | Required outcome |
| --- | --- | --- |
| UP-01 | The bytes representation diverges (PHP base64 string, Node Buffer); a handler reads different types. | Pin ONE representation (raw bytes) across the four; PHP stops base64-encoding the content into the descriptor. |
| UP-02 | The descriptor key set (`filename`/`content_type`/`size`/bytes) is confirmed only in PHP/Node. | Pin one key set and gate it in all four. |
| UP-03 | The size bound (`TINA4_MAX_UPLOAD_SIZE` default 10 MB) is confirmed only in PHP. | Pin one variable and default; gate an over-size rejection BEFORE buffering, in all four. |
| UP-04 | Filename safety is not gated; a save built from the client filename is a path-traversal vulnerability. | Gate that a save uses a sanitized/confined name and rejects `../`/null/absolute, in all four. |
| UP-05 | Multiple files per field (a list) is confirmed only in PHP/Node. | Gate the single-vs-list shape in all four. |
| UP-06 | No shared fixture exists. | Add `file_upload_contract.json`. |

## Owner decisions

Proposed for owner ratification:

1. One uploaded-file descriptor across the four: `filename` (client, untrusted), `content_type`,
   `size`, and the bytes as RAW BYTES (not a base64 string); PHP stops base64-encoding the
   content.
2. `TINA4_MAX_UPLOAD_SIZE` (default 10 MB) bounds the upload in all four; an over-size body is
   rejected BEFORE the whole body is buffered.
3. The client `filename` is untrusted: the framework exposes it for display, but a save uses a
   sanitized or generated name confined to a target directory; a raw-filename write is rejected.
4. Multiple files under one field produce a list; a single file a single descriptor.
5. The `content_type` is advisory; a handler that cares validates the actual bytes.

## Proposed conformance fixture

Add `file_upload_contract.json` with stable ids for: a single-file upload producing a descriptor
with `filename`/`content_type`/`size`/raw-bytes; two files under one field producing a list; an
over-size upload rejected (413-style) before buffering; a malicious filename (`../../evil`, a
null byte, an absolute path) NOT usable to write outside a target directory; a malformed
multipart body failing 400; and the bytes round-tripping unchanged. Every case posts a real
multipart body to a real handler; no mock can claim conformance (the filename-safety and size
guards must be proven on real parsing).

## Integration map

- Feature 29 hosts `files`; the request parser produces the descriptors; the messenger
  attachment path and AutoCrud file handling consume them.
- The filename-safety rule shares the confinement of Feature 30 `file()` and Feature 41 static.
- Central fixtures, four runners, the CI matrix and the upload docs update together.

## Breaking changes and migration

- PHP moving off base64 content to raw bytes changes what a handler reads from a PHP upload;
  `Breaking:` entry with the migration (read bytes, not a base64 string).
- Pinning the descriptor key set and the size default aligns the other three; additive where a
  key was already present.
- The filename-safety rule is a security hardening.

## Implementation backlog

1. Add `file_upload_contract.json` and wire four runners against real multipart posts.
2. Pin the descriptor shape and the raw-bytes representation (UP-01, UP-02) in all four.
3. Pin `TINA4_MAX_UPLOAD_SIZE` and gate the before-buffering over-size rejection (UP-03).
4. Gate filename safety (UP-04) and the single-vs-list shape (UP-05).
5. Run locally and on the root lab, then flip owed->proven in CONTRACT-MAP.

No framework implementation belongs in the audit commit.

## Porting capsule

Parse a `multipart/form-data` body into `files`, keyed by field name, each entry a descriptor
(`filename` client-untrusted, `content_type`, `size`, raw bytes) or a list for multiple files.
Check `Content-Length` against `TINA4_MAX_UPLOAD_SIZE` (10 MB default) and reject an over-size
body BEFORE buffering. Never write a file to a path built from the client filename; expose it for
display but save under a sanitized/confined name. Prove the port with a single upload, a
multi-file field, an over-size rejection, and a malicious-filename save that is confined.

## Audit closure checklist

- [x] Boundary and public surface complete.
- [x] Lifecycle and every producer/consumer edge complete.
- [x] Configuration, failure, side-effect and security rules complete.
- [x] Wire/storage and provider contracts complete.
- [x] Existing-language contradictions recorded (UP-01..06).
- [x] Owner ambiguities recorded (5 proposed; the filename-safety and bytes-representation are key).
- [x] Proposed shared cases and mutation witnesses complete.
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
