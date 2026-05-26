# 📱 OpenClaw Mobile

**Aplicación móvil de OpenClaw para Android** — UI en Flutter con servicios nativos en Kotlin para gateway, terminal, SSH y capacidades del dispositivo.

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────┐
│           Flutter (UI/UX)               │
│  Screens · Providers · Servicios Dart   │
├─────────────────────────────────────────┤
│        MethodChannel (Puente Nativo)    │
├─────────────────────────────────────────┤
│      Kotlin (Servicios Foreground)      │
│  Gateway · Node · Terminal · SSH        │
│  Sensores · Batería · Almacenamiento    │
└─────────────────────────────────────────┘
```

### 🔄 Flujo de Comunicación

1. **Flutter** invoca métodos nativos mediante `NativeBridge`
2. **MainActivity** enruta llamadas a `BootstrapManager`, `ProcessManager` y servicios foreground
3. Los logs del gateway regresan por `EventChannel` para visualización en tiempo real

---

## 🧩 Componentes Principales

### Design System (`lib/design/`)

| Archivo | Propósito |
|---------|-----------|
| `tokens.dart` | Tokens de diseño: espaciado, radios, colores, temas (`buildOpenClawTheme()`) |
| `components.dart` | 11 componentes reutilizables: `StatusBadge`, `PressableCard`, `SectionHeader`, `SettingsCard`, `InfoRow`, etc. |

### Pantallas (`lib/screens/`)

| Pantalla | Descripción |
|----------|-------------|
| **Splash** | Carga inicial con verificación de bootstrap |
| **Dashboard** | Panel principal con estado del gateway, herramientas y configuración |
| **Setup Wizard** | Asistente de instalación paso a paso |
| **Terminal** | Emulador de terminal completo con PTY |
| **Onboarding** | Configuración de API keys de proveedores IA |
| **Settings** | Configuración general de la app |
| **SSH** | Control del servidor SSH remoto |
| **Logs** | Visor de logs del gateway en tiempo real |
| **Providers** | Gestión de proveedores de IA |
| **Packages** | Instalación de paquetes opcionales |
| **Node** | Estado y control del nodo conectado |
| **Web Dashboard** | WebView del panel web del gateway |

### Widgets (`lib/widgets/`)

- `terminal_view_module.dart` — Componente reutilizable de terminal con PTY
- `terminal_toolbar.dart` — Barra de herramientas del terminal
- `node_controls.dart` — Controles del nodo conectado
- `live_console_widget.dart` — Consola en vivo para logs de instalación

---

## 📋 Auditoría Técnica

Se realizó una revisión completa del proyecto documentada en [`docs/mobile-audit-2026-05.md`](../docs/mobile-audit-2026-05.md):

- **Rendimiento** — Hot paths, caché, llamadas IPC, carga en UI
- **Seguridad** — Permisos, almacenamiento, servicios foreground, validaciones
- **UI/UX** — Jerarquía visual, iconografía, accesibilidad
- **Comunicación nativa** — Consistencia del bridge, manejo de errores

### Mejoras Aplicadas

- ✅ Dashboard con animaciones staggered (`flutter_animate`)
- ✅ Sistema de diseño unificado con tokens y componentes
- ✅ Tema Material You con `buildOpenClawTheme(isDark:)`
- ✅ Componentes reutilizables (`StatusBadge`, `PressableCard`, etc.)
- ✅ Terminal unificada vía `TerminalViewModule`
- ✅ SHA256 verification para descargas de rootfs
- ✅ Optimización `epoll` en el PTY nativo (C++)

---

## 🔧 Desarrollo Local

### Requisitos

| Herramienta   | Versión       |
| ------------- | ------------- |
| Flutter       | 3.24.x stable |
| Dart          | >= 3.2.0      |
| Android SDK   | API 29+       |
| Java          | 17 (Temurin)  |

### Comandos

```bash
cd flutter_app

# Obtener dependencias
flutter pub get

# Análisis estático
flutter analyze

# Ejecutar en dispositivo
flutter run

# Build de release
flutter build apk --release

# Tests
flutter test
```

---

## 📄 Licencia

OpenClaw Mobile es parte del ecosistema [OpenClaw](https://github.com/anthropics/openclaw) y se distribuye bajo licencia MIT.

---

<div align="center">

[🌐 OpenClaw Gateway](https://github.com/anthropics/openclaw) · [🐛 Reportar Bug](https://github.com/desarrollo032/openclaw-termux/issues) · [⭐ GitHub](https://github.com/desarrollo032/openclaw-termux)

</div>
