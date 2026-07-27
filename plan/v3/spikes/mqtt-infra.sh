#!/bin/sh
# Stand up every broker the MQTT tests need. Reproducible for CI and for the
# four framework implementations. Idempotent: safe to re-run.
#
#   1883  Mosquitto, anonymous            -> protocol + session tests
#   1884  Mosquitto, auth required        -> username/password tests
#   8883  Mosquitto, TLS (self-signed CA) -> mqtts:// tests
#   1885  EMQX 5.8                        -> SUBACK 0x80 (Mosquitto never returns it)
#
# Usage:  sh mqtt-infra.sh [dir]     (default: ./mqtt-infra)
set -e
DIR="${1:-./mqtt-infra}"
mkdir -p "$DIR/certs" "$DIR/conf"
cd "$DIR"

# ---------------------------------------------------------------- TLS material
# The CA needs basicConstraints + keyUsage or modern OpenSSL refuses to trust it
# as a CA ("CA cert does not include key usage extension"). Learned the hard way.
if [ ! -f certs/ca.crt ]; then
  cat > certs/ca.cnf <<'EOF'
[req]
distinguished_name=dn
x509_extensions=v3_ca
prompt=no
[dn]
CN=tina4-test-ca
[v3_ca]
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
EOF
  openssl req -x509 -newkey rsa:2048 -nodes -keyout certs/ca.key \
    -out certs/ca.crt -days 365 -config certs/ca.cnf >/dev/null 2>&1
  openssl req -newkey rsa:2048 -nodes -keyout certs/server.key \
    -out certs/server.csr -subj "/CN=localhost" >/dev/null 2>&1
  cat > certs/srv.ext <<'EOF'
basicConstraints=CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:localhost,IP:127.0.0.1
EOF
  openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key \
    -CAcreateserial -out certs/server.crt -days 365 \
    -extfile certs/srv.ext >/dev/null 2>&1
  chmod 644 certs/*.key certs/*.crt
  echo "certs generated"
fi

# ---------------------------------------------------------------- mosquitto
# per_listener_settings is REQUIRED. Without it allow_anonymous and password_file
# are GLOBAL and the last listener wins, so the auth listener silently accepts
# anonymous clients and your auth test passes for the wrong reason.
cat > conf/mosquitto.conf <<'EOF'
per_listener_settings true

listener 1883 0.0.0.0
allow_anonymous true

listener 1884 0.0.0.0
allow_anonymous false
password_file /mosquitto/config/passwd

listener 8883 0.0.0.0
allow_anonymous true
cafile /mosquitto/certs/ca.crt
certfile /mosquitto/certs/server.crt
keyfile /mosquitto/certs/server.key
EOF

if ! grep -q '\$' conf/passwd 2>/dev/null; then
  printf 'tina4:testpass\n' > conf/passwd
  docker run --rm -v "$PWD/conf:/mosquitto/config" eclipse-mosquitto:2 \
    mosquitto_passwd -U /mosquitto/config/passwd >/dev/null 2>&1
  echo "password file hashed"
fi

docker rm -f tina4-mosquitto >/dev/null 2>&1 || true
docker run -d --name tina4-mosquitto \
  -p 1883:1883 -p 1884:1884 -p 8883:8883 \
  -v "$PWD/conf/mosquitto.conf:/mosquitto/config/mosquitto.conf" \
  -v "$PWD/conf/passwd:/mosquitto/config/passwd" \
  -v "$PWD/certs:/mosquitto/certs" \
  eclipse-mosquitto:2 >/dev/null

# ---------------------------------------------------------------- emqx
# NOTE: there is no emqx/emqx:5 tag. Use 5.8. EMQX's DEFAULT authorization
# already denies subscribing to "#" and "$SYS/#", which is how we elicit a real
# SUBACK 0x80 with no custom ACL - Mosquitto enforces at delivery instead and
# hands the client a granted QoS, so it can never produce 0x80.
docker rm -f tina4-emqx >/dev/null 2>&1 || true
docker run -d --name tina4-emqx -p 1885:1883 emqx/emqx:5.8 >/dev/null

printf 'waiting for brokers'
for p in 1883 1884 8883 1885; do
  i=0
  while [ $i -lt 40 ]; do
    nc -z 127.0.0.1 $p 2>/dev/null && break
    printf '.'; sleep 2; i=$((i+1))
  done
done
echo ""
for p in 1883 1884 8883 1885; do
  if nc -z 127.0.0.1 $p 2>/dev/null; then echo "  $p UP"; else echo "  $p DOWN"; fi
done
echo ""
echo "export TINA4_MQTT_TEST_CA=$PWD/certs/ca.crt"
