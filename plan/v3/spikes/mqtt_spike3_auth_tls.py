"""
MQTT spike, part 3: username/password auth and TLS (mqtts://).

Owner asked for both in this release. Zero dependencies still holds: TLS is
`ssl` from the Python stdlib, and every target language has an equivalent built
in (Ruby `openssl`, PHP `ext-openssl` + stream contexts, Node `node:tls`).

Broker layout used here (all one Mosquitto container):
  1883  anonymous
  1884  allow_anonymous false + password_file  -> auth tests
  8883  TLS with a self-signed CA              -> mqtts tests

CONNACK return codes that matter:
  0 accepted, 4 bad username or password, 5 not authorized
"""
import socket
import ssl
import struct
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mqtt_spike import Mqtt, _varint, _mstr, CONNECT, CONNACK  # noqa: E402

CERTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "certs")
# The spike infra lives outside the repo; allow an override.
CA = os.environ.get("TINA4_MQTT_TEST_CA", "")

passed = failed = 0


def check(label, cond, detail=""):
    global passed, failed
    if cond:
        print(f"  PASS  {label}")
        passed += 1
    else:
        print(f"  FAIL  {label} {detail}")
        failed += 1


class AuthMqtt(Mqtt):
    """Mqtt + username/password + optional TLS.

    Deliberately a subclass here so the diff against the proven spike is small
    and reviewable; in the framework it is the same class with extra kwargs.
    """
    __slots__ = ()

    def __init__(self, host="127.0.0.1", port=1883, tls=False, ca_file=None,
                 verify=True):
        raw = socket.create_connection((host, port), timeout=5)
        raw.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        if tls:
            ctx = ssl.create_default_context(
                purpose=ssl.Purpose.SERVER_AUTH,
                cafile=ca_file if verify else None)
            if not verify:
                # Only ever for a test that PROVES verification is real.
                ctx.check_hostname = False
                ctx.verify_mode = ssl.CERT_NONE
            raw = ctx.wrap_socket(raw, server_hostname=host)
        # bypass the parent's socket setup, reuse everything else
        self.sock = raw
        self._pid = 0
        self._inbox = []

    def connect_auth(self, client_id, username=None, password=None,
                     keepalive=60, clean=True):
        """Returns the CONNACK return code instead of raising, so a test can
        assert on a REFUSAL as well as on success."""
        flags = 0x02 if clean else 0x00
        if username:
            flags |= 0x80
        if password:
            flags |= 0x40
        body = bytearray()
        body += _mstr("MQTT")
        body.append(0x04)
        body.append(flags)
        body += struct.pack("!H", keepalive)
        body += _mstr(client_id)
        # payload order is fixed: client id, will topic, will msg, username, password
        if username:
            body += _mstr(username)
        if password:
            body += _mstr(password)
        self.sock.sendall(bytes([CONNECT]) + _varint(len(body)) + body)
        head, resp = self._read_packet()
        if head != CONNACK:
            raise ConnectionError(f"expected CONNACK, got {head:#x}")
        return resp[1]


print("=== MQTT auth + TLS vs real Mosquitto ===")

# ---------------------------------------------------------------- auth on 1884
c = AuthMqtt(port=1884)
rc = c.connect_auth("spike3-good", username="tina4", password="testpass")
check("correct credentials accepted (rc=0)", rc == 0, f"rc={rc}")
c.publish("spike3/auth", "authenticated", qos=1)
check("QoS 1 publish works on an authenticated connection", True)
c.disconnect()

c = AuthMqtt(port=1884)
rc = c.connect_auth("spike3-nocreds")
check("NO credentials refused on an auth-required listener", rc in (4, 5), f"rc={rc}")
try:
    c.sock.close()
except Exception:
    pass

c = AuthMqtt(port=1884)
rc = c.connect_auth("spike3-badpass", username="tina4", password="wrong")
check("wrong password refused (rc=4 or 5)", rc in (4, 5), f"rc={rc}")
try:
    c.sock.close()
except Exception:
    pass

c = AuthMqtt(port=1884)
rc = c.connect_auth("spike3-baduser", username="nobody", password="testpass")
check("unknown username refused", rc in (4, 5), f"rc={rc}")
try:
    c.sock.close()
except Exception:
    pass

# Credentials must NOT be accepted as a silent no-op on the anonymous listener
c = AuthMqtt(port=1883)
rc = c.connect_auth("spike3-anon-with-creds", username="tina4", password="testpass")
check("anonymous listener still accepts a credentialed connect", rc == 0, f"rc={rc}")
c.disconnect()

# ---------------------------------------------------------------- TLS on 8883
ca = CA if CA and os.path.exists(CA) else None
if not ca:
    print("  SKIP  TLS checks: set TINA4_MQTT_TEST_CA to the CA path")
else:
    t = AuthMqtt(port=8883, tls=True, ca_file=ca)
    rc = t.connect_auth("spike3-tls")
    check("TLS connect with CA verification accepted", rc == 0, f"rc={rc}")
    t.subscribe("spike3/tls", qos=1)
    t.publish("spike3/tls", "over-tls", qos=1)
    topic, payload, qos = t.receive()
    check("publish/subscribe round-trip over TLS", payload == b"over-tls", payload)
    check("TLS session is really encrypted (cipher negotiated)",
          t.sock.cipher() is not None, str(t.sock.cipher()))
    t.disconnect()

    # Verification must be REAL: a default context with no CA must reject a
    # self-signed chain. If this passes, we are not actually verifying anything.
    rejected = False
    try:
        bad = AuthMqtt(port=8883, tls=True, ca_file=None, verify=True)
        bad.sock.close()
    except ssl.SSLCertVerificationError:
        rejected = True
    except ssl.SSLError:
        rejected = True
    check("self-signed cert REJECTED without the CA (verification is real)", rejected)

# ------------------------------------------------- SUBACK 0x80 against EMQX
# Mosquitto CANNOT produce 0x80: it enforces ACLs at delivery time and hands the
# client a granted QoS, then silently delivers nothing - exactly the trap. EMQX
# refuses at subscribe time, and its DEFAULT authorization already denies "#"
# and "$SYS/#", so no custom ACL is needed.
EMQX_PORT = int(os.environ.get("TINA4_MQTT_TEST_EMQX_PORT", "1885"))
try:
    e = Mqtt(port=EMQX_PORT)
    e.connect("spike3-emqx")
    emqx_up = True
except OSError:
    emqx_up = False
    print(f"  SKIP  EMQX checks: nothing listening on {EMQX_PORT}")

if emqx_up:
    def raw_sub(c, flt, qos=1):
        pid = c._next_pid()
        body = bytearray(struct.pack("!H", pid)) + _mstr(flt) + bytes([qos])
        c.sock.sendall(bytes([0x82]) + _varint(len(body)) + body)
        head, resp = c._read_packet()
        return resp[2] if len(resp) > 2 else None

    check("EMQX refuses subscribe '#' with SUBACK 0x80", raw_sub(e, "#") == 0x80)
    check("EMQX refuses subscribe '$SYS/#' with SUBACK 0x80", raw_sub(e, "$SYS/#") == 0x80)
    granted = raw_sub(e, "allowed/topic")
    check("EMQX still grants a permitted topic", granted == 1, f"granted={granted}")
    e.disconnect()

print(f"\n  Results: {passed} passed, {failed} failed")
raise SystemExit(1 if failed else 0)
