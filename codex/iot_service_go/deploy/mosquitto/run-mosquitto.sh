#!/bin/sh
set -eu

CONFIG_OUT="/tmp/mosquitto.generated.conf"

mkdir -p /mosquitto/password

if [ ! -f /mosquitto/password/passwd ]; then
  mosquitto_passwd -b -c /mosquitto/password/passwd "${MQTT_USERNAME}" "${MQTT_PASSWORD}"
fi

chown mosquitto:mosquitto /mosquitto/password/passwd
chmod 640 /mosquitto/password/passwd

cat > "${CONFIG_OUT}" <<EOF
listener 1883
allow_anonymous false
password_file /mosquitto/password/passwd

persistence true
persistence_location /mosquitto/data/

log_dest stdout
EOF

if [ "${MQTT_TLS_ENABLED:-0}" = "1" ] && \
   [ -f /mosquitto/certs/ca.crt ] && \
   [ -f /mosquitto/certs/server.crt ] && \
   [ -f /mosquitto/certs/server.key ]; then
  cat >> "${CONFIG_OUT}" <<EOF

listener 8883
allow_anonymous false
password_file /mosquitto/password/passwd
cafile /mosquitto/certs/ca.crt
certfile /mosquitto/certs/server.crt
keyfile /mosquitto/certs/server.key
require_certificate false
tls_version tlsv1.2
EOF
fi

exec mosquitto -c "${CONFIG_OUT}"
