# Task: MQTT 3.1.1 in core, all four frameworks

Owner go-ahead 2026-07-23: "would be good to get MQTT working", "keep to zero deps and efficient
code". Phase 1b of `iot-and-ev-charging.md`. Companion test cases in `iot-gis-test-plan.md`
(A5-A11, E1-E2).

## Status: SPIKE PROVEN, build not started

The plan called for a spike before committing four implementations. Done, and it passes.

## Spike result (2026-07-23)

`plan/v3/spikes/mqtt_spike.py`, 246 lines, **stdlib only** (`socket`, `struct`), run against a real
Eclipse Mosquitto 2 in Docker on 1883. **15 of 15 checks passed:**

| Proven | Why it matters |
|--------|----------------|
| CONNECT / CONNACK rc=0 | session establishment |
| Remaining-Length varint 0, 127, **128**, 16383 | 128 is the multi-byte boundary where naive encoders break |
| PUBLISH QoS 0 | no packet id on the wire, no ack |
| PUBLISH QoS 1 + matching PUBACK | the id must round-trip or you have silent loss |
| PINGREQ / PINGRESP | keepalive, which is what makes the Last Will fire |
| SUBSCRIBE / SUBACK granted QoS | including the `fleet/+/telemetry` wildcard |
| Topic + payload intact end to end | no framing corruption |
| Retained message to a LATE subscriber | dashboards get current state on connect |
| **Last Will on ungraceful close** | dead-device detection, not inferred from silence |
| Retained cleared by empty payload | the documented way to reset state |

Reproduce: `docker run -d --name tina4-mosquitto -p 1883:1883 -v
$PWD/plan/v3/spikes/mosquitto.conf:/mosquitto/config/mosquitto.conf eclipse-mosquitto:2` then
`python3 plan/v3/spikes/mqtt_spike.py`.

## Wire-protocol facts the four implementations must all get right

These are the places a hand-rolled client goes wrong. Every one is covered by the spike.

1. **The packet identifier exists only when QoS > 0.** Emitting it at QoS 0, or omitting it at
   QoS 1, desynchronises the stream and every later packet mis-parses.
2. **Remaining Length is a varint**, 7 bits per byte with the high bit as continuation. Test 128
   explicitly: a single-byte assumption works for every payload under 128 bytes and then fails.
3. **TCP is a stream, so `recv` returns short.** Read into a buffer in a loop. Assuming one `recv`
   yields a whole packet is the classic bug and it only shows under load.
4. **Read the fixed header in exactly 1 + N bytes** (N <= 4). Speculatively over-reading consumes
   the next packet's header.
5. **SUBACK can refuse** with 0x80. Treating any SUBACK as success means silently receiving nothing.
6. **Connect-flag bit order** for the will: flag 0x04, QoS at bits 3-4, retain 0x20, and the payload
   order is client id, will topic, will message, username, password.

## Efficiency constraints (owner: "efficient code")

- One `bytearray` per packet; no string concatenation in the publish path.
- `TCP_NODELAY` on: telemetry frames are tiny and Nagle would add latency for no gain.
- Slice the payload out of the single read buffer; no per-byte loops.
- `__slots__` on the client (Python) - a fleet ingest process may hold many.
- No background thread by default. Reuse the existing `background()` cooperative task for the
  keepalive, exactly as the queue consumers do.

## Design: shaped like Queue, lazy-loaded

Per the architectural position in `iot-and-ev-charging.md`: in core, but nobody who does not use it
pays for it.

```
Mqtt(url="mqtt://broker:1883", client_id=...)   # TINA4_MQTT_URL
  .publish(topic, payload, qos=0, retain=False)
  .subscribe(filter, qos=1)
  .consume()                                    # generator, mirrors Queue.consume()
```

Env: `TINA4_MQTT_URL`, `TINA4_MQTT_CLIENT_ID`, `TINA4_MQTT_KEEPALIVE`.
Naming per language: `publish`/`subscribe` everywhere; snake_case in Python/Ruby, camelCase in
PHP/Node, per the existing convention.

## Scope
- [x] Spike hand-rolled MQTT 3.1.1 against real Mosquitto (15/15)
- [ ] Python master implementation + real-broker tests
- [ ] Mirror PHP / Ruby / Node + equivalent tests
- [ ] Mosquitto as a CI service in all four workflows (same as redis/kafka/rabbitmq)
- [ ] **QoS 2: refuse loudly. DECIDED by the owner 2026-07-23.** `qos=2` raises immediately with a
      message naming the limit and the alternative, in all four frameworks. It is NOT silently
      downgraded to QoS 1: a caller who asked for exactly-once and got at-least-once would
      double-process without ever seeing an error, which is the same silent-success failure class as
      the bare `require()` and the `testing: true` SSE tests. The error text must say what to do
      instead: use QoS 1 with an idempotent consumer keyed on `(device_id, device_timestamp)`.
      Lock-in test per framework: `qos=2` raises, and the message names both the limit and the
      alternative. QoS 2 support can land later without a breaking change, since today's behaviour
      is an error rather than a wrong success.
- [ ] Idempotent ingest helper (test case A5): QoS 1 is at-least-once, so duplicates are guaranteed.
      Natural key `(device_id, device_timestamp)`, not an incrementing counter.
- [ ] Reconnect + clean-session=false replay (E1)
- [ ] Docs: one chapter per framework, generated from the same source

## Decisions taken
1. **QoS 2: refuse loudly** (owner, 2026-07-23). See the scope item above for the contract.
2. **MQTT 5 features** (topic aliases, shared subscriptions, session expiry) are out of scope for
   the first release. 3.1.1 is what every broker and device speaks.
3. **Modbus and OCPP stay separate.** OCPP 1.6J is JSON frames over WebSocket, which we already
   ship; Modbus TCP is a small binary request/response with no broker. Neither belongs inside the
   MQTT module.
