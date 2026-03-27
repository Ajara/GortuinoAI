# IoT Service Go

Microservicio Go para backend IoT con:

- Gin Gonic
- GORM + SQLite
- Paho MQTT

## Endpoints

- `POST /setup`
- `POST /login`
- `GET /api/actual`
- `GET /api/historico`
- `POST /api/valvula/:id`

## Setup inicial

Ejemplo:

```json
{
  "username": "admin",
  "password": "supersegura",
  "mqtt_broker_ip": "192.168.1.100",
  "mqtt_port": 1883,
  "mqtt_secure": false,
  "mqtt_username": "iot-user",
  "mqtt_password": "iot-pass"
}
```

## Ejecucion

```bash
go mod tidy
go run .
```

La base SQLite se crea como `iot.db` en el directorio del servicio.

Tambien puedes fijar la ruta con la variable `DB_PATH`.

Para JWT puedes fijar `JWT_SECRET`. Si no se define, el servicio usa un valor por defecto solo apto para desarrollo.

## Docker Compose

El proyecto incluye:

- `Dockerfile` para el backend
- `docker-compose.yml` para backend + Mosquitto

Levantar el stack:

```bash
docker compose up --build
```

En Docker, la base queda persistida en la carpeta local `./data` del proyecto y se guarda como `./data/iot.db`.

## Login

Ejemplo:

```json
{
  "username": "admin",
  "password": "supersegura"
}
```

Respuesta esperada:

```json
{
  "token": "jwt-aqui"
}
```

Los endpoints bajo `/api/*` requieren:

```txt
Authorization: Bearer <token>
```

Si usas el stack con Compose, en `POST /setup` debes enviar:

```json
{
  "username": "admin",
  "password": "supersegura",
  "mqtt_broker_ip": "mqtt",
  "mqtt_port": 1883,
  "mqtt_secure": false,
  "mqtt_username": "iot-user",
  "mqtt_password": "iot-pass"
}
```

En `docker-compose.yml`, Mosquitto queda configurado con:

- usuario: `iot-user`
- password: `iot-pass`

Si cambias esos valores en el servicio `mqtt`, debes usar los mismos en `/setup` y en el provisionamiento del ESP32.

TLS opcional en Mosquitto:

- listener plano: `1883`
- listener TLS: `8883`
- activa TLS poniendo `MQTT_TLS_ENABLED=1` en `docker-compose.yml`
- coloca los certificados en:
  - [ca.crt](C:/workspace/codex/iot_service_go/deploy/mosquitto/certs/ca.crt)
  - [server.crt](C:/workspace/codex/iot_service_go/deploy/mosquitto/certs/server.crt)
  - [server.key](C:/workspace/codex/iot_service_go/deploy/mosquitto/certs/server.key)

Si activas TLS en `/setup`, puedes enviar:

```json
{
  "username": "admin",
  "password": "supersegura",
  "mqtt_broker_ip": "mqtt",
  "mqtt_port": 8883,
  "mqtt_secure": true,
  "mqtt_ca": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
  "mqtt_username": "iot-user",
  "mqtt_password": "iot-pass"
}
```

`mqtt` es el nombre del servicio dentro de la red interna de Docker.
