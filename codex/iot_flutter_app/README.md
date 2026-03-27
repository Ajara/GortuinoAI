# IoT Flutter App

App Flutter para Android/iOS con:

- Modo oscuro
- Provider para estado global
- `flutter_secure_storage` para JWT
- `shared_preferences` para IP del servidor
- `fl_chart` para histórico de temperaturas

## Estructura

- `lib/models`
- `lib/providers`
- `lib/screens`
- `lib/services`
- `lib/widgets`

## Backend esperado

- `POST /setup`
- `POST /login`
- `GET /api/actual`
- `GET /api/historico`
- `POST /api/valvula/:id`
