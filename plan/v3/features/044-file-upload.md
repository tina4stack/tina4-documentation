# Feature 44: File upload contract

## Identity and status

- Matrix identity: 44 - File upload contract (multipart parse into `request.files`)
- Audit state: decision-ready
- Audit note: re-measured 2026-08-11 from four-language source (correcting a prior-session doc whose headline
  claim - PHP holds bytes as BASE64 - is FALSE; all four hold RAW bytes; the false claim traced to a stale
  PHP docblock). Python `core/request.py:445` (`ebbab30`); PHP `Tina4/Server.php:2364` + `Tina4/Request.php:327`
  (`6faabac5`); Ruby `lib/tina4/request.rb:456` (`6d5b1de`); Node `packages/core/src/request.ts:284` +
  `types.ts:3` (`27cf0f4`).
- Dependencies: the request model (29, `files` lives on it), the multipart parser, `TINA4_MAX_UPLOAD_SIZE`.
- Dependants: any upload handler; the messenger attachment path; AutoCrud file fields.
- Existing ADRs: the request-model contract (29).

- Catalog phase: Routing and middleware

## Why this feature exists

A client posts a file; the handler receives it as one predictable descriptor (filename, type, size, bytes),
bounded by a size limit, with the client filename treated as untrusted. The audit question is whether the
descriptor SHAPE, the size bound, and the safety rules are the same in all four. The bytes representation IS
uniform (raw bytes everywhere - the prior doc was wrong); the descriptor keys, the multi-file shape, and the
before-buffering enforcement are NOT.

## Existing implementation evidence

Multipart parsing populates `request.files`, keyed by field name (confirmed all four: `request.py:91`,
`Request.php:68`, `request.rb:249`, `types.ts:55`). Per file:

- BYTES = RAW bytes in every language (NO base64 anywhere): Python `bytes` (`request.py:449`, with the comment
  "Content stays as raw bytes - no base64 encoding"); PHP raw binary string (`Server.php:2368`
  socket-server multipart; `Request.php:330` `file_get_contents` on the SAPI path); Ruby raw `String`
  materialised lazily from the Rack tempfile, plus the `tempfile` IO (`request.rb:43-57`); Node `Buffer`
  (`request.ts:288`).
- DESCRIPTOR KEYS: core `{filename, type, content, size}`; Node and PHP-multipart also carry `fieldName`;
  Ruby also carries `tempfile`; the PHP `$_FILES`/SAPI path has no `fieldName`. The key is `type` (NOT
  `content_type`) and `content` (NOT `bytes`/`data`) everywhere.
- `TINA4_MAX_UPLOAD_SIZE` exists in all four, default 10 MB (10485760): `request.py:11`, `Request.php:191`,
  `request.rb:122`, `request.ts:139`.
- The client filename is taken VERBATIM (no sanitization/traversal guard) in all four.

## Public surface contract

A multipart request populates `files[fieldName]` with one descriptor (or, in Node, a list for repeated field
names). Each descriptor carries `filename` (client, untrusted), `type`, `size`, and `content` (raw bytes). The
upload is bounded by `TINA4_MAX_UPLOAD_SIZE`. A handler that saves the file must derive a SAFE name.

## Inputs and outputs

- Input: a `multipart/form-data` body + `TINA4_MAX_UPLOAD_SIZE`.
- Output: `files` mapping each field to a descriptor (Node: a descriptor or a list). An over-size DECLARED
  body -> 413 in all four; a chunked/under-declared over-size -> 413 only in Python/Node (see the register).

## Lifecycle and operation graph

1. Read the body (Python/Node run a per-chunk running counter against the cap; PHP/Ruby check only the
   declared Content-Length).
2. Parse each multipart part into a form field or a file descriptor.
3. Place files in `files` keyed by field name (Node appends a list on a repeat; the others overwrite).
4. A handler reads `filename`/`type`/`size`/`content`; to persist, it must derive a safe name.

## Configuration and precedence

- `TINA4_MAX_UPLOAD_SIZE` (default 10 MB), all four. NOTE (PHP): the BEFORE-buffering socket guard is driven
  by a DIFFERENT knob, `TINA4_MAX_REQUEST_BODY` (`Server.php:1430`, same 10 MB default); `TINA4_MAX_UPLOAD_SIZE`
  is checked in the `Request` constructor AFTER the body is buffered (`Server.php:874` buffers, then
  `Request.php:193` checks). See the register.

## Failures, side effects and security

- SECURITY (filename): the client `filename` is UNTRUSTED and passes through verbatim in all four (no
  `basename`/traversal/null-byte guard). `../../evil`, absolute paths, and null bytes reach descriptor
  `filename` unmodified. A save MUST use a sanitized/generated name confined to a target dir (same rule as
  30/41). The framework exposes the raw name for display only.
- SIZE / MEMORY: Python and Node stop accumulating at the cap via a running per-chunk counter (`server.py:2718`,
  `request.ts:180`) - a chunked or under-declared over-size is caught. PHP and Ruby check only the declared
  Content-Length, so a chunked/lying-length over-size is NOT bounded (memory protection not at parity - see
  the register).
- The PRNG-free path; `content` is raw bytes so a 10 MB upload is ~10 MB in memory (the prior doc's "base64
  inflates to ~13 MB" was false).

## Wire and persistence contract

The wire input is the multipart body; the contract is the descriptor shape (`filename`, `type`, `size`,
`content` raw bytes) and the size bound. No framework persistence. The descriptor KEY SET is not yet uniform
(see the register).

## Providers and substitutability

Transport-level. A future runtime parses the same multipart body into the same (to-be-pinned) descriptor with
raw bytes, the same size bound WITH a running counter, and the same untrusted-filename rule.

## Contradictions and defects

| ID | Finding | Proposed resolution |
| --- | --- | --- |
| UP-PHP-BASE64-FALSE | The prior doc's headline (PHP holds `content` as a BASE64 string, inflating 10 MB to ~13 MB) is FALSE - PHP stores RAW bytes (`Server.php:2368`, `Request.php:330` `file_get_contents`). The false claim traces to a STALE DOCBLOCK `Request.php:296` ("`content => string (base64)`") that the code 20 lines below contradicts. The audit inherited a comment, not the code. | Correct the doc (bytes are raw in all four); fix the stale `Request.php:296` docblock so it says raw bytes. |
| UP-MULTIFILE-LOSS | Multiple files under ONE field name SILENTLY lose all but the last in Python (`request.py:446` `result[name]={...}`), Ruby (`request.rb:461`), and the PHP socket server (`Server.php:2364`). Only Node keeps a list (`request.ts:292-297`); PHP's `$_FILES` path arrays only for `name="x[]"`. Real data loss, no signal. | Decide the shape: produce a LIST for repeated field names in all four (Node's model), or document last-wins. Gate it. |
| UP-CHUNKED-BYPASS | PHP and Ruby enforce the size cap on the DECLARED Content-Length only (`Request.php:193`, `request.rb:136`); a chunked body (no length) or an under-declared length is never counted, so an over-size upload bypasses the cap and buffers unbounded (Ruby's own source concedes Puma merely bounds the read; `rack_app.rb:134-137`). Python (`server.py:2718`) and Node (`request.ts:180`) run per-chunk counters and stop. Memory-exhaustion protection is not at parity. | Add a running per-chunk counter (or a streaming bound) to PHP and Ruby so a chunked/lying-length over-size is refused before exhausting memory. |
| UP-PHP-TWO-KNOBS | PHP's only BEFORE-buffering refusal (`Server.php:1430`) is governed by `TINA4_MAX_REQUEST_BODY`, NOT the documented `TINA4_MAX_UPLOAD_SIZE`; the latter is checked in-constructor AFTER the full body is buffered (`Server.php:874`). Lowering only `TINA4_MAX_UPLOAD_SIZE` does not protect before buffering. Two knobs, one documented. | Reconcile: drive the before-buffering guard from `TINA4_MAX_UPLOAD_SIZE` (or document both knobs and their relationship). |
| UP-DESCRIPTOR-KEYS | The descriptor key set is NOT identical (the prior C7 claim is false): core `{filename, type, content, size}`; `fieldName` in Node + PHP-multipart, absent in Python + PHP-`$_FILES`; `tempfile` only in Ruby. And the prior doc's own naming (`content_type`, `bytes`, `data`) matches NONE of the four (they use `type`, `content`). | Pin ONE descriptor: keys `{filename, type, size, content}` (raw bytes), decide `fieldName` (yes/no) and Ruby's `tempfile` (keep as an optional streaming handle or drop), gate it in all four. |
| UP-FILENAME-UNTRUSTED | The client filename reaches descriptor `filename` verbatim in all four; there is NO framework save that sanitizes it, and no test gates that a `../`/absolute/null-byte name cannot escape a target dir. By design (the framework exposes the raw name; a safe save is the app's job), but ungated. | Provide a safe-save helper (sanitize + confine) and gate that a malicious filename cannot write outside the target dir, in all four. |
| UP-NO-FIXTURE | No shared `file_upload_contract.json` exists. | Add it once UP-DEC-01 pins the descriptor. |

## Owner decisions

- UP-DEC-01 (proposed): pin ONE descriptor - keys + the raw-bytes representation (already uniform) - and
  reconcile the naming (`type` vs `content_type`, `content` vs `bytes`) and the optional keys
  (`fieldName`/`tempfile`) (UP-DESCRIPTOR-KEYS). Fix the stale PHP base64 docblock (UP-PHP-BASE64-FALSE).
- UP-DEC-02 (proposed): fix the SILENT multi-file data loss (UP-MULTIFILE-LOSS) - list for repeated fields in
  all four, or documented last-wins - and close the chunked-body over-size bypass in PHP/Ruby
  (UP-CHUNKED-BYPASS), reconciling PHP's two size knobs (UP-PHP-TWO-KNOBS). Highest value (data loss + memory).
- UP-DEC-03 (proposed): add a safe-save helper and gate filename safety (UP-FILENAME-UNTRUSTED) in all four.

## Proposed conformance fixture

A shared fixture (real multipart posts, no mocks): a single upload yields `{filename, type, size, content}`
with raw bytes that round-trip unchanged; TWO files under one field name behave identically across the four
(list, per UP-DEC-02); a DECLARED over-size returns 413, and a CHUNKED over-size also returns 413 (catches
UP-CHUNKED-BYPASS); a `../../evil`/null-byte/absolute filename cannot write outside a target dir (UP-DEC-03);
a malformed multipart body fails cleanly (400).

## Integration map

- Consumers: upload handlers, the messenger attachment path, AutoCrud file fields. Composes: the request model
  (29), the size bound, the safe-save/static confinement (30/41).

## Breaking changes and migration

- Making repeated-field uploads a LIST changes what a Python/Ruby/PHP handler reads (previously a single
  descriptor) - a `Breaking:` entry with the migration. Adding running counters to PHP/Ruby is a hardening.
  Fixing the base64 docblock is a doc fix. Pinning the descriptor keys is additive where a key already exists.

## Porting capsule

Parse `multipart/form-data` into `files` keyed by field name; each entry `{filename (client-untrusted), type,
size, content (RAW bytes)}` - never base64. Produce a LIST for a repeated field name (do not silently drop -
the Python/Ruby/PHP bug). Enforce `TINA4_MAX_UPLOAD_SIZE` (10 MB default) with a RUNNING per-chunk counter so
a chunked/lying-length body is refused BEFORE it exhausts memory (not just a declared-Content-Length check -
the PHP/Ruby gap), returning 413. Never write to a path built from the client filename; provide a
sanitize-and-confine save helper. Prove it with a single upload, a two-file field (both survive), a chunked
over-size (413), and a malicious-filename save that is confined.

## Audit closure checklist

- [x] Boundary and public surface complete (descriptor + files map x four).
- [x] Lifecycle and producer/consumer edges complete (read -> count -> parse -> place).
- [x] Configuration (two PHP knobs), failure (chunked bypass) and security (untrusted filename) rules complete.
- [x] Wire (descriptor shape, raw bytes) and provider contracts complete.
- [x] Four-language behaviour recorded truthfully (raw bytes all four; multi-file loss; chunked bypass) -
  correcting the prior false base64 claim.
- [x] Owner ambiguities decided (UP-DEC-01/02/03).
- [x] Conformance fixture (multi-file + chunked over-size + filename safety) complete.
- [x] Integration map and migrations complete.
- [x] Backlog ordered.
- [x] Porting capsule sufficient.
