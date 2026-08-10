# Feature 012: Response types

## Identity and status

- Matrix identity: 12 - JSON, HTML, text, XML, file and redirect responses
- Current state: standalone 3.14 re-audit in progress
- Historical audit: 2026-08-01, previously bundled with Features 11 and 79
  plus the Feature 64 CLI
- Existing decision: ADR-0019
- Current shared executable fixture: none
- Required shared fixture: `plan/v3/fixtures/response_types_contract.json`

This file now owns Feature 12 only. Rate limiting lives in
`011-rate-limiting.md`, the routes CLI in `064-routes-cli.md`, and route groups
in `079-route-groups.md`.

The old audit fixed one serious status-preservation defect, but it did not
define exact JSON bytes, failure semantics, automatic type selection, bodyless
statuses, file resource behavior or a future-language implementation formula.
Those are being re-audited before 3.14.0.

## Boundary

Feature 12 owns:

- callable/automatic response type selection;
- explicit JSON, HTML, text and XML helpers;
- native object/model/query-result normalization for JSON;
- serialization failure behavior and exact media types/bytes;
- status preservation and body-forbidden response semantics;
- redirects and their Location field;
- file/attachment responses, MIME selection and resource bounds;
- the shared executable fixture and future-language formula.

It delegates the base mutable response/header/cookie object to Feature 5,
dispatch finalization and HEAD routing to Feature 6, middleware unwinding to
Feature 7, templates to Frond, streaming/SSE to its own feature, and
compression/ETag/range/cache behavior to their numbered features.

## Historical evidence retained

| Helper | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| `json` media type | `application/json` | `application/json` | `application/json; charset=utf-8` | `application/json` |
| `html` | UTF-8 lowercase | UTF-8 uppercase | UTF-8 lowercase | UTF-8 lowercase |
| `text` | UTF-8 lowercase | UTF-8 uppercase | UTF-8 lowercase | UTF-8 lowercase |
| `xml` | UTF-8 lowercase | UTF-8 uppercase | UTF-8 lowercase | UTF-8 lowercase |
| redirect default | 302 | 302 | 302 | 302 |
| explicit status survived before old fix | yes | no | no | yes |
| explicit status survives now | yes | yes | yes | yes |

The old audit measured that PHP and Ruby reset a status selected by
`status(N)` when `json`, `html`, `text` or `xml` was called. That could turn a
rate-limit rejection into HTTP 200. Both were changed to preserve the selected
status.

The same audit left these gaps open:

- Ruby alone added a charset parameter to JSON;
- PHP alone uppercased the UTF-8 charset token;
- PHP `json()` pretty-printed while its callable response emitted compact JSON;
- nested ORM/model normalization differed;
- unserializable values became strings, empty HTTP 200 bodies, `{}` or
  exceptions depending on language;
- `response.file()` had separate traversal work but no complete cross-language
  resource/wire contract;
- all tests copied language-local expectations instead of consuming one data
  fixture.

## Current re-audit evidence

Focused local suites are green at the start of this pass:

| Python | PHP | Ruby | Node |
| --- | --- | --- | --- |
| 38 passed | 67 tests / 126 assertions | 64 examples | 115 response assertions |

Those totals are characterization evidence only. Three of the four
auto-serialization suites substitute duck-typed model/result objects, exact
Unicode and invalid-number JSON are not shared cases, and bodyless status/file
behavior is not one fixture. Adversarial and real-socket lab work is still in
progress; this file must not be treated as a completed audit yet.

## Completion work in progress

The standalone audit will finish with:

- a standards-locked JSON normalization and failure contract;
- explicit decisions for callable strings and HTML detection;
- exact status/media-type/header/body bytes;
- 1xx/204/205/304 and HEAD suppression rules;
- redirect status and Location validation;
- bounded regular-file streaming and safe attachment names;
- real ORM/DatabaseResult integration cases;
- a shared `response_types_contract.json` fixture with four thin runners;
- a step-by-step formula that can implement Feature 12 in another language.
