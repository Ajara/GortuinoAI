## Subproyecto Flutter

Este directorio está pensado para contener la app móvil/web de **Tamavans** escrita en Flutter.

### Crear el proyecto Flutter

1. Abre una terminal en la carpeta raíz del proyecto:

   ```bash
   cd c:\workspace\proyecto_tamavans
   ```

2. Crea el proyecto dentro de la carpeta `flutter` (puedes cambiar el nombre `tamavans_app` si quieres):

   ```bash
   cd flutter
   flutter create tamavans_app
   ```

3. Abre la carpeta `flutter/tamavans_app` en tu IDE (VS Code, Android Studio, etc.).

### Integración con el backend Go

- Asegúrate de tener corriendo los contenedores:

  ```bash
  docker-compose up -d
  ```

- El backend Go expone HTTP en `http://localhost:8080`.
- Desde Flutter podrás:
  - Consumir la API REST (por ejemplo `/health`, `/publish`).
  - Más adelante, añadir soporte MQTT usando paquetes como `mqtt_client`.

### Próximos pasos sugeridos

- Crear pantallas básicas en Flutter para:
  - Ver estado (`/health`).
  - Enviar mensajes MQTT a través del endpoint `/publish` del backend.

