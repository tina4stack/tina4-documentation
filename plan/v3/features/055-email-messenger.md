# Feature 55: Email / Messenger

## Identity and status

- Matrix identity: Feature 55, Email/Messenger (SMTP). The earlier Feature 0
  label described its role as the audit pilot; it is not a second identity.
- Audit state: queued for its numeric position in the 3.14 re-audit
- Existing ADRs: ADR-0004, ADR-0041, ADR-0042
- Shared fixture: `fixtures/messenger_contract.json` (14 current invariants)
- Historical audit: `messenger-contract.md`

## Why this feature exists

Give an application one simple, portable way to compose, send, capture, inspect
and manage email without changing behavior when the Tina4 language changes.

## Boundary

Messenger owns message composition, SMTP sending, development capture, IMAP
inspection and mailbox mutation. Transport protocols, filesystem persistence,
TLS/authentication and attachment bytes cross the boundary and must therefore be
specified rather than inferred from a runtime library.

## Existing implementation evidence

The 2026-07-28 pilot reconciled factory/send/capture behavior and later work
added a 14-invariant shared fixture plus real GreenMail coverage. That evidence
is a baseline, not closure: the 3.14 pass must enumerate the entire SMTP and IMAP
surface, destructive failures and producer-to-consumer identifier flow.

## Public surface contract

Audit pending: factory/construction, send, capture, list/folders, read, search,
attachments, flags, move and delete across all four.

## Inputs and outputs

Audit pending. Existing decided read shape and attachment-content rules must be
re-derived from the fixture and checked against every public path.

## Lifecycle and operation graph

```
compose -> send or capture -> discover folder/message -> read -> fetch attachment
        -> flag/move/delete -> verify resulting mailbox state
```

Every identifier produced by one step must be valid input to the next.

## Configuration and precedence

Audit pending: explicit options, `TINA4_MAIL_*`, SMTP availability, forced
capture, TLS/auth defaults and filesystem mailbox location.

## Failures, side effects and security

Audit pending: connection/auth/TLS failure, partial SMTP delivery, malformed
addresses, missing messages, attachment decoding, destructive IMAP failure,
credential redaction and capture-file atomicity.

## Wire and persistence contract

Audit pending: SMTP/IMAP identifiers, MIME encoding, header normalization,
attachment bytes, capture JSON and folder semantics.

## Providers and substitutability

The same application cases must work against capture storage and real
SMTP/IMAP. Existing real-service evidence uses GreenMail on the `.99` lab.

## Contradictions and defects

Historical defects and fixes are preserved in `messenger-contract.md`. The new
audit has not yet declared the remaining surface complete.

## Owner decisions

- 2026-07-28: SMTP availability, not debug mode, selects real sending; explicit
  `TINA4_MAIL_CAPTURE=true` forces capture.
- 2026-08-08: Feature 55 is the canonical identity. The historical Feature 0
  pilot label is retired rather than kept as an alias.

## Proposed conformance fixture

Extend the current 14 invariants only after every public branch is mapped. New
cases must include missing/stale identifiers and failed destructive operations.

## Integration map

Audit pending: exports, configuration bootstrap, CLI/scaffolding, dev mailbox,
documentation, diagnostics and release migration notes.

## Breaking changes and migration

To be derived from contradictions. Pre-3.14 correction is permitted.

## Implementation backlog

Planning only until the complete audit finishes.

## Porting capsule

Incomplete. This file will become the language-neutral Messenger implementation
plan and the parity oracle for every runtime.

## Audit closure checklist

- [ ] Boundary and public surface complete.
- [ ] Lifecycle and every producer/consumer edge complete.
- [ ] Configuration, failure, side-effect and security rules complete.
- [ ] Wire/storage and provider contracts complete.
- [ ] Existing-language contradictions recorded.
- [ ] Owner ambiguities decided and recorded.
- [ ] Proposed shared cases and mutation witnesses complete.
- [ ] Integration map and breaking migrations complete.
- [ ] Implementation backlog dependency-ordered.
- [ ] Porting capsule is clean-room sufficient.
