<div align="center">

# ⚡ OpenClaw

**AI Gateway para Android** — Aplicación Flutter autónoma con terminal integrada, panel web y configuración de un toque.

[![Descargar APK](https://img.shields.io/badge/Descargar-APK-green?style=for-the-badge&logo=android)](https://github.com/desarrollo032/openclaw-termux/releases/latest)
[![Build](https://github.com/desarrollo032/openclaw-termux/actions/workflows/flutter-build.yml/badge.svg)](https://github.com/desarrollo032/openclaw-termux/actions/workflows/flutter-build.yml)
[![npm](https://img.shields.io/npm/v/openclaw-termux?color=blue&label=npm)](https://www.npmjs.com/package/openclaw-termux)
[![Versión](https://img.shields.io/badge/versión-1.9.0--beta.1-blue?style=flat-square)](https://github.com/desarrollo032/openclaw-termux/releases)
[![Licencia: MIT](https://img.shields.io/badge/Licencia-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-22-green?logo=node.js)](https://nodejs.org/)
[![Android](https://img.shields.io/badge/Android-10%2B-brightgreen?logo=android)](https://www.android.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.24-02569B?logo=flutter)](https://flutter.dev/)
[![PRs Bienvenidas](https://img.shields.io/badge/PRs-bienvenidas-brightgreen.svg)](https://github.com/desarrollo032/openclaw-termux/pulls)

<img src="assets/ic_launcher.png" alt="OpenClaw" width="100"/>

---

</div>

## 📋 Tabla de Contenidos

- [¿Qué es OpenClaw?](#-qué-es-openclaw)
- [Capturas de Pantalla](#-capturas-de-pantalla)
- [Características](#-características)
- [Inicio Rápido](#-inicio-rápido)
- [Requisitos](#-requisitos)
- [Advertencias](#-advertencias)
- [Uso de CLI](#-uso-de-cli)
- [Paquetes Opcionales](#-paquetes-opcionales)
- [Capacidades del Nodo](#-capacidades-del-nodo)

---

## 🤖 ¿Qué es OpenClaw?

OpenClaw lleva la puerta de enlace de IA [OpenClaw](https://github.com/anthropics/openclaw) a Android. Configura un entorno Ubuntu completo a través de **proot**, instala **Node.js 22** y **OpenClaw**, y proporciona una interfaz nativa de Flutter con control total sobre el gateway y acceso a capacidades del dispositivo (cámara, ubicación, sensor, etc.).

### Dos formas de usar

| Característica | 📱 App Flutter (Autónoma)        | 💻 CLI de Termux                 |
| -------------- | -------------------------------- | -------------------------------- |
| **Instalar**   | Compilar APK o descargar release | `npm install -g openclaw-termux` |
| **Configurar** | Tocar "Comenzar configuración"   | `openclawx setup`                |
| **Gateway**    | Tocar "Iniciar Gateway"          | `openclawx start`                |
| **Terminal**   | Emulador de terminal integrado   | Shell de Termux                  |
| **Panel Web**  | WebView integrado                | Navegador en `localhost:18789`   |

---

## 📸 Capturas de Pantalla

<div align="center">

|                                                                     |                                                                          |                                                                               |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| <img src="assets/dashboard.png" width="200"/><br/>**📊 Panel**      | <img src="assets/setupscreen.png" width="200"/><br/>**⚙️ Configuración** | <img src="assets/onboardingscreen.png" width="200"/><br/>**🚀 Incorporación** |
| <img src="assets/websscreen.png" width="200"/><br/>**🌐 Panel Web** | <img src="assets/logscreen.png" width="200"/><br/>**📋 Registros**       | <img src="assets/settingsscreen.png" width="200"/><br/>**🔧 Configuración**   |

</div>

---

## ✨ Características

### 📱 Aplicación Flutter

- **🎯 Configuración de un toque** — Descarga rootfs de Ubuntu, Node.js 22 y OpenClaw automáticamente
- **🖥️ Terminal integrada** — Emulador de terminal completo con barra de herramientas, copiar/pegar, URLs clicables
- **🎛️ Controles de Gateway** — Iniciar/detener gateway con indicador de estado y verificaciones de salud
- **🤖 Proveedores de IA** — Configurar claves API y seleccionar modelos para **7 proveedores** (Anthropic, OpenAI, Google Gemini, OpenRouter, NVIDIA NIM, DeepSeek, xAI)
- **🔒 Acceso remoto SSH** — Iniciar/detener servidor SSH, establecer contraseña raíz, comandos copiables
- **🔧 Menú Configurar** — Ejecutar `openclaw configure` en terminal integrada
- **📡 Capacidades de nodo** — 7 capacidades (15 comandos) expuestas a IA vía WebSocket
- **🔑 Captura de token** — Autenticación automática desde onboarding
- **🌐 Panel Web** — WebView integrado con token de autenticación (accesible desde Herramientas)
- **📋 Visor de registros** — Logs de gateway en tiempo real con búsqueda/filtro
- **📦 Paquetes opcionales** — Instalar Go, Homebrew y OpenSSH
- **⚙️ Configuración** — Auto-start, batería, info del sistema, re-ejecutar setup
- **🔔 Servicio foreground** — Gateway activa en segundo plano con notificaciones
- **📊 Barra de progreso optimizada** — Progreso de descarga con throttling inteligente (~20 líneas totales)

### ⚡ Runtime Gateway Optimizado (v1.9.0-beta.1)

- **OpenClaw sin `--verbose` por defecto** — Menos stdout y menor presión sobre el event loop de Node.js.
- **Launcher runtime auto-actualizable** — Las instalaciones existentes reciben el nuevo `start-gateway.sh` al iniciar el gateway, sin repetir el wizard.
- **Más espacio para Node.js** — V8 usa `--max-old-space-size=512` y `--max-semi-space-size=64` para reducir GC en cargas pesadas.
- **Caches persistentes** — `NODE_COMPILE_CACHE`, `XDG_CACHE_HOME` y `npm_config_cache` se guardan dentro del rootfs para acelerar arranques calientes.
- **Menos overhead de proot** — La limpieza de temporales se hace desde Kotlin y el gateway evita binds stdio que generaban warnings de `/proc/self/fd`.

### 🏗️ Arquitectura Modular (v1.8.9-beta)

- **MainActivity refactorizada** — La lógica nativa se dividió en 3 handlers especializados:
  - `SystemHandler` — Sistema, batería, permisos, webview
  - `HardwareHandler` — Cámara, sensores, BLE, USB Serial
  - `ProcessHandler` — Proot, bootstrap, servicios foreground
- **TerminalViewModule unificado** — Componente reutilizable de terminal compartido entre Terminal, Onboarding y Package Install
- **Optimización PTY con epoll** — Menor consumo de batería al leer datos de terminal

### 🐛 Correcciones Recientes (v1.8.9-beta)

- **WebViewActivity** ya no crashea — tema AppCompat corregido
- **Sin duplicados de app** — `launchMode="singleTask"` elimina copias múltiples
- **Gateway URL** abre navegador externo; Panel Web en Herramientas usa WebView interno

### 💻 CLI de Termux

- **⚡ Configuración de un comando** — Instala proot-distro, Ubuntu, Node.js 22 y OpenClaw
- **🩹 Bionic Bypass** — Soluciona el bloqueo `os.networkInterfaces()` en Android
- **⏳ Carga inteligente** — Spinner hasta que el gateway esté listo
- **🔀 Paso directo** — Ejecutar cualquier comando OpenClaw vía `openclawx`

---

## 🚀 Inicio Rápido

### 📱 App Flutter (Recomendado)

1. Descarga el APK desde [Releases](https://github.com/desarrollo032/openclaw-termux/releases)
2. Instala en tu dispositivo Android
3. Abre la app y toca **Comenzar configuración**
4. Opcional: instala **Go** o **Homebrew** desde las tarjetas de paquete
5. Configura tus API keys en **Incorporación**
6. Toca **Iniciar Gateway** en el panel

O compila desde la fuente:

```bash
git clone https://github.com/desarrollo032/openclaw-termux.git
cd openclaw-termux
bash scripts/build-apk.sh
```

---

### 🔧 Desarrollo

#### Configuracion OpenClaw y Gateway

> ⚡ **Nuevo en v1.9.0-beta.1:** runtime del gateway optimizado para arranque más rápido, menos logs, más cache y menor presión del event loop.

> Si compilas desde fuente, asegúrate de tener Flutter 3.24+ y Android SDK API 29+.

OpenClaw crea y mantiene su configuración principal en `/root/.openclaw/openclaw.json` dentro del rootfs. La app solo repara lo mínimo que necesita Android para arrancar de forma autónoma:

- `gateway.mode = "local"` para que `openclaw gateway` pueda iniciar.
- `gateway.nodes.allowCommands` para habilitar las capacidades del nodo Android.
- entradas antiguas de modelos que OpenClaw ya no acepta.

La app no debe crear `gateway.plugins`. En OpenClaw actual esa clave es inválida y `openclaw doctor --fix` falla con `gateway: Unrecognized key: "plugins"`. Si alguna vez se necesita configurar plugins del gateway, usa el esquema oficial de OpenClaw a nivel raíz (`plugins.entries`) o los comandos de OpenClaw, no una clave dentro de `gateway`.

Si una instalación vieja ya tiene `gateway.plugins`, abre la app actualizada o ejecuta el reparador; esa clave se elimina automáticamente sin borrar API keys, proveedores ni agentes.

**Si compilas manualmente con `flutter build`:**

```bash
cd flutter_app
flutter pub get
flutter build apk --release
```

### 💻 CLI de Termux

#### De una línea (recomendado)

```bash
curl -fsSL https://raw.githubusercontent.com/desarrollo032/openclaw-termux/main/install.sh | bash
```

#### O vía npm

```bash
npm install -g openclaw-termux
openclawx setup
```

---

## 📋 Requisitos

| Requisito                | Detalle                                                                   |
| ------------------------ | ------------------------------------------------------------------------- |
| **📱 Android**           | 10 o superior (API 29)                                                    |
| **💾 Almacenamiento**    | ~500 MB para Ubuntu + Node.js + OpenClaw                                  |
| **🏗️ Arquitecturas**     | arm64-v8a, armeabi-v7a, x86_64                                            |
| **📦 Termux** (solo CLI) | Desde [F-Droid](https://f-droid.org/packages/com.termux/) (NO Play Store) |

---

## ⚠️ Advertencias

> [!IMPORTANT]
> **Permiso de almacenamiento** — Esta app **NO** necesita acceso de almacenamiento completo. Si se solicita, **deniega** el permiso a menos que necesites que proot acceda a `/sdcard`.

> [!CAUTION]
> **Optimización de batería** — Deshabilita la optimización de batería para la app en Ajustes de Android para evitar que el gateway se cierre en segundo plano.

> [!NOTE]
> **Primer lanzamiento** — La configuración inicial descarga ~500 MB. Asegúrate de tener una conexión estable y suficiente almacenamiento.

---

## 💻 Uso de CLI

```bash
# Primera vez: configuración (instala proot + Ubuntu + Node.js + OpenClaw)
openclawx setup

# Verificar estado de instalación
openclawx status

# Iniciar gateway de OpenClaw
openclawx start

# Ejecutar incorporación para configurar API keys
openclawx onboarding

# Entrar en shell de Ubuntu
openclawx shell

# Cualquier comando OpenClaw funciona directamente
openclawx doctor
openclawx gateway --verbose
```

---

## 📦 Paquetes Opcionales

Después de la configuración inicial, instala herramientas de desarrollo directamente desde la app:

| Paquete         | Instalación                  | Tamaño  | Acceso                     |
| --------------- | ---------------------------- | ------- | -------------------------- |
| **Go (Golang)** | `apt install golang`         | ~150 MB | Setup, Dashboard, Settings |
| **Homebrew**    | Instalador oficial           | ~500 MB | Setup, Dashboard, Settings |
| **OpenSSH**     | `apt install openssh-server` | ~10 MB  | Setup, Dashboard, Settings |

---

## 📡 Capacidades del Nodo

La app se conecta al gateway como un **nodo**, exponiendo hardware de Android a la IA:

| Capacidad        | Comandos                                                | Permiso Requerido   |
| ---------------- | ------------------------------------------------------- | ------------------- |
| **📷 Cámara**    | `camera.snap`, `camera.clip`, `camera.list`             | Cámara              |
| **🎨 Lienzo**    | `canvas.navigate`, `canvas.eval`, `canvas.snapshot`     | Ninguno             |
| **💡 Flash**     | `flash.on`, `flash.off`, `flash.toggle`, `flash.status` | Cámara (linterna)   |
| **📍 Ubicación** | `location.get`                                          | Ubicación           |
| **🖥️ Pantalla**  | `screen.record`                                         | MediaProjection     |
| **📊 Sensor**    | `sensor.read`, `sensor.list`                            | Sensores corporales |
| **📳 Háptica**   | `haptic.vibrate`                                        | Ninguno             |

> El archivo `openclaw.json` se repara automáticamente para permitir los 15 comandos y limpiar claves antiguas inválidas como `gateway.plugins`.

---

<div align="center">

**Hecho con ❤️ por [desarrollo032](https://github.com/desarrollo032)**

[Reportar Bug](https://github.com/desarrollo032/openclaw-termux/issues) · [Solicitar Feature](https://github.com/desarrollo032/openclaw-termux/issues) · [Contribuir](https://github.com/desarrollo032/openclaw-termux/pulls)

</div>
