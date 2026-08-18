# IoT and MQTT

Tina4 includes a zero-dependency MQTT 3.1.1 client for telemetry, device state,
asset tracking, and EV charging. It connects to an external broker such as
Mosquitto, EMQX, HiveMQ, or AWS IoT. Tina4 is not a broker.

## Configure, connect, and publish

```ini
TINA4_MQTT_URL=mqtt://127.0.0.1:1883
TINA4_MQTT_CLIENT_ID=warehouse-api
TINA4_MQTT_KEEPALIVE=60
TINA4_MQTT_TLS_VERIFY=true
TINA4_MQTT_CA_FILE=/run/secrets/mqtt-ca.pem
```

Use `mqtt://` or `tcp://` for plain TCP and `mqtts://` for TLS. Put credentials
in URL user information or constructor options. There are no username or
password environment variables.

```typescript
import { Mqtt } from "tina4-nodejs";

const mqtt = new Mqtt();
await mqtt.connect();
const packetId = await mqtt.publish(
  "fleet/meter-42/telemetry",
  JSON.stringify({ kwh: 12.5 }),
  1,
);
await mqtt.disconnect();
```

Node.js connects explicitly. QoS 0 waits for no acknowledgement. QoS 1 returns
the packet id after PUBACK. Tina4 refuses QoS 2.

```typescript
const mqtt = new Mqtt({ cleanSession: false });
await mqtt.connect();

for await (const message of mqtt.consume("fleet/+/telemetry", 1)) {
  process(message.topic, message.text());
}
```

`consume()` acknowledges after successful loop handling. Use
`receive(undefined, false)` followed by `message.acknowledge()` for manual
control. Messages expose topic, byte payload, QoS, packet id, retained and
duplicate flags, acknowledgement, `text()`, and `toObject()`.

Retained publishes store current state; an empty retained payload clears it.
Configure `willTopic`, `willPayload`, `willQos`, and `willRetain` for an unclean
disconnect. `disconnect()` suppresses the will; `kill()` lets the broker publish
it. TLS verification defaults to true. `tls()`, `cipher()`, and `tlsVersion()`
report the connection. One client has one socket reader.
