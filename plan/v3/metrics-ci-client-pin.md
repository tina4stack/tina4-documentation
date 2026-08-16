# Task: Keep framework CI on the metrics contract client

**Outcome:** all four framework CI suites exercise the current native metrics
contract with the signed Tina4 client release that owns it, and unrelated
boundary/cluster regressions exposed by the rerun are fixed rather than hidden.

## Scope

- [x] Reproduce the failing GitHub Actions jobs at the merged v3 heads.
- [x] Identify the shared metrics handoff failure in all completed jobs.
- [x] Confirm the workflows still pin client 3.8.71 while
      `has_referencing_test` shipped in signed client 3.8.76.
- [x] Pin and checksum client 3.8.76 in Python, PHP, Ruby, and Node CI.
- [x] Fix PHP timeout-boundary classification against libpq's real wording.
- [x] Make Node's cluster distribution test use distinct TCP connections.
- [ ] Run focused tests and complete framework CI at the exact pushed heads.

## Parity

| Rule | Python | PHP | Ruby | Node.js |
| --- | --- | --- | --- | --- |
| CI uses signed client 3.8.76 | ✅ | ✅ | ✅ | ✅ |
| Metrics handoff requires `has_referencing_test` | ✅ | ✅ | ✅ | ✅ |
| No analyzer fallback | ✅ | ✅ | ✅ | ✅ |

## Bugs

- [x] METRICS-CI-CLIENT: all framework workflows pinned 3.8.71 and therefore
      cannot satisfy the current native JSON contract.
- [x] PHP-CONNECT-BOUNDARY: libpq may return a few microseconds before the
      wall-clock threshold while explicitly reporting `timeout expired`.
- [x] NODE-CLUSTER-PROBE: HTTP keep-alive reuses one connection, but Node
      cluster schedules connections rather than individual requests.

## Verification

- [x] The checksummed Linux 3.8.76 binary reports `has_referencing_test`.
- [x] Four focused metrics handoff suites pass with client 3.8.76:
      Python 10, PHP 3 / 18 assertions, Ruby 3, Node 12.
- [x] PHP timeout boundary, real black-hole connect, and instant-refusal
      negative pass: 3 tests / 25 assertions.
- [x] Node cluster-mode suite passes three consecutive runs: 2 tests each.
- [ ] Four GitHub Actions test workflows pass at the final v3 commits.

## Status: In progress
