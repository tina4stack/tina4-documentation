# Feature 042: Session handling

## Identity and status

- Matrix identity: 42 - session lifecycle and interchangeable stores
- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-08-01, previously bundled with Feature 41
- Existing decision: ADR-0021
- Required provider packets: 42.1 file, 42.2 Redis, 42.3 Valkey,
  42.4 MongoDB, 42.5 database and 42.6 memcached

Feature 42 owns session-ID generation/adoption, fixation defense, data
semantics, regeneration/destruction, cookie integration, dirty/save behavior,
backend failure policy and the common provider interface. JWT validation and
request authentication belong to Feature 41.

## Historical evidence retained

The bundled audit reproduced attacker-controlled path traversal through file
session IDs in PHP and Node. It standardized the accepted ID alphabet,
known-session adoption and hashed file names. It also found that a store outage
could be mistaken for an unknown ID and rotate every user's session; the final
rule preserves the supplied ID on transport failure and discards it only when a
healthy store reports a miss.

Open parity gaps remain:

- session entropy was 128 or 256 bits;
- `set()` was lazy in Python/Ruby and eager in PHP/Node;
- `all()` hid four different sets of internal keys;
- Ruby returned the default for a stored `false`;
- invalid HttpOnly config failed open in Python/PHP;
- provider tests and failure behavior were not proven uniformly against live
  backends.

The standalone audit must settle the surface contract first, then give each
42.x provider its own conformance packet and shared fixture report.
