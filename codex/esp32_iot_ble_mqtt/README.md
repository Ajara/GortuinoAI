# ESP32 IoT BLE MQTT

Sketch Arduino para ESP32 con:

- Provisionamiento BLE
- Sensores DS18B20
- Lectura de bateria por ADC
- Publicacion MQTT en JSON
- Control de reles por MQTT

Archivo principal:

- `esp32_iot_ble_mqtt.ino`

Dependencias habituales en Arduino IDE:

- `PubSubClient`
- `ArduinoJson`
- `OneWire`
- `DallasTemperature`

En ESP32 ya vienen normalmente:

- `WiFi`
- `Preferences`
- `BLE`

Provisionamiento BLE:

- Nombre: `ESP32_PROVISIONING`
- Formato JSON:

```json
{"ssid":"MiWiFi","password":"MiClave","mqtt":"192.168.1.100","mqtt_user":"iot-user","mqtt_password":"iot-pass"}
```

- Formato JSON con TLS:

```json
{"ssid":"MiWiFi","password":"MiClave","mqtt":"broker.midominio.com","mqtt_user":"iot-user","mqtt_password":"iot-pass","mqtt_secure":true,"mqtt_port":8883,"mqtt_ca":"-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"}
```

- Formato texto:

```txt
SSID=MiWiFi;PASS=MiClave;MQTT=192.168.1.100;MQTT_USER=iot-user;MQTT_PASS=iot-pass
```

- Formato texto con TLS:

```txt
SSID=MiWiFi;PASS=MiClave;MQTT=broker.midominio.com;MQTT_USER=iot-user;MQTT_PASS=iot-pass;MQTT_SECURE=1;MQTT_PORT=8883
```
