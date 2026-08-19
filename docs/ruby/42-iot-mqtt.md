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
in URL user information or constructor arguments. There are no username or
password environment variables.

```ruby
mqtt = Tina4::Mqtt.new
packet_id = mqtt.publish(
  "fleet/meter-42/telemetry",
  '{"kwh":12.5}',
  qos: 1
)
mqtt.disconnect
```

Construction connects by default. QoS 0 waits for no acknowledgement. QoS 1
returns the packet id after PUBACK. Tina4 refuses QoS 2.

```ruby
mqtt = Tina4::Mqtt.new(clean_session: false)
mqtt.consume("fleet/+/telemetry", qos: 1) do |message|
  process(message.topic, message.to_s)
end
```

`consume` acknowledges after successful block handling. Use
`receive(ack: false)` followed by `message.acknowledge` for manual control.
Messages expose topic, byte payload, QoS, packet id, retained and duplicate
flags, acknowledgement, text through `to_s`, and `to_h`.

Retained publishes store current state; an empty retained payload clears it.
Configure `will_topic`, `will_payload`, `will_qos`, and `will_retain` for an
unclean disconnect. `disconnect` suppresses the will; `kill` lets the broker
publish it. TLS verification defaults to true. `tls?`, `cipher`, and
`tls_version` report the connection. One client has one socket reader.
