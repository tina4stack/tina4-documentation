# Feature 079: Route groups

## Identity and status

- Matrix identity: 79 - nested route prefixes and shared policy
- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-08-01, previously hidden in the 11/12/79 bundle
- Dependencies: Feature 6 router/dispatch and Feature 7 middleware
- Existing decisions: ADR-0015 and ADR-0019

Feature 79 owns deterministic prefix joining, nested group composition,
middleware inheritance/order and group-level policy declarations. It does not
own route matching precedence, middleware hook execution or CLI rendering.

## Historical evidence retained

The old audit fixed three Python defects: group middleware ran twice, a nested
prefix was dropped, and merely adding middleware disabled the write-route auth
gate. PHP, Ruby and Node were already correct on those measured cases.

Two gaps remained:

- Ruby accepted and displayed `auth_handler:` on a group but dispatch never
  called it, creating a false security declaration.
- Only PHP normalized all leading/trailing slash combinations. Python, Ruby and
  Node could form `/apiusers`, a path without a leading slash or `/api//users`.

Only Python received the historical group regression suite. The standalone
audit must establish one prefix grammar, one inheritance/order formula, an
explicit group-auth decision and a shared nested-group fixture for every
current and future language.
