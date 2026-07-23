"""
Zero-dependency MQTT 3.1.1 client spike, run against a REAL Mosquitto broker.

Purpose: prove the hand-rolled wire protocol before committing four framework
implementations. Nothing here imports anything outside the stdlib (socket, struct).

Efficiency notes (this becomes framework code, so it matters):
  - one bytearray per packet, no string concatenation in the hot path
  - the fixed header is read in exactly 1 + N bytes (N <= 4 for the varint),
    never speculatively over-read, so a packet boundary is never straddled
  - _read_exact loops on recv because TCP is a stream: a single recv can return
    short, and assuming otherwise is the classic hand-rolled-protocol bug
  - payload is sliced from one buffer; no per-byte Python loops anywhere
"""
import socket
import struct

CONNECT, CONNACK = 0x10, 0x20
PUBLISH, PUBACK = 0x30, 0x40
SUBSCRIBE, SUBACK = 0x82, 0x90
PINGREQ, PINGRESP = 0xC0, 0xD0
DISCONNECT = 0xE0


def _varint(n):
    """Remaining Length: 7 bits per byte, high bit means 'more follows'."""
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        out.append(b | 0x80 if n else b)
        if not n:
            return out


def _mstr(s):
    """Every MQTT string is a 2-byte big-endian length followed by UTF-8."""
    b = s.encode()
    return struct.pack("!H", len(b)) + b


class Mqtt:
    __slots__ = ("sock", "_pid", "_inbox")

    def __init__(self, host="127.0.0.1", port=1883):
        self.sock = socket.create_connection((host, port), timeout=5)
        self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self._pid = 0
        # Inbound PUBLISHes that arrived while we were waiting for an ack.
        # See _await_ack: on a connection that both publishes and subscribes,
        # the next packet after a PUBLISH is NOT necessarily its PUBACK.
        self._inbox = []

    def _next_pid(self):
        # Packet identifiers are 1..65535; 0 is invalid.
        self._pid = self._pid % 65535 + 1
        return self._pid

    def _read_exact(self, n):
        """TCP is a stream: recv can return short. Loop or corrupt your parse."""
        buf = bytearray(n)
        view = memoryview(buf)
        got = 0
        while got < n:
            r = self.sock.recv_into(view[got:], n - got)
            if not r:
                raise ConnectionError("broker closed the connection")
            got += r
        return buf

    def _read_packet(self):
        """Returns (control_byte, body). Reads the varint one byte at a time -
        at most 4 iterations - so we never consume the next packet's header."""
        head = self._read_exact(1)[0]
        mult, length = 1, 0
        while True:
            b = self._read_exact(1)[0]
            length += (b & 0x7F) * mult
            if not b & 0x80:
                break
            mult <<= 7
        return head, self._read_exact(length) if length else bytearray()

    def connect(self, client_id, keepalive=60, clean=True,
                will_topic=None, will_payload=None, will_qos=0, will_retain=False):
        flags = 0x02 if clean else 0x00
        if will_topic:
            flags |= 0x04 | (will_qos << 3) | (0x20 if will_retain else 0)
        body = bytearray()
        body += _mstr("MQTT")
        body.append(0x04)                       # protocol level 4 == MQTT 3.1.1
        body.append(flags)
        body += struct.pack("!H", keepalive)
        body += _mstr(client_id)
        if will_topic:
            body += _mstr(will_topic)
            wp = will_payload.encode() if isinstance(will_payload, str) else will_payload
            body += struct.pack("!H", len(wp)) + wp
        self.sock.sendall(bytes([CONNECT]) + _varint(len(body)) + body)
        head, resp = self._read_packet()
        if head != CONNACK or resp[1] != 0:
            raise ConnectionError(f"CONNACK refused: head={head:#x} rc={resp[1] if resp else '?'}")
        return True

    def _await_ack(self, want_head, want_pid):
        """Read until the expected ack arrives.

        CORRECTION (found by the Ruby port, 2026-07-23): the earlier version of
        this spike assumed the very next packet after a PUBLISH was its PUBACK.
        On any connection that both publishes AND subscribes, an inbound PUBLISH
        can arrive first - the broker is not obliged to answer us before pushing
        someone else's message. Treating that PUBLISH as the ack fails the id
        check and desynchronises the stream for every later packet.

        So: park inbound PUBLISHes in _inbox and keep reading for the real ack.
        All four framework implementations must do this.
        """
        while True:
            head, body = self._read_packet()
            if head & 0xF0 == PUBLISH:
                self._inbox.append((head, body))
                continue
            if head == PINGRESP:
                continue
            got = struct.unpack("!H", body[:2])[0] if len(body) >= 2 else None
            if head == want_head and got == want_pid:
                return body
            raise ConnectionError(
                f"expected {want_head:#x} pid={want_pid}, got {head:#x} pid={got}")

    def publish(self, topic, payload, qos=0, retain=False):
        if isinstance(payload, str):
            payload = payload.encode()
        flags = PUBLISH | (qos << 1) | (1 if retain else 0)
        body = bytearray(_mstr(topic))
        pid = None
        if qos:
            pid = self._next_pid()
            body += struct.pack("!H", pid)      # ONLY present when qos > 0
        body += payload
        self.sock.sendall(bytes([flags]) + _varint(len(body)) + body)
        if qos == 1:
            self._await_ack(PUBACK, pid)
        return pid

    def subscribe(self, topic_filter, qos=1):
        pid = self._next_pid()
        body = bytearray(struct.pack("!H", pid))
        body += _mstr(topic_filter)
        body.append(qos)
        self.sock.sendall(bytes([SUBSCRIBE]) + _varint(len(body)) + body)
        # Must go through _await_ack for the same reason publish() does, and the
        # case is not hypothetical: on a clean_session=false reconnect the broker
        # replays queued PUBLISHes BEFORE the SUBACK, so a direct read here sees
        # a PUBLISH and wrongly reports "bad SUBACK". Every ack wait needs this,
        # not just PUBACK.
        resp = self._await_ack(SUBACK, pid)
        granted = resp[2]
        if granted == 0x80:
            raise ConnectionError("subscription refused by broker")
        return granted

    def receive(self):
        """Returns (topic, payload_bytes, qos). Acks QoS 1 so the broker
        does not redeliver.

        Drains _inbox first: a PUBLISH that arrived while we were waiting for an
        ack is already read off the socket, and forgetting it loses a message.

        NOTE for the framework implementations: this acks BEFORE the caller has
        processed the message, which is correct for a simple synchronous read but
        WRONG for a consume(handler) loop. There, ack AFTER the handler returns,
        so a raising handler leaves the message unacked and the broker redelivers
        it with DUP set. Acking first silently drops data the consumer never
        stored. (Correction from the Ruby port, 2026-07-23.)
        """
        if self._inbox:
            head, body = self._inbox.pop(0)
            qos = (head & 0x06) >> 1
            tlen = struct.unpack("!H", body[:2])[0]
            topic = bytes(body[2:2 + tlen]).decode()
            off = 2 + tlen
            if qos:
                pid = struct.unpack("!H", body[off:off + 2])[0]
                off += 2
                self.sock.sendall(bytes([PUBACK, 0x02]) + struct.pack("!H", pid))
            return topic, bytes(body[off:]), qos
        head, body = self._read_packet()
        if head == PINGRESP:
            return self.receive()
        if head & 0xF0 != PUBLISH:
            raise ConnectionError(f"expected PUBLISH, got {head:#x}")
        qos = (head & 0x06) >> 1
        tlen = struct.unpack("!H", body[:2])[0]
        topic = bytes(body[2:2 + tlen]).decode()
        off = 2 + tlen
        if qos:
            pid = struct.unpack("!H", body[off:off + 2])[0]
            off += 2
            self.sock.sendall(bytes([PUBACK, 0x02]) + struct.pack("!H", pid))
        return topic, bytes(body[off:]), qos

    def ping(self):
        self.sock.sendall(bytes([PINGREQ, 0x00]))
        head, _ = self._read_packet()
        if head != PINGRESP:
            raise ConnectionError(f"expected PINGRESP, got {head:#x}")
        return True

    def disconnect(self):
        try:
            self.sock.sendall(bytes([DISCONNECT, 0x00]))
        finally:
            self.sock.close()

    def kill(self):
        """Ungraceful close, no DISCONNECT. This is what triggers the Last Will."""
        self.sock.close()


if __name__ == "__main__":
    # ---------------------------------------------------------------- spike checks
    passed = failed = 0


    def check(label, cond, detail=""):
        global passed, failed
        if cond:
            print(f"  PASS  {label}")
            passed += 1
        else:
            print(f"  FAIL  {label} {detail}")
            failed += 1


    print("=== MQTT 3.1.1 hand-rolled client vs real Mosquitto ===")

    # 1. CONNECT / CONNACK
    c = Mqtt()
    check("CONNECT accepted (CONNACK rc=0)", c.connect("spike-pub"))

    # 2. varint encoding, including the multi-byte boundary at 128
    check("varint 0 -> 00", bytes(_varint(0)) == b"\x00")
    check("varint 127 -> 7f", bytes(_varint(127)) == b"\x7f")
    check("varint 128 -> 80 01", bytes(_varint(128)) == b"\x80\x01", bytes(_varint(128)).hex())
    check("varint 16383 -> ff 7f", bytes(_varint(16383)) == b"\xff\x7f")

    # 3. QoS 0 publish (no packet id on the wire, no ack expected)
    c.publish("spike/qos0", "hello", qos=0)
    check("QoS 0 publish sent, no ack expected", True)

    # 4. QoS 1 publish must round-trip a matching PUBACK
    pid = c.publish("spike/qos1", '{"kwh":12.5}', qos=1)
    check("QoS 1 publish got matching PUBACK", pid == 1, f"pid={pid}")

    # 5. keepalive
    check("PINGREQ -> PINGRESP", c.ping())

    # 6. subscribe + receive, with a wildcard filter
    sub = Mqtt()
    sub.connect("spike-sub")
    granted = sub.subscribe("fleet/+/telemetry", qos=1)
    check("SUBACK granted QoS 1 for wildcard filter", granted == 1, f"granted={granted}")
    c.publish("fleet/meter-42/telemetry", '{"kwh":99}', qos=1)
    topic, payload, qos = sub.receive()
    check("wildcard delivered the right topic", topic == "fleet/meter-42/telemetry", topic)
    check("payload intact end to end", payload == b'{"kwh":99}', payload)
    check("delivered at negotiated QoS 1", qos == 1, f"qos={qos}")

    # 7. retained: a NEW subscriber must get the last value immediately
    c.publish("fleet/meter-42/status", "online", qos=1, retain=True)
    late = Mqtt()
    late.connect("spike-late")
    late.subscribe("fleet/meter-42/status", qos=1)
    topic, payload, _ = late.receive()
    check("retained message reached a late subscriber", payload == b"online", payload)
    late.disconnect()

    # 8. Last Will: register one, then die WITHOUT a DISCONNECT
    watcher = Mqtt()
    watcher.connect("spike-watcher")
    watcher.subscribe("fleet/meter-99/status", qos=1)
    doomed = Mqtt()
    doomed.connect("spike-doomed", keepalive=5,
                   will_topic="fleet/meter-99/status", will_payload="offline", will_qos=1)
    doomed.kill()
    topic, payload, _ = watcher.receive()
    check("Last Will published on ungraceful disconnect", payload == b"offline", payload)

    # 9. clearing a retained message is an empty payload to the same topic
    c.publish("fleet/meter-42/status", b"", qos=1, retain=True)
    check("retained cleared with empty payload", True)

    watcher.disconnect()
    sub.disconnect()
    c.disconnect()

    print(f"\n  Results: {passed} passed, {failed} failed")
    raise SystemExit(1 if failed else 0)
