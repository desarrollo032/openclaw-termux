# OpenClaw Mobile (Flutter + Kotlin)

Aplicación móvil de OpenClaw para Android, con UI en Flutter y servicios nativos en Kotlin para gateway, terminal, SSH y capacidades del dispositivo.

## Arquitectura

- **Flutter (UI/UX y estado):** pantallas, providers y servicios Dart.
- **Canal nativo (`MethodChannel`):** puente entre Flutter y Android para operaciones de sistema.
- **Kotlin (servicios foreground):** ejecución de procesos gateway/node/terminal/ssh, lectura de sensores, batería y almacenamiento.

### Flujo de comunicación Flutter ↔ Kotlin

1. Flutter invoca métodos nativos mediante `NativeBridge`.
2. `MainActivity` enruta llamadas a `BootstrapManager`, `ProcessManager` y servicios foreground.
3. Logs del gateway regresan por `EventChannel` para visualización en UI.

## Revisión técnica realizada

Se documentó una revisión completa de:

- Rendimiento (hot paths, cache, llamadas IPC, carga en UI).
- Seguridad (permisos, almacenamiento, servicios foreground, validaciones de entrada).
- UX/UI (jerarquía visual, iconografía, accesibilidad, discoverability).
- Comunicación Kotlin/Flutter (consistencia, manejo de errores y estabilidad de servicios).

Consulta el reporte completo: **`../docs/mobile-audit-2026-05.md`**.

## Mejoras aplicadas en esta iteración

- Refresh manual de estado del gateway desde el dashboard (sin reiniciar flujo).
- Iconografía modernizada en secciones clave para mejor escaneo visual.
- Mejora de accesibilidad agregando `Semantics` al panel principal.

## Verificación local recomendada

En entorno con SDK de Flutter/Android configurado:

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew lint
```

## Notas

Este entorno no incluye Flutter SDK preinstalado, por lo que análisis y tests automáticos deben ejecutarse en CI o en una máquina con toolchain completa.
