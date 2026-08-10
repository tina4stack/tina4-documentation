# Feature 094: MQTT client

## Identity and status

- Matrix identity: 94 - MQTT client
- Audit state: decision-ready
- Audit note: measured from four-language source 2026-08-10 (the MQTT client in each repo) at Python
  `386cd6d`, PHP `743b7469`, Ruby `c61250c`, Node `26be920` (PHP files verified byte-identical to v3).
  Four parallel extractions + I cross-checked the four normative rules (especially the security-critical
  per-client TLS trust store) against each framework's quoted construction. The authoritative design is
  `plan/v3/mqtt-implementation.md` (its status header "Python/PHP/Node pending" is STALE - all four
  shipped 2026-07-23). No framework code changed.
- Dependencies: the env/dotenv layer (`TINA4_MQTT_*`), the cooperative-background scheduler (keepalive),
  the log layer (TLS verify-off warning); TLS uses each runtime's stdlib SSL
- Dependants: IoT / telemetry / EV-charging apps (Phase 1b of the IoT plan); any app talking to an MQTT
  broker
- Existing ADRs: none specific to MQTT (the QoS-2 refusal and the env precedence follow the framework
  conventions; ADR-0024 env-single-source is reused for truthiness). This audit proposes the first (the
  MQTT contract) plus the fixture.
- Shared fixtures: NONE. `mqtt_contract.json` is owed (no fixture, no CONTRACT-MAP row). The client is
  proven per-framework by REAL broker tests (Python 53, Ruby 78, PHP 50, Node 77 no-mock, vs real
  Mosquitto/EMQX) but not by one oracle. Given the deep parity it is highly fixturable.
- Catalog phase: Integrations

## Why this feature exists

An IoT or telemetry application needs to talk MQTT without a heavy dependency. Tina4 ships a hand-rolled,
ZERO-DEPENDENCY MQTT 3.1.1 client in every language: CONNECT/PUBLISH/SUBSCRIBE with QoS 0/1, retained
messages, Last Will, keepalive, TLS with real certificate verification, and durable sessions - the same
shape across four languages, spike-proven against real Mosquitto and hardened by the Ruby port that
found the reference spike's bugs.

## Boundary

This feature owns the MQTT CLIENT: the wire codec (fixed header, Remaining-Length varint, the 3.1.1
packet set), CONNECT/CONNACK, PUBLISH/PUBACK (QoS 0/1), SUBSCRIBE/SUBACK, PINGREQ/PINGRESP, DISCONNECT,
the ack-parking inbox, `consume`/`receive` acknowledgement, retained/will/keepalive, the per-client TLS
trust store, and `parse_url`/env config. It is a CLIENT only - Tina4 is not an MQTT broker.

## Existing implementation evidence

The four NORMATIVE rules (all found by the Ruby port; all PRESENT in all four):

| Rule | Python | PHP | Ruby | Node |
| --- | --- | --- | --- | --- |
| #1 ack-parking (loop + inbox; PUBACK AND SUBACK; receive drains first) | yes | yes | yes | yes |
| #2 consume acks AFTER handler; receive acks immediately | yes | yes | yes | yes |
| #3 TLS per-client trust store (never the shared default; verify-off warns) | yes | yes | yes | yes |
| #4 importing the client has no side effects | yes | yes | yes | yes |

And the wire + behaviour contract (all four):

| Evidence | All four |
| --- | --- |
| Zero-dep hand-rolled 3.1.1 (no paho/mqtt-gem/php-mqtt/npm-mqtt) | yes (socket/struct/ssl per runtime) |
| Remaining-Length varint correct at the 128 boundary (0/127/128/16383/max tested) | yes |
| QoS 0 (no id, no ack) / QoS 1 (id + PUBACK); QoS 2 REFUSED loudly (names the idempotent-consumer alternative) | yes |
| Retained (retain bit; empty-payload clear) | yes |
| Last Will (flag 0x04, QoS bits 3-4, retain 0x20; correct payload order; kill fires it, disconnect suppresses it) | yes |
| Cooperative keepalive (no dedicated thread; pings only when idle) | yes |
| Credentials from URL userinfo or constructor (NO username/password env var) | yes (consistent) |
| Real no-mock broker tests (Mosquitto anon/auth/TLS + EMQX) | yes |

This is reference-quality 4/4 parity. The divergences are one owed fixture, one Node-specific concurrency
footgun the async model introduces, a test-coverage-parity gap, and small per-language guards.

## Public surface contract

`Mqtt(url, client_id, username, password, ca_file, tls_verify, keepalive, clean_session, will_*,
timeout, read_timeout, connect)` with `parse_url`, `connect`/`connected`/`disconnect`/`kill`,
`publish(topic, payload, qos=0, retain=False) -> packet_id|None`, `subscribe(topic_filter, qos=1) ->
packet_id`, `receive(timeout, ack=True) -> MqttMessage`, `consume(topic_filter, qos, iterations,
timeout)` (a generator, mirroring `Queue.consume`), `acknowledge(packet_id)`, `ping`/`send_keepalive`/
`start_keepalive`/`stop_keepalive`, and `tls`/`cipher`/`tls_version`. `MqttMessage` carries topic,
payload (bytes), qos, packet_id, retained, duplicate, and `acknowledge`/`text`/`to_dict`. Naming is
snake_case (Python/Ruby) and camelCase (PHP/Node) per the framework convention; the concept set is
identical.

## Inputs and outputs

- Input: a broker URL (`mqtt://`/`tcp://` plain 1883, `mqtts://` TLS 8883), credentials, a client id,
  keepalive, a will, and per-publish topic/payload/qos/retain.
- Output: `publish` returns the packet id (QoS 1) or null (QoS 0); `subscribe` returns the packet id;
  `receive`/`consume` yield `MqttMessage`; TLS accessors return the negotiated cipher/version (proof of
  a completed handshake). A refused QoS 2, a bad SUBACK (0x80), a mismatched ack id, or a real
  connect/auth/TLS failure RAISES a typed `MqttError`/`MqttTimeoutError`.

## Lifecycle and operation graph

1. CONNECT: build CONNECT (protocol level 4, keepalive, clean-session flag, optional will, optional
   username/password), send, read CONNACK, map the return code.
2. PUBLISH: QoS 0 sends no packet id and waits for nothing; QoS 1 sends a packet id and waits for the
   matching PUBACK - through the ack-parking loop that PARKS any inbound PUBLISH into the inbox.
3. SUBSCRIBE: send with a packet id, wait for the SUBACK (same ack-parking loop), reject a 0x80 grant.
4. RECEIVE/CONSUME: `receive` drains the inbox first, then reads a PUBLISH, acking immediately (or per
   `ack`); `consume` yields with `ack=false` and acks AFTER the handler (a raising handler leaves it
   unacked -> broker redelivers with DUP).
5. KEEPALIVE: a cooperative background task pings only when the socket has been idle.
6. CLOSE: `disconnect` sends DISCONNECT (broker discards the will); `kill` drops the socket (the will
   fires).

## Configuration and precedence

- `TINA4_MQTT_URL` (default `mqtt://127.0.0.1:1883`), `TINA4_MQTT_CLIENT_ID` (default `tina4-<random>`),
  `TINA4_MQTT_KEEPALIVE` (default 60), `TINA4_MQTT_CA_FILE`, `TINA4_MQTT_TLS_VERIFY` (default true) -
  read via each framework's env wrapper; an explicit constructor arg WINS over the URL userinfo and the
  env. There is NO `TINA4_MQTT_USERNAME`/`_PASSWORD` in any framework - credentials come from the URL or
  the constructor (consistent across the four).
- `parse_url` accepts `mqtt://`/`tcp://` (plain) and `mqtts://` (TLS), bracketed IPv6, a last-`@` split
  so an un-encoded `@` in a password survives, and percent-decoding that preserves `+`.

## Failures, side effects and security

- TLS PER-CLIENT TRUST STORE (NORMATIVE #3, the security core): every framework builds its OWN trust
  store and never touches the shared/process-wide default - Python a fresh `ssl.SSLContext(
  PROTOCOL_TLS_CLIENT)`, Ruby its own `OpenSSL::X509::Store` with `cert_store=`, PHP a per-stream `ssl`
  context, Node a fresh per-connection `tls.ConnectionOptions`. This closes the exact bug the Ruby port
  found (a shared store leaked the CA to every later client, so a self-signed cert was accepted without
  a CA - "plaintext trust wearing a TLS badge"). Proven by REAL negative tests in all four: a self-
  signed cert is REJECTED without a CA, and a CA loaded into one client does NOT leak into a later
  client in the same process. Verify-off logs a loud warning naming MITM and `TINA4_MQTT_CA_FILE`.
- ACK-PARKING (NORMATIVE #1): the ack-wait LOOPS and parks inbound PUBLISHes into an inbox rather than
  assuming the next packet is the ack - covering BOTH PUBACK and SUBACK, because on a `clean_session=
  false` resume the broker replays queued PUBLISHes BEFORE the SUBACK. `receive` drains the inbox first,
  so no parked message is lost. A mismatched ack id RAISES rather than silently desyncing. Proven by a
  real durable-replay-before-SUBACK test in all four.
- QoS 2 REFUSED loudly (all four): a QoS-2 publish/subscribe/will raises naming the limit AND the
  alternative ("use QoS 1 with an idempotent consumer keyed on (device_id, device_timestamp)") - never
  silently downgraded, never sent as nothing.
- SUBACK 0x80 (subscription refused) RAISES in all four (the code path), so a refused subscription is
  never a silent "receive nothing" - but the TEST driving it exists only in Ruby (MQTT-03).
- The single-reader contract is documented in all four; only Node's async model makes a concurrent
  second reader reachable from ordinary user code (MQTT-02).

## Wire and persistence contract

No persistence. The wire is MQTT 3.1.1 over TCP (or TLS): a fixed header (packet type + flags), a
Remaining-Length varint (7 bits/byte, high bit continuation, capped at 4 bytes), then the variable
header + payload. The packet identifier exists ONLY at QoS > 0. The will flags and payload order
(client id, will topic, will message, username, password) are fixed. Every framework encodes the
identical bytes - the varint 128 boundary and the QoS-0-no-id rule are the classic hand-rolled-client
bugs, and all four are tested against them.

## Providers and substitutability

No provider seam - the broker is external (Mosquitto, EMQX, any 3.1.1 broker). The client is the unit;
an app substitutes a broker by changing `TINA4_MQTT_URL`. TLS vs plain is chosen by the URL scheme.

## Contradictions and defects

The client is reference-quality parity. The open items are one owed fixture and four targeted gaps:

| ID | Finding | Required outcome |
| --- | --- | --- |
| MQTT-01 | No `mqtt_contract.json`; no CONTRACT-MAP row; no ADR. Each framework has its own real-broker tests (Python 53, Ruby 78, PHP 50, Node 77) but not one shared oracle - despite deep, identical behaviour (ack-parking, consume/receive-ack, TLS store, QoS-2 refusal, retained, will, keepalive, the varint boundary). | Add `mqtt_contract.json` driving four runners against a real broker: the varint boundary, QoS-2 refusal, ack-parking (replay-before-SUBACK), consume-acks-after vs receive-acks-now, retained + clear, will fires on kill, TLS self-signed-rejected + no-CA-leak, SUBACK-0x80 refusal. Add the first MQTT ADR. |
| MQTT-02 | FIX NODE (concurrency): Node's async model overwrites `this.waiter` unconditionally in `readExact`, so a `consume()` loop AND a concurrent `publish(qos=1)` on the same client silently clobber the first waiter (it hangs to its deadline, or forever if `read_timeout` is null). The three synchronous backends block the whole call, so a second concurrent reader cannot interleave - the footgun is Node-only, unguarded, and untested. | Node guards the single-reader invariant at runtime (throw or queue when a waiter is already outstanding) OR serialises publish-ack and receive on one internal reader; add a test for the concurrent case. |
| MQTT-03 | Test-coverage parity: the SUBACK-0x80 (subscription refused) code path exists in all four, but the TEST driving a broker that returns 0x80 exists ONLY in Ruby (4 EMQX cases). Python confirmed lacking; PHP/Node have EMQX in the infra but no confirmed 0x80 test. The "silently receive nothing" footgun is under-tested in three of four. | Add the EMQX SUBACK-0x80 refusal test to Python, PHP and Node (Ruby is the reference), against the EMQX broker already in `mqtt-infra.sh`. |
| MQTT-04 | PHP-only code-quality: the will-payload length uses `pack('n', strlen(...))` WITHOUT the 65535 guard that `mqttString` enforces (`Mqtt.php:388`), so a >64KiB will silently truncates the length and corrupts the CONNECT; and two trusted-broker `unpack` sites (parsePublish, waitForAcknowledgement) lack the length guard their CONNACK/SUBACK siblings have. | PHP adds the 65535 guard to the will-payload length and the length guard to the two `unpack` sites (a malformed short packet should raise a clean `MqttError`, not a PHP warning). |
| MQTT-05 | Env-uniformity: the `TINA4_MQTT_*` vars are read by the client but not registered in the CLI `known_vars()` (Python confirmed; likely all four), so `tina4` env tooling/doctor does not know about them. | Add `TINA4_MQTT_URL`/`_CLIENT_ID`/`_KEEPALIVE`/`_CA_FILE`/`_TLS_VERIFY` to the CLI `known_vars()` index. |

Not defects (recorded so they are not re-raised): the per-language SNI/TLS nuances are DELIBERATE and
documented (Python always passes `server_hostname` and matches IP-SANs; Ruby skips SNI for an IP literal;
PHP uses `peer_name` incl. IP-SANs; Node sets `rejectUnauthorized`+`ca` per connection). Auto-reconnect
(E1) is a listed OPEN follow-up, not a parity gap. The broker-gated tests self-SKIP when the broker is
down, so a green run without `TINA4_REQUIRE_SERVICES` + infra proves only the pure-logic assertions - a
shared verification-gate caveat, addressed by the fixture running under the real-service gate.

## Owner decisions

The client is proven parity; the open calls are:

1. FIXTURE + ADR (MQTT-01): add `mqtt_contract.json` and the first MQTT ADR. Headline owed item.
2. NODE CONCURRENCY (MQTT-02): guard the single-reader invariant in Node (the one place the async model
   diverges). FIX NODE.
3. SUBACK-0x80 COVERAGE (MQTT-03): add the refusal test to Python/PHP/Node.
4. PHP GUARDS (MQTT-04): the will-length + unpack length guards.
5. ENV INDEX (MQTT-05): register the MQTT env vars in the CLI.

No open behavioural decision on the wire contract - it is settled and spike-proven.

## Proposed conformance fixture

Add `mqtt_contract.json` driving four runners against a REAL broker (no mocks - every framework already
uses real Mosquitto/EMQX): `encode_remaining_length` over 0/127/128/16383/max; a QoS-2 publish/subscribe
raises naming the alternative; a QoS-1 publish round-trips its packet id + PUBACK while QoS 0 returns
none; a `clean_session=false` resume replays a PUBLISH BEFORE the SUBACK and it is parked, not mistaken
for the ack; `consume` acks only after the handler (a raising handler leaves it unacked -> DUP) while
`receive` acks immediately; a retained message reaches a late subscriber and an empty payload clears it;
a will fires on `kill()` and is discarded on `disconnect()`; a TLS connection REJECTS a self-signed cert
without a CA and a CA loaded into one client does NOT leak into a later client; and a SUBACK 0x80
raises. The TLS negatives and the replay-before-SUBACK case are the load-bearing witnesses.

## Integration map

- Selected/configured by `TINA4_MQTT_*` (register them in the CLI - MQTT-05); keepalive uses the
  cooperative background scheduler (the same one the queue consumers use); TLS uses each runtime's
  stdlib SSL with a per-client store.
- `mqtt_contract.json` (owed) is the shared oracle; `mqtt-implementation.md` is the normative design
  (its status header needs refreshing to "4/4 shipped").
- Real brokers are provisioned by `mqtt-infra.sh` (Mosquitto 1883 anon / 1884 auth / 8883 TLS / 1885
  EMQX); the real-service gate must be set for the wire coverage to actually run.

## Breaking changes and migration

None outstanding. The client shipped 4/4 at parity. MQTT-02 (Node waiter guard) makes a
currently-hanging concurrent-misuse case fail fast or serialise - additive safety, no correct usage
breaks. MQTT-03/04/05 are test, guard and index additions. The fixture (MQTT-01) is additive proof.

## Implementation backlog

1. Add `mqtt_contract.json` and wire four runners under the real-service gate (MQTT-01); add the first
   MQTT ADR.
2. Node: guard the single-reader invariant + test the concurrent case (MQTT-02).
3. Add the EMQX SUBACK-0x80 refusal test to Python/PHP/Node (MQTT-03).
4. PHP: the will-length + unpack length guards (MQTT-04). Register the MQTT env vars in the CLI
   `known_vars()` (MQTT-05). Run locally and on the root lab with brokers up, then flip owed->proven in
   CONTRACT-MAP.

## Porting capsule

Implement a zero-dependency MQTT 3.1.1 client: encode a fixed header + a Remaining-Length varint (7
bits/byte, high-bit continuation, 4-byte cap - test 128); CONNECT (protocol level 4, keepalive, clean-
session, optional will with flag 0x04 / QoS at bits 3-4 / retain 0x20 and payload order client-id, will-
topic, will-message, username, password), read CONNACK; PUBLISH with a packet id ONLY at QoS > 0 and the
retain low-bit, waiting for the matching PUBACK at QoS 1 through an ack-wait that LOOPS and PARKS inbound
PUBLISHes into an inbox (the same loop serves SUBACK); SUBSCRIBE (low nibble 0x2), reject a 0x80 grant;
`receive` drains the inbox then reads, acking immediately (or per a flag); `consume` yields then acks
AFTER the handler; PINGREQ/PINGRESP from a cooperative background task that pings only when idle. Refuse
QoS 2 loudly. For TLS, build your OWN trust store (never the shared default), verify the peer, and log
loudly when verification is off. Have NO import side effects. Prove it with `mqtt_contract.json` against
a real broker - the varint boundary, ack-parking replay-before-SUBACK, consume/receive ack, retained,
will, and the TLS self-signed-rejected + no-CA-leak negatives.

## Audit closure checklist

- [x] Boundary and public surface complete (the 3.1.1 client; not a broker).
- [x] Lifecycle and every producer/consumer edge complete (connect/publish/subscribe/receive/consume/keepalive/close).
- [x] Configuration, failure, side-effect and security rules complete (per-client TLS store, ack-parking, QoS-2 refusal).
- [x] Wire/storage and provider contracts complete (MQTT 3.1.1 bytes; broker is external).
- [x] Existing-language contradictions recorded (MQTT-01..05; reference-quality parity, Node concurrency the one real divergence).
- [x] Owner ambiguities recorded (5; the fixture and the Node waiter guard are the keys).
- [x] Proposed shared cases and mutation witnesses complete (`mqtt_contract.json` over a real broker, no mocks).
- [x] Integration map and breaking migrations complete.
- [x] Implementation backlog dependency-ordered.
- [x] Porting capsule is clean-room sufficient.
