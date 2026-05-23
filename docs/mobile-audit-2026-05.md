# OpenClaw Mobile Audit — 2026-05-23

## Alcance

- Revisión de app Flutter + Android Kotlin.
- Revisión de velocidad, seguridad, UI/UX y puente nativo.
- Propuesta de optimizaciones sin romper funcionalidades.

## Hallazgos de rendimiento

1. **Canal nativo parcialmente optimizado**
   - `NativeBridge` ya cachea rutas y arquitectura para reducir IPC repetitivo.
   - Recomendación: extender cache para estados de servicios con TTL corto (1-2s) cuando la UI consulta con alta frecuencia.

2. **Servicios en background bien desacoplados**
   - `MainActivity` ejecuta tareas pesadas con `ExecutorService`.
   - Recomendación: migrar lecturas puntuales (ej. sensor one-shot) a `HandlerThread`/coroutines para timeout no bloqueante.

3. **Dashboard optimizado para lectura secuencial**
   - Mejoras de iconografía y semántica para acelerar navegación visual.

## Hallazgos de seguridad

1. **Permisos sensibles**
   - Uso de `MANAGE_EXTERNAL_STORAGE` en Android 11+ es potente y debe justificarse por caso de uso.
   - Recomendación: fallback a SAF/document picker para reducir superficie de riesgo en futuras versiones.

2. **Operaciones privilegiadas en proot**
   - Se realiza escape de comillas al configurar password root; buena práctica mínima.
   - Recomendación: reforzar validación de inputs desde Flutter (longitud mínima, bloqueo de caracteres de control).

3. **Servicios foreground**
   - Correcto para supervivencia en background.
   - Recomendación: auditar periódicamente canales de notificación y textos para evitar fuga de datos sensibles.

## Comunicación Kotlin ↔ Flutter

### Estado actual

- `MethodChannel` centralizado en `MainActivity`.
- `EventChannel` para logs del gateway.
- `NativeBridge` homogéneo para invocaciones desde Flutter.

### Recomendaciones

- Definir contrato de errores tipados (códigos fijos) compartido en Dart/Kotlin para mejor DX.
- Introducir versionado del bridge (ej. `bridgeVersion`) para migraciones seguras.
- Añadir pruebas de integración de canal con mocks (Flutter integration tests + instrumented tests Android).

## UI/UX

### Mejoras aplicadas

- Iconos modernizados por dominio funcional (tools/config/system).
- Acción rápida de refresh para estado de gateway.
- Etiqueta semántica del panel principal para accesibilidad.

### Próximas mejoras sugeridas

- Skeleton loading en cards al abrir app.
- Modo compacto para pantallas pequeñas.
- Atajos contextuales (long-press) en cards de terminal/SSH/dashboard.

## Errores encontrados

- No se pudieron ejecutar `flutter analyze` y `flutter test` en este entorno por falta del binario `flutter`.
- No se detectaron excepciones nuevas introducidas en los cambios aplicados.

## Plan recomendado (prioridad)

1. **P0:** pipeline CI con `flutter analyze`, `flutter test` y `./gradlew lint`.
2. **P1:** endurecer validación de inputs en bridge y reducir permisos de almacenamiento.
3. **P1:** pruebas de integración Flutter-Kotlin para métodos críticos (gateway/node/ssh).
4. **P2:** mejoras UX avanzadas (skeletons, compact mode, shortcuts).
