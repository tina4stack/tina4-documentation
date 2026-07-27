"""
MQTT spike, part 2: the behaviours the framework code must SURVIVE, not just perform.

Part 1 (mqtt_spike.py) proved the happy path. This proves the awkward half:
offline replay, keepalive expiry, redelivery with DUP set, and what the broker
actually does with QoS 2 (so our refusal is a documented client-side choice
rather than an assumption).

Run against the same real Mosquitto. stdlib only.
"""
import socket
import struct
import time
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mqtt_spike import Mqtt, _varint, _mstr, PUBLISH, PUBACK, SUBACK  # noqa: E402

passed = failed = 0


def check(label, cond, detail=""):
    global passed, failed
    if cond:
        print(f"  PASS  {label}")
        passed += 1
    else:
        print(f"  FAIL  {label} {detail}")
        failed += 1


print("=== MQTT session / resilience behaviours vs real Mosquitto ===")

TOPIC = "spike2/fleet/meter-7/telemetry"

# ---------------------------------------------------------------------------
# 1. clean_session=False: the broker must queue QoS 1 while we are OFFLINE and
#    replay on reconnect. This is what makes an intermittent SIM survivable, and
#    it is test case E1 in the IoT test plan.
# ---------------------------------------------------------------------------
sub = Mqtt()
sub.connect("spike2-durable", clean=False)
sub.subscribe(TOPIC, qos=1)
sub.disconnect()                                  # graceful: session persists

pub = Mqtt()
pub.connect("spike2-pub")
for i in range(3):
    pub.publish(TOPIC, f'{{"n":{i}}}', qos=1)     # published while sub is GONE
pub.disconnect()

back = Mqtt()
back.connect("spike2-durable", clean=False)       # same client id, clean=False
got = []
back.sock.settimeout(3)
try:
    for _ in range(3):
        topic, payload, qos = back.receive()
        got.append(payload)
except (socket.timeout, TimeoutError):
    pass
check("offline QoS 1 messages replayed on reconnect", len(got) == 3, f"got {len(got)}: {got}")
check("replayed payloads intact and ordered",
      got == [b'{"n":0}', b'{"n":1}', b'{"n":2}'], str(got))
back.disconnect()

# ---------------------------------------------------------------------------
# 2. clean_session=True must NOT replay. Proves the flag actually does something,
#    so a framework default of True cannot silently lose data people expected.
# ---------------------------------------------------------------------------
s2 = Mqtt()
s2.connect("spike2-clean", clean=True)
s2.subscribe("spike2/clean", qos=1)
s2.disconnect()
p2 = Mqtt()
p2.connect("spike2-pub2")
p2.publish("spike2/clean", "lost", qos=1)
p2.disconnect()
s2b = Mqtt()
s2b.connect("spike2-clean", clean=True)
s2b.subscribe("spike2/clean", qos=1)
s2b.sock.settimeout(2)
replayed = True
try:
    s2b.receive()
except (socket.timeout, TimeoutError):
    replayed = False
check("clean_session=True does NOT replay (flag is real)", replayed is False)
s2b.disconnect()

# ---------------------------------------------------------------------------
# 3. Keepalive expiry. The broker MUST drop a client that goes quiet past
#    1.5 x keepalive. This is the mechanism the Last Will depends on, so if our
#    client forgets to PINGREQ it gets silently disconnected in production.
# ---------------------------------------------------------------------------
quiet = Mqtt()
quiet.connect("spike2-quiet", keepalive=2)
quiet.sock.settimeout(8)
t0 = time.time()
dropped = False
try:
    quiet.sock.recv(1)                            # returns b"" when broker closes
    dropped = True
except (socket.timeout, TimeoutError):
    dropped = False
except ConnectionError:
    dropped = True
elapsed = time.time() - t0
check("broker drops a silent client past 1.5x keepalive", dropped,
      f"still connected after {elapsed:.1f}s")
check("drop happened at roughly 1.5x keepalive (3s), not instantly",
      2.0 <= elapsed <= 7.0, f"{elapsed:.1f}s")
try:
    quiet.sock.close()
except Exception:
    pass

# A client that DOES ping survives the same window.
alive = Mqtt()
alive.connect("spike2-alive", keepalive=2)
time.sleep(1.2)
alive.ping()
time.sleep(1.2)
alive.ping()
check("PINGREQ keeps the session alive across 2x keepalive", alive.ping())
alive.disconnect()

# ---------------------------------------------------------------------------
# 4. Redelivery sets the DUP flag. We must NOT treat DUP as a new sample: this
#    is test case A5 (duplicate delivery / double-billed energy).
# ---------------------------------------------------------------------------
dup_sub = Mqtt()
dup_sub.connect("spike2-dup", clean=False)
dup_sub.subscribe("spike2/dup", qos=1)
dp = Mqtt()
dp.connect("spike2-dup-pub")
dp.publish("spike2/dup", "once", qos=1)
dp.disconnect()

# Read the PUBLISH but deliberately do NOT send PUBACK, then drop the socket.
head, body = dup_sub._read_packet()
first_dup = bool(head & 0x08)
dup_sub.kill()                                    # no PUBACK, no DISCONNECT

again = Mqtt()
again.connect("spike2-dup", clean=False)
again.sock.settimeout(4)
redelivered, dup_flag = False, False
try:
    h2, b2 = again._read_packet()
    redelivered = (h2 & 0xF0) == PUBLISH
    dup_flag = bool(h2 & 0x08)
except (socket.timeout, TimeoutError):
    pass
check("first delivery has DUP clear", first_dup is False)
check("unacked QoS 1 message is redelivered", redelivered)
check("redelivery sets the DUP flag (A5: must be idempotent)", dup_flag,
      "DUP not set - a consumer cannot tell this is a repeat")
again.disconnect()

# ---------------------------------------------------------------------------
# 5. What does the broker do with QoS 2? We refuse it client-side by decision,
#    so record what we are choosing NOT to do rather than assuming.
# ---------------------------------------------------------------------------
q2 = Mqtt()
q2.connect("spike2-qos2")
body = bytearray(_mstr("spike2/qos2"))
body += struct.pack("!H", 1)
body += b"exactly-once"
q2.sock.sendall(bytes([PUBLISH | (2 << 1)]) + _varint(len(body)) + body)
q2.sock.settimeout(3)
pubrec = None
try:
    h, b = q2._read_packet()
    pubrec = h
except (socket.timeout, TimeoutError):
    pass
check("broker answers QoS 2 with PUBREC 0x50 (a 4-packet flow we are not doing)",
      pubrec == 0x50, f"got {hex(pubrec) if pubrec else 'nothing'}")
try:
    q2.sock.close()
except Exception:
    pass

print(f"\n  Results: {passed} passed, {failed} failed")
raise SystemExit(1 if failed else 0)
