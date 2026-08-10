# Feature 041: JWT authentication

## Identity and status

- Matrix identity: 41 - zero-dependency JWT authentication
- Current state: reopened / queued for a standalone 3.14 audit
- Historical audit: 2026-08-01, previously bundled with Feature 42
- Existing decision: ADR-0021
- Current shared fixture: copied `test_auth_session_contract` cases, not one
  central data oracle

Feature 41 owns token creation/validation, configured algorithm enforcement,
claims and time boundaries, request authentication, API-key interaction and
the byte-compatible password-hash contract. Session IDs, cookies, persistence
and session backends belong to Feature 42.

## Historical evidence retained

All four implemented HS256/384/512 and rejected `alg: none`. PHP and Node had
native RS256; Python did not. Ruby's partial RS256 path depended on an undeclared
`jwt` gem and could be activated by key files appearing on disk. Password hashes
were verified byte-compatible as
`pbkdf2_sha256$260000$salt$hex` with a 32-byte derived key.

The bundled audit fixed these measured defects:

- Python treated a decoded Basic header as an authenticated truthy result
  without verifying credentials.
- malformed `exp`/`nbf` claims and the exact expiry boundary differed;
- request-auth API-key result shapes differed;
- Python/Ruby route gates bypassed the timing-safe API-key validator.

Still unresolved in the historical packet: route-gate API-key bypass was a
two-two split, Ruby could auto-switch to an undeclared RS256 dependency, and
`expires_in=0` meant non-expiring in three ports but immediately expired in
Ruby. The standalone audit must settle these decisions, centralize executable
vectors and test real application gates rather than copied helpers.
