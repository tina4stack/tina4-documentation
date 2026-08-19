# IoT and MQTT

Tina4 includes a zero-dependency MQTT 3.1.1 client for telemetry, device state,
asset tracking, and EV charging applications. It connects to an external broker
such as Mosquitto, EMQX, HiveMQ, or AWS IoT. Tina4 is not an MQTT broker.

## Configure the broker

```ini
TINA4_MQTT_URL=mqtt://127.0.0.1:1883
TINA4_MQTT_CLIENT_ID=warehouse-api
TINA4_MQTT_KEEPALIVE=60
TINA4_MQTT_TLS_VERIFY=true
TINA4_MQTT_CA_FILE=/run/secrets/mqtt-ca.pem
```

Use `mqtt://` or `tcp://` for plain TCP and `mqtts://` for TLS. Credentials
belong in URL user information or explicit constructor arguments:

```ini
TINA4_MQTT_URL=mqtts://device-user:device-password@broker.example.com:8883
```

Explicit constructor values beat URL values and environment values. Broker
credentials do not have dedicated environment variables.

## Publish telemetry

Python connects when `Mqtt()` is constructed unless `connect=False`.

```python
from tina4_python.mqtt import Mqtt

mqtt = Mqtt()
packet_id = mqtt.publish(
    "fleet/meter-42/telemetry",
    '{"kwh":12.5,"timestamp":"2026-08-18T08:00:00Z"}',
    qos=1,
)
mqtt.disconnect()
```

QoS 0 returns `None` and waits for no acknowledgement. QoS 1 returns the packet
id after the matching PUBACK. Tina4 refuses QoS 2 instead of downgrading it.
Use QoS 1 with an idempotency key such as `(device_id, device_timestamp)`.

## Subscribe and consume

```python
mqtt = Mqtt(clean_session=False)

for message in mqtt.consume("fleet/+/telemetry", qos=1):
    process(message.topic, message.text())
```

`consume()` acknowledges after the loop resumes from a successfully handled
message. If processing raises, the broker can redeliver the message. Use
`receive(ack=True)` when the application wants immediate acknowledgement, or
`receive(ack=False)` followed by `message.acknowledge()` for manual control.

`MqttMessage` exposes `topic`, byte `payload`, `qos`, `packet_id`, `retained`,
`duplicate`, `acknowledge()`, `text()`, and `to_dict()`.

## Retained state and Last Will

```python
mqtt.publish("fleet/meter-42/status", "online", qos=1, retain=True)
```

A retained publish gives new subscribers the latest device state. Publishing an
empty retained payload clears it.

Use a Last Will to report an unclean disconnect:

```python
mqtt = Mqtt(
    will_topic="fleet/meter-42/status",
    will_payload="offline",
    will_qos=1,
    will_retain=True,
)
```

`disconnect()` sends MQTT DISCONNECT and suppresses the will. `kill()` drops the
socket so the broker publishes it.

## TLS and trust

Every client builds its own TLS trust store. A CA loaded for one connection
cannot leak into another client. Verification defaults to true. Disabling it
logs a warning because encrypted traffic without peer verification remains open
to a man-in-the-middle attack.

After a TLS connection, `mqtt.tls()`, `mqtt.cipher()`, and
`mqtt.tls_version()` report the negotiated channel.

## Public operations

| Operation | Purpose |
| --- | --- |
| `connect()` / `connected()` | Open the broker connection and inspect its state. |
| `publish()` | Send QoS 0 or QoS 1 data, optionally retained. |
| `subscribe()` | Register a topic filter and return its packet id. |
| `receive()` | Read one message with immediate or manual acknowledgement. |
| `consume()` | Iterate messages and acknowledge after successful handling. |
| `acknowledge()` | Send PUBACK for a packet id. |
| `ping()` / `start_keepalive()` | Check or maintain an idle connection. |
| `disconnect()` / `kill()` | Close cleanly or simulate an unclean device loss. |

One client has one socket reader. Do not run two receive loops on the same
instance. Create another client when independent consumers need the same topic.
