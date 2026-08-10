# Feature 088: Email and messenger

## Identity and status

- Matrix identity: 88 - Email and messenger
- Audit state: decision-ready
- Audit note: this feature is ALREADY PROVEN. `messenger_contract.json` (14 invariants, 14 proven, 0
  owed) drives four real runners against a REAL GreenMail SMTP/IMAP server (no mocks). This audit
  re-verifies the contract holds, records the resolved history, and catches two stale-bookkeeping
  drifts (MSG-01, MSG-02) - both objective corrections to already-Accepted decisions, applied in this
  commit. Measured 2026-08-10 against the shipped source and the proven fixture; source unchanged.
- Dependencies: the dotenv/env layer (`TINA4_MAIL_*` config), the debug layer (capture gate), the
  seeder (DevMailbox `seed`), the request.files bytes convention (attachment `content`)
- Dependants: any app sending transactional email or reading an IMAP mailbox; the dev mailbox at `/__dev`
- Existing ADRs: ADR-0004 (best implementation prevails; the send/read/inbox SHAPES), ADR-0008/G5
  (idiomatic casing: `body_text`/`bodyText`), ADR-0041 (an explicit argument always beats the
  environment), ADR-0042 (the messenger uid is the IMAP UID, never a sequence number). ALL four
  Accepted.
- Shared fixtures: `messenger_contract.json` - 14 invariants, ALL PROVEN, real GreenMail. One of the
  few reference-quality-PROVEN features in the catalog (with cache and session).
- Catalog phase: Integrations

## Why this feature exists

An application needs to send transactional email and read a mailbox without a heavy dependency. Tina4
ships a hand-rolled, ZERO-DEPENDENCY messenger in every language: an SMTP sender (with templates and
attachments), an IMAP reader (inbox, read, search, unread, folders, mark, delete), and a dev-capture
mailbox that intercepts mail when no SMTP host is configured. The whole subsystem speaks ONE shape
across the four languages - the same method set, the same result keys, the same failure contract -
proven against a live GreenMail server.

## Boundary

This feature owns the MESSENGER: the SMTP send path (`send`/`send_template`/`add_header`), the IMAP
read path (`inbox`/`read`/`search`/`unread`/`folders`/`mark_read`/`mark_unread`/`delete`), the
connection probes (`test_connection`/`test_imap_connection`), the DevMailbox capture surface
(`capture`/`inbox`/`read`/`unread_count`/`delete`/`clear`/`seed`/`count`), and the `create_messenger`
factory that gates capture vs send. SMTP and IMAP are the framework's own zero-dep protocol clients,
not a provider seam.

## Existing implementation evidence

The 14 proven invariants ARE the contract (all PROVEN in all four against real GreenMail):

| Invariant | Rule (summary) | ADR |
| --- | --- | --- |
| msg-uid-is-a-real-uid | `uid` is the IMAP UID, never a sequence number; every fetch/store uses the UID command form | 0042 |
| msg-uid-is-a-string | `uid` is a string on every method that returns or accepts one | 0004 |
| msg-inbox-is-newest-first | `inbox()`/`search()` return newest-first; page[0] is newest | 0004 |
| msg-folder-is-first-and-positional | `inbox(folder, limit, offset)` + `read(uid, folder)` callable positionally; kwargs added never substituted | 0004 |
| msg-missing-uid-is-null-not-empty | a fetch for a non-existent UID returns null, never raises | 0004 |
| msg-read-methods-fail-loud | read methods RAISE `MessengerConnectionError` on connect/auth/protocol failure; empty means empty; `send()` never raises | 0004 |
| msg-inbox-item-shape | inbox item = uid, subject, from, to, date, snippet, seen; from/to strings; date ISO-8601 | 0004 |
| msg-read-item-shape | `read()` = EXACTLY 10 keys (uid, subject, from, to, cc, date, body_text, body_html, attachments, headers); Message-ID in headers; attachments carry raw decoded bytes | 0004, 0008 |
| msg-snippet-is-decoded-text | `snippet` is decoded, transfer-decoded, tag-stripped text, or absent; never raw bytes | 0004 |
| msg-send-result-shape | `send()` returns {success, message, id} on BOTH delivery and capture; id = real Message-ID on success, null on failure; no path-specific extras | 0004 |
| msg-every-method-exists-everywhere | every public method exists in all four under the idiomatic spelling of ONE concept | 0004 |
| msg-env-vars-are-honoured-everywhere | a documented/allow-listed env var is read AND acted on by every framework | 0041 |
| msg-explicit-beats-env | every env-read configurable is constructor-settable, and the constructor wins | 0041 |
| msg-capture-gate | capture when no SMTP host; `TINA4_DEBUG` does NOT suppress sending; `TINA4_MAIL_CAPTURE=true` forces capture; the factory returns ONE concrete type, interception is a branch | 0004 |

This is a subsystem that four independently-written suites once ALL passed while two were wrong (the
uid-as-sequence-number case survived every suite because each framework read back by its own reported
id). The shared fixture against real GreenMail is what closed it.

## Public surface contract

- Send (`Messenger`): `send(to, subject, body, html=False, text=None, cc=None, bcc=None, ...)`,
  `send_template(to, subject, template, data, ...)`, `add_header(name, value)`. Returns {success,
  message, id} (msg-send-result-shape).
- Read (IMAP): `inbox(folder="INBOX", limit=20, offset=0)`, `unread(folder="INBOX")`, `read(uid,
  folder="INBOX")`, `search(folder, subject, from, ...)`, `mark_read(uid, folder)`, `mark_unread(uid,
  folder)`, `delete(uid, folder)`, `folders()`. Idiomatic casing per ADR-0008/G5 (`mark_read` vs
  `markRead`).
- Probes: `test_connection()`, `test_imap_connection()`.
- DevMailbox (capture): `capture(to, subject, body, ...)`, `inbox(limit, offset)`, `read(msg_id)`,
  `unread_count()`, `delete(msg_id)`, `clear(folder)`, `seed(count, seed)`, `count(folder)`.
- Factory: `create_messenger(**kwargs)` returns ONE concrete type; the capture-vs-send decision is a
  BRANCH inside it (msg-capture-gate), never a method swap on the instance.

## Inputs and outputs

- `send`: recipients (string or list), subject, body, optional HTML flag + plain-text alternative, cc/
  bcc (a bare string normalises to a list). Output: {success, message, id} on both send and capture.
- `read`: a UID string + folder. Output: exactly 10 canonical keys; `attachments` is a list of
  {filename, content_type, size, content} where `content` is the RAW DECODED BYTES of the part (the
  request.files convention) and `size` is that byte length - downloadable in every framework.
- `inbox`/`search`: folder + paging. Output: a newest-first page of items {uid, subject, from, to,
  date (ISO-8601), snippet (decoded text), seen}.

## Lifecycle and operation graph

1. FACTORY: `create_messenger()` reads the config; if no SMTP host is set (or `TINA4_MAIL_CAPTURE=true`)
   it wires the CAPTURE branch, else the SEND branch - ONE concrete type either way (msg-capture-gate).
2. SEND: build the MIME message (headers, HTML+text alternatives, attachments), connect SMTP, deliver;
   return {success, message, id} with the real Message-ID. `send()` never raises - a failure is a
   result with null values.
3. READ: connect IMAP, address every fetch/store by the UID command form (msg-uid-is-a-real-uid,
   ADR-0042); return the canonical shapes; a read-path connect/auth/protocol failure RAISES
   `MessengerConnectionError` (msg-read-methods-fail-loud); a missing UID returns null.
4. CAPTURE: the DevMailbox stores the same {success, message, id} shape and exposes an inspection
   surface (inbox/read/seed/count) for `/__dev`.

## Configuration and precedence

- Env vars (`TINA4_MAIL_HOST`/`_PORT`/`_USERNAME`/`_PASSWORD`/`_FROM`, `TINA4_IMAP_*`,
  `TINA4_MAIL_CAPTURE`, ...) are READ AND ACTED ON by every framework that documents them
  (msg-env-vars-are-honoured-everywhere, ADR-0041). Every env-read configurable is ALSO
  constructor-settable, and the constructor WINS (msg-explicit-beats-env, ADR-0041).
- `TINA4_MAIL_CAPTURE=true` forces capture; a missing SMTP host implies capture; `TINA4_DEBUG` does
  NOT suppress sending (msg-capture-gate). This is the resolved gate - four frameworks once had four
  different answers (one was "always send").

## Failures, side effects and security

- FAIL-LOUD READ, FAIL-SOFT SEND (msg-read-methods-fail-loud): the read methods raise
  `MessengerConnectionError` on a real connection/auth/protocol failure (an empty result means empty,
  never failure); `send()` never raises (it returns a result). This split is uniform and proven.
- UID INTEGRITY (msg-uid-is-a-real-uid, ADR-0042): every id is the IMAP UID, so an id stored today
  still addresses the same message after another client expunges. The pre-fix bug (Python and Node
  returned sequence numbers) silently addressed the WRONG message after an expunge - fixed at
  tina4-python 3237383 and tina4-nodejs c1b28fd; PHP and Ruby were already correct.
- ATTACHMENT BYTES (msg-read-item-shape): `attachments[i].content` is the raw decoded bytes in all
  four, so an attachment is downloadable everywhere (was Python-only before #69/#70).
- No auth is added by the messenger; SMTP/IMAP credentials come from env/constructor and the transport
  uses the configured TLS. Capture writes to a local dev store, never the network.

## Wire and persistence contract

The wire is SMTP (send) and IMAP (read) - the framework's own zero-dep protocol clients. The public
data contract is the three shapes: the send result {success, message, id}, the inbox item {uid,
subject, from, to, date, snippet, seen}, and the read item (10 canonical keys with `attachments`
carrying raw bytes). The `uid` is always the IMAP UID as a string. DevMailbox persistence is a local
store for inspection only.

## Providers and substitutability

There is NO provider seam: SMTP and IMAP are the two protocols, implemented directly. The one
substitution is the capture-vs-send BRANCH inside `create_messenger` - the same concrete type serves a
dev box (capture) and production (send), decided by config, not by a class union or a method swap.

## Contradictions and defects

The FEATURE is proven and needs no code work. The two open items are stale bookkeeping, both corrected
in this commit:

| ID | Finding | Required outcome |
| --- | --- | --- |
| MSG-01 | `messenger_contract.json`'s `msg-uid-is-a-real-uid` invariant still carries `adr: "OWED - needs a new ADR"`, and its `_adr_note` still says "0042 is free ... deliberately NOT allocated here". But ADR-0042 ("The messenger uid is the IMAP UID, never a sequence number") has since been WRITTEN and Accepted, ratifying exactly this rule. The marker is stale. | Update the fixture: set the invariant's `adr` to `ADR-0042` and replace the stale `_adr_note`. Metadata only (the CONTRACT-MAP already counts it PROVEN, so the runners are unaffected). DONE in this commit. |
| MSG-02 | ADR-0041 and ADR-0042 exist as Accepted files (`plan/v3/decisions/ADR-004{1,2}.md`) but neither is listed in the DECISIONS.md index. The index is incomplete. | Add both ADR rows to the DECISIONS.md index with their titles and Accepted status. DONE in this commit. |

Historical defects (all RESOLVED, recorded for provenance): the send/capture 5th-positional split
(`text` vs `cc`) and the method-swap that filed the plain-text body as a CC recipient (Python worst);
the factory returning a `Messenger | DevMailbox` union with no shared send method (Node #41 crash);
PHP-never-captures (the factory was `return new static()`); `text` dropped on every dev path; and the
uid-as-sequence-number data-integrity bug. All are closed by the 14 proven invariants.

## Owner decisions

There are no open behavioural decisions - the contract is ratified (ADR-0004/0008/0041/0042). The two
bookkeeping corrections (MSG-01, MSG-02) are objective syncs to already-Accepted decisions, applied in
this commit rather than proposed. If the owner prefers a fresh ADR number for the uid rule instead of
0042, that is the only reversible call - but 0042 already exists, Accepted, with that exact title, so
the audit treats it as the ratifying ADR.

## Proposed conformance fixture

ALREADY EXISTS and is PROVEN: `messenger_contract.json` (14 invariants, 14 proven, 0 owed) drives
`tests/test_messenger_contract.py`, `tests/MessengerContractTest.php`, `spec/messenger_contract_spec.rb`
and `test/messengerContract.test.ts` against a REAL GreenMail SMTP/IMAP server (no mocks). It is the
model other clusters should reach - the uid invariant in particular is a MEASURED witness (send P1 P2
P3, expunge P1, ask for P3: a sequence-numbering framework returns the wrong message). No new fixture is
owed; only the MSG-01 metadata refresh.

## Integration map

- The factory reads the env/dotenv layer and the capture gate; `send` uses SMTP; the read methods use
  IMAP with UID addressing; DevMailbox `seed` uses the seeder; `attachments[i].content` follows the
  request.files bytes convention.
- `messenger_contract.json` is the shared oracle (proven); ADR-0004/0008/0041/0042 are the ratifying
  decisions; the DECISIONS.md index must list 0041/0042 (MSG-02).
- The dev mailbox surfaces at `/__dev` via the DevMailbox inspection methods.

## Breaking changes and migration

None outstanding. The breaking changes that unified this subsystem already shipped (the send/capture
signature unification, the factory returning one type, the uid-as-UID fix). A deployment on a current
release already speaks the proven contract. The MSG-01/MSG-02 corrections are documentation-only.

## Implementation backlog

1. MSG-01: refresh `messenger_contract.json` (uid invariant `adr` -> ADR-0042; update `_adr_note`).
2. MSG-02: add ADR-0041 and ADR-0042 to the DECISIONS.md index.
3. Nothing else - the feature is proven; re-run the messenger contract runners on the root lab to
   confirm 14/14 stays green at the current HEAD (routine, not a gap).

No framework implementation is needed or belongs in the audit commit.

## Porting capsule

Implement a zero-dependency messenger: a `Messenger` with `send(to, subject, body, html, text, cc,
bcc)` (MIME build, SMTP deliver, returns {success, message, id} and NEVER raises), `send_template`,
`add_header`, and IMAP read methods `inbox(folder, limit, offset)` / `read(uid, folder)` / `search` /
`unread` / `folders` / `mark_read` / `mark_unread` / `delete` that address every fetch/store by the
IMAP UID (never a sequence number), raise `MessengerConnectionError` on a real failure, return null for
a missing UID, and return the canonical shapes (inbox item: uid/subject/from/to/date-ISO/snippet-
decoded/seen; read item: the 10 keys with `attachments[i].content` as raw decoded bytes). Add a
`create_messenger()` factory that returns ONE concrete type and branches to a capture DevMailbox when no
SMTP host is set (or `TINA4_MAIL_CAPTURE=true`), never swapping a method; `TINA4_DEBUG` must not
suppress sending. Every env var is also constructor-settable and the constructor wins. Prove the port
with `messenger_contract.json` against a real GreenMail server - all 14 invariants, no mocks.

## Audit closure checklist

- [x] Boundary and public surface complete (send + IMAP read + DevMailbox capture + the factory gate).
- [x] Lifecycle and every producer/consumer edge complete (factory/send/read/capture).
- [x] Configuration, failure, side-effect and security rules complete (fail-loud read / fail-soft send, uid integrity, env precedence).
- [x] Wire/storage and provider contracts complete (SMTP/IMAP; the three proven shapes; no provider seam).
- [x] Existing-language contradictions recorded (all RESOLVED; MSG-01/MSG-02 are stale bookkeeping, corrected).
- [x] Owner ambiguities recorded (none behavioural; the contract is ratified by ADR-0004/0008/0041/0042).
- [x] Proposed shared cases and mutation witnesses complete (`messenger_contract.json`, 14/14 proven, real GreenMail).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered (two bookkeeping fixes only).
- [x] Porting capsule is clean-room sufficient.
