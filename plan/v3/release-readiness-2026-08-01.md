# Release readiness, 2026-08-01

What is on v3, what it breaks, and what is still open. Written after merging nine
branches into v3 in all four frameworks and verifying on the Linux lab host.

## Verdict

**Not ready to tag today.** The code is green and the merge is done, but three
things must be settled first, and none of them is a test failure:

1. Three test doubles remain on v3 in violation of the no-mock rule (PHP).
2. The release is BREAKING in five user-visible ways and has no migration note.
3. The machine that certifies the release was compromised today and its host
   ports are still open.

Nothing here is a blocker on the framework code itself.

## What landed

Nine branches merged into v3 in tina4-python, tina4-php, tina4-ruby and
tina4-nodejs, and four ADRs onto tina4-documentation main:

  audit-routing (ADR-0019)   audit-caching (ADR-0020)
  audit-auth (ADR-0021)      audit-queues (ADR-0022)
  no-mock-sweep              rs256-optin
  session-backend-defects    session-get-falsy
  test-free-ports (node only)

The ADR log was restructured to one file per record at plan/v3/decisions/ so
parallel branches can never again collide on one line - four agents had appended
at the identical line 1792 of a single DECISIONS.md, producing three stacked
conflicts where "keep ours" would have silently dropped a security ADR.

## Test state

Verified on the Linux lab (192.168.88.99) against live services, at the exact
commits pushed to origin/v3.

| framework | commit    | result                                        |
| --------- | --------- | --------------------------------------------- |
| python    | 4afd5a1   | 4622 passed, 0 failed, 25 skipped             |
| php       | ed9357c2  | 4702 tests, 14736 assertions, 0 failures      |
| ruby      | 4660fee   | 4789 examples, 0 failures, 8 pending          |
| nodejs    | 20fae6c   | 6957 passed, 0 failed, 226 files              |

macOS cannot produce a single-process PHP green - PHP 8.5.7 aborts with
"Maximum execution time of 0 seconds exceeded" despite max_execution_time=0 - so
the lab is the only gate that counts for PHP.

## BREAKING - these need a migration note before tagging

1. **Node RabbitMQ and Kafka queue backends THROW on construction** (ADR-0022).
   An app with backend: "rabbitmq" does not start. This is a holding position
   pending the persistent-connection rewrite, not the settled design.

2. **TINA4_TRUSTED_PROXIES defaults to EMPTY - trust nothing** (ADR-0019).
   Behind nginx, Cloudflare or an ALB, X-Forwarded-For is no longer believed, so
   every client resolves to the proxy IP and the rate limiter buckets them
   together. Any proxied deployment MUST set this or rate limiting misbehaves.

3. **Authenticated GETs are no longer cached** (ADR-0020, RFC 9111 s3.5). This
   closes a measured cross-user leak - PHP served one user's private balance to
   another with X-Cache: HIT - but shared-cache hit rates drop on authenticated
   endpoints. Opt back in per route with Cache-Control: public.

4. **update() / delete() with no filter now RAISE** instead of operating on every
   row. truncate() is the explicit whole-table spelling.

5. **start(id) refuses to adopt an id the store never issued** (ADR-0021,
   session fixation). An app that mints its own session ids breaks.

### Session invalidation is backend-dependent, not universal

ADR-0021 changed the on-disk/key name to sha256(id) where the id becomes a NAME.
Only two backends are affected:

| backend        | derivation            | existing sessions |
| -------------- | --------------------- | ----------------- |
| file           | sha256(id)            | INVALIDATED       |
| memcached      | prefix + sha256(id)   | INVALIDATED       |
| redis / valkey | prefix + raw id       | survive           |
| mongodb        | _id = raw id          | survive           |
| database       | raw id                | survive           |

Most production deployments are on redis or mongo and will see NO relogin. Do
not state "everyone is logged out" in the notes - it is wrong for three of five.

## Real bugs fixed in this cycle

- **PHP Session::saveToFile discarded file_put_contents' return value.** That
  function returns false and does not throw, so a write that never landed left
  save() returning true. Silent session loss. PHP-only: Python, Ruby and Node
  all use APIs that raise, so their identical safeWrite wrappers already caught
  it. Verified empirically on Ruby.

- **Ruby MemcachedHandler#gc had arity 0** (`alias gc cleanup`) while Session#gc
  calls handler.gc(max_lifetime). Session GC has NEVER worked on a memcached
  session backend; the ArgumentError was then reported as a BACKEND failure, so
  an internal bug was blamed on the operator's memcached. Parity checked: Python,
  PHP and Node all already take the argument. Ruby was the 1-of-4 outlier.

- **Ruby TINA4_LOG_STRICT was a documented no-op.** stdlib ::Logger::LogDevice
  swallowed the write failure one layer below Tina4 and downgraded it to a stderr
  warning. Measured on a genuinely full ram disk. Now wired through Logger's
  reraise_write_errors: seam.

Both Ruby bugs were only findable because the no-mock sweep removed the doubles
that were hiding them.

## Open, must be decided before tagging

1. **Three test doubles still on v3, violating the no-mock rule**:
   ScriptedApi (tests/ApiTest.php), FlakyCommitAdapter (tests/DbContractAbcTest.php),
   TestableWebSocket (tests/WebSocketV3Test.php). The rule is absolute, so v3
   ships in violation of it today.

2. **No CHANGELOG "Breaking:" entries** for the five items above. Contract
   changes require a Breaking: line plus a migration note.

3. **Stored-nil semantics remain a 2-vs-2 split.** Fixing Ruby's Session#get to
   match PHP/Node makes PYTHON the 1-of-4 outlier on a stored nil. Owner call.

4. **ADR-0020 is a conformance restatement, not a decision** (RFC 9111 MUST NOT
   plus ecosystem unanimity). Three independent reviews agreed. It should be
   reclassified rather than numbered as an architecture decision.

5. **Four breaking ADRs have ZERO code anchors** - 0005, 0008, 0014, 0017 - while
   the meta-policy ADR-0004 has 44. The anchoring convention is followed where it
   matters least.

## Lab host security - open

The lab was compromised on 2026-08-01. tina4-lab-mongo was found by a mass
scanner (45.156.87.252), its databases dropped and a READ_ME_TO_RECOVER_YOUR_DATA
ransom note written demanding 0.0079 BTC. 86 distinct public IPs appear in the
mongod log. Do not pay - this campaign drops data and bluffs exfiltration.

Closed:
- All 12 lab containers now bind 127.0.0.1 + 192.168.88.99 instead of 0.0.0.0.
- DOCKER-USER firewall restricts every published container port to the LAN,
  persisted via tina4-lab-firewall.service, mutation-proven enforced.
- Root cause fixed in tina4-lab.sh: port specs were lifted from the CI workflows,
  where 0.0.0.0 is harmless (ephemeral runner, no inbound route), onto a
  long-lived host where it is a door. ufw would NOT have helped - docker's DNAT
  sits in nat/PREROUTING, before ufw filters.

STILL OPEN:
- Host ports remain unfiltered (INPUT policy ACCEPT, ufw inactive):
  16443 Kubernetes API, 10250 kubelet, 10257, 10259, 25000 cluster-agent, 22.
  DOCKER-USER cannot reach these. 10250 and 16443 are the ones to worry about.
- tina4-lab-firebird (3050), the MQTT brokers and the GPU containers (vllm-*,
  tina4-rag, tina4-gateway, diffusion) are not managed by tina4-lab.sh and still
  bind 0.0.0.0 - covered by the firewall only.
- Whether the router forwards all ports or only some is unknown from inside.

## Process fix landed

The credential env names had drifted: the suites read TINA4_TEST_MYSQL_USERNAME/
_PASSWORD, infra env exported _USER/_PASS, and nothing checked they agreed. Every
mysql/mssql test fell through to its own default and had been green for months
only because a long-lived container allowed passwordless root.

This was the THIRD instance of the same failure mode in this file (see the
TINA4_TEST_PG_DB2 note), and the second time it was diagnosed, written down, and
not fixed. check_env_contract() now machine-checks the contract in doctor and is
mutation-proven. A note is not a control.
