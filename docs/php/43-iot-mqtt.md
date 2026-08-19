# IoT and MQTT

Tina4 includes a zero-dependency MQTT 3.1.1 client for telemetry, device state,
asset tracking, and EV charging. It connects to an external broker such as
Mosquitto, EMQX, HiveMQ, or AWS IoT. Tina4 is not a broker.

## Configure and publish

```ini
TINA4_MQTT_URL=mqtt://127.0.0.1:1883
TINA4_MQTT_CLIENT_ID=warehouse-api
TINA4_MQTT_KEEPALIVE=60
TINA4_MQTT_TLS_VERIFY=true
TINA4_MQTT_CA_FILE=/run/secrets/mqtt-ca.pem
```

Use `mqtt://` or `tcp://` for plain TCP and `mqtts://` for TLS. Put credentials
in URL user information or explicit constructor arguments. Broker credentials
do not have dedicated environment variables.

```php
use Tina4\Mqtt;

$mqtt = new Mqtt();
$packetId = $mqtt->publish(
    'fleet/meter-42/telemetry',
    '{"kwh":12.5}',
    qos: 1
);
$mqtt->disconnect();
```

Construction connects by default. QoS 0 waits for no acknowledgement. QoS 1
returns the packet id after PUBACK. Tina4 refuses QoS 2 instead of silently
downgrading it.

## Consume safely

```php
$mqtt = new Mqtt(cleanSession: false);

foreach ($mqtt->consume('fleet/+/telemetry', qos: 1) as $message) {
    process($message->topic, $message->text());
}
```

`consume()` acknowledges after successful loop handling. Use
`receive(ack: false)` followed by `$message->acknowledge()` for manual control.
Messages expose topic, byte payload, QoS, packet id, retained and duplicate
flags, `acknowledge()`, `text()`, and `toArray()`.

Retained publishes store current device state; an empty retained payload clears
it. Configure `willTopic`, `willPayload`, `willQos`, and `willRetain` to report
an unclean disconnect. `disconnect()` suppresses the will; `kill()` lets the
broker publish it.

Each client builds its own TLS trust store. Verification defaults to true.
`tls()`, `cipher()`, and `tlsVersion()` report the negotiated connection. One
client has one socket reader, so independent consumers need separate clients.
