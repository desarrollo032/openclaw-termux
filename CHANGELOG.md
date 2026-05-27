# 📋 Changelog

> Todas las versiones notables de OpenClaw.

---

## 🚦 v1.9.0-beta.1 <small>— Gateway Runtime Performance Beta</small>

### 🚀 Mejoras de rendimiento

- **Arranque de OpenClaw sin modo verbose por defecto** — El gateway ahora se ejecuta con salida limpia (`--no-color --no-emoji`) para reducir carga de stdout, presión sobre el event loop y tráfico de logs entre proot, Kotlin y Flutter.
- **Launcher runtime auto-actualizable** — Antes de iniciar OpenClaw, la app refresca `/root/.openclaw/start-gateway.sh` para que instalaciones existentes reciban las optimizaciones sin repetir el wizard ni reinstalar paquetes.
- **Más espacio para V8** — El heap de Node.js sube a 512 MB y el semi-space a 64 MB para disminuir GC agresivo cuando OpenClaw carga plugins y dependencias pesadas.
- **Caches persistentes en storage de la app** — `NODE_COMPILE_CACHE`, `XDG_CACHE_HOME` y `npm_config_cache` quedan dentro del rootfs para acelerar arranques calientes y reutilizar compilación/caches.
- **Limpieza de temporales sin abrir proot extra** — Los temporales del gateway se limpian desde Kotlin sobre el filesystem de la app, evitando un proceso proot adicional antes de arrancar OpenClaw.
- **Menos warnings de `/proc/self/fd` en gateway mode** — El modo runtime evita binds stdio innecesarios que generaban ruido de proot en dispositivos Android.

### ✅ Validación

- `flutter analyze`
- `:app:testDebugUnitTest --tests com.nxg.openclawproot.GatewayRuntimePolicyTest`
- `:app:assembleDebug`

---

## 🚦 v1.8.9-beta <small>— WebView Fix, Arquitectura Modular & Terminal Optimizada</small>

### 🐛 Correcciones

- **WebViewActivity Crash** — El panel web crasheaba al abrirse por tema incompatible. Corregido: nuevo `WebViewTheme` heredando de `Theme.AppCompat.Light.NoActionBar`.
- **Duplicados de App** — `taskAffinity=""` causaba múltiples copias de la app al abrir enlaces. Corregido: `launchMode="singleTask"` y eliminación de `taskAffinity`.
- **AccessibilityService API 35+** — `TakeScreenshotCallback` usaba `getBitmap()` eliminado en API 35. Corregido: usa `ScreenshotResult.hardwareBuffer` + `Bitmap.wrapHardwareBuffer()`.
- **SystemHandler webSearch** — Variable `query` fuera de scope en bloque catch. Corregida declaración movida fuera del try-catch.
- **canControlFlashlight** — Atributo no disponible eliminado de `accessibility_service_config.xml`.

### 🚀 Nuevas Funcionalidades

- **Dashboard: Gateway URL abre navegador externo** — La URL con token y botón "Abrir" en la tarjeta del Gateway ahora abren Chrome/navegador predeterminado. "Panel Web" en Herramientas sigue usando el WebView interno.
- **Verificación SHA256 dinámica** — El hash SHA256 del rootfs se obtiene automáticamente desde `SHA256SUMS` de Ubuntu al instalar, garantizando integridad incluso si el tarball se actualiza.
- **Throttling de descarga rootfs** — El progreso de descarga ya no genera cientos de líneas. Ahora solo loguea al cruzar cada 5% (~20 líneas totales) y actualiza la UI como máximo cada 500ms.

### 🏗️ Arquitectura

- **MainActivity refactorizada en handlers** — La "clase dios" `MainActivity.kt` se dividió en `SystemHandler`, `HardwareHandler` y `ProcessHandler`, mejorando mantenibilidad y testabilidad.
- **TerminalViewModule unificado** — Nuevo widget reutilizable `TerminalViewModule` que encapsula la lógica PTY. Ahora compartido entre las pantallas Terminal, Onboarding y Package Install.
- **Optimización PTY con epoll** — El native C++ (`openclaw_pty.cpp`) ahora usa `epoll` para lectura eficiente, eliminando polling y reduciendo consumo de batería.

### 🔧 Mejoras

- **Logs de instalación limpios** — El progreso de descarga del rootfs se muestra con throttling inteligente, eliminando el spam en la consola en vivo.
- **Código Kotlin más modular** — Handlers especializados reemplazan el monolithic switch en MainActivity.
- **Componente de terminal consistente** — Misma experiencia de terminal en todas las pantallas que usan PTY.

---

## 🚦 v1.8.8-beta <small>— Auto-Recovery System & Instalación Resiliente</small>

### 🚀 Nuevas Funcionalidades

- **Sistema de Recuperación Automática dpkg/apt** — Detecta y repara automáticamente errores como "dpkg was interrupted", "exit code 100", locks rotos, paquetes inconsistentes y más, sin intervención manual.
- **Reinteligente con 3 Intentos** — Si un comando apt/dpkg falla por un error recuperable, el sistema ejecuta la secuencia de reparación y reintenta hasta 3 veces antes de marcar el entorno como corrupto.
- **Pre-Flight dpkg Audit** — Antes de ejecutar comandos apt, se verifica el estado de dpkg con `dpkg --audit` y se repara si es necesario.
- **Flag `_recoveryAttempted`** — Optimización que evita verificaciones redundantes de dpkg durante la misma instalación.

### 🔧 Mejoras de Estabilidad

- **Recuperación en Dos Capas** — Kotlin (`ProcessManager.runInProotWithRecovery`) ejecuta la reparación pre-vuelo; Dart (`BootstrapService._runProotWithRecovery`) maneja reintentos, detección de entorno corrupto y logging estructurado.
- **Secuencia de Reparación Completa:**
  1. Limpieza de archivos lock (`/var/lib/dpkg/lock*`, `/var/cache/apt/archives/lock`, `/var/lib/apt/lists/lock`)
  2. `dpkg --configure -a` (reconfigura paquetes interrumpidos)
  3. `apt --fix-broken install -y` (repara dependencias rotas)
  4. `apt update && apt upgrade -y` (refresca estado de paquetes)
- **Detección de Entorno Corrupto** — Si tras 3 intentos no se puede recuperar, se lanza `_CorruptEnvironmentException` con mensaje claro al usuario.
- **Logging Claro** — Mensajes con prefijos `[STEP]`, `[OK]`, `[WARN]`, `[ERR]` visibles en la consola en vivo durante la instalación.

### 🐛 Correcciones

- **Instalación interrumpida por dpkg** — El error `PlatformException(PROOT_ERROR, exit code 100)` ya no bloquea la instalación; el sistema lo detecta y repara automáticamente.

---

## 🚦 v1.8.6 <small>— Config Repair, Gateway Mode & Node.js Update</small>

### 🐛 Bug Fixes

- **Config Corruption Fix (#83, #88)** — Provider model entries were written as bare strings instead of objects (`{ id: "model-name" }`), causing OpenClaw config validation to reject the file. Fixed both the Node.js script path and the direct file I/O fallback. Existing corrupted configs are now auto-repaired on gateway init.
- **Gateway Start Failure (#93, #90)** — The gateway blocked with "set gateway.mode=local (current: unset)". Now `gateway.mode=local` is set automatically in `openclaw.json` during provider config saves, gateway config writes, bionic bypass installation, and on startup repair.
- **Config Auto-Repair on Init (#88)** — Added `_repairConfigFile()` that runs on every `GatewayService.init()` to fix corrupted model entries and missing `gateway.mode`.
- **Bionic Bypass Robustness (#94)** — Added retry logic with parent directory creation if `mkdirs()` fails silently.
- **Pre-seed Config on Setup** — `installBionicBypass()` now creates a default `openclaw.json` with `gateway.mode=local`.
- **Setup Re-prompt After Node Upgrade (#97)** — Expanded auto-repair to reinstall Node.js and OpenClaw when binaries are missing.

### ✨ Enhancements

- **Node.js Updated to 22.14.0** — Upgraded from 22.13.1 to latest 22.x LTS.
- **npm Package Synced to 1.8.6** — Updated package.json version, refreshed dependencies, bumped engine to Node >= 22.
- **Removed Outdated Model** — Dropped `claude-3-5-sonnet-20241022` from Anthropic defaults.

---

## 🚦 v1.8.4 <small>— Serial, Log Timestamps & ADB Backup</small>

### 🚀 New Features

- **Serial over Bluetooth & USB (#21)** — New `serial` node capability with 5 commands (`list`, `connect`, `disconnect`, `write`, `read`). Supports USB serial via `usb_serial` and BLE via Nordic UART Service.
- **Gateway Log Timestamps (#54)** — All gateway log messages now include ISO 8601 UTC timestamps.
- **ADB Backup Support (#55)** — Added `android:allowBackup="true"` to AndroidManifest.

### ✨ Enhancements

- **Check for Updates (#59)** — New option in Settings > About. Queries GitHub Releases API, compares semver, shows update dialog.

### 🐛 Bug Fixes

- **Node Capabilities Not Available (#56)** — Added direct file I/O fallback to write `openclaw.json` directly on the Android filesystem.
- **Node Commands Reference** — Fixed `node.capabilities` event to send both `commands` and `caps` fields.

---

## 🚦 v1.8.3 <small>— Multi-Instance Guard</small>

### 🐛 Bug Fixes

- **Duplicate Gateway Processes (#48)** — Services guard against re-entry when Android re-delivers `onStartCommand`.
- **Wakelock Leaks** — All 5 foreground services release existing wakelock before acquiring a new one.
- **Orphan PTY Instances** — Terminal screens kill previous PTY before starting a new one on retry.
- **Notification ID Collisions** — SetupService and ScreenCaptureService use unique notification IDs.

---

## 🚦 v1.8.2 <small>— DNS Reliability, Screenshot Capture & Custom Models</small>

### 🐛 Bug Fixes

- **Setup State Detection (#44)** — Replaced slow proot exec check with fast filesystem check.
- **DNS / No Internet Inside Proot (#45)** — `resolv.conf` written to both `config/` and `rootfs/ubuntu/etc/` at every entry point.
- **NVIDIA NIM Config Breaks Onboarding (#46)** — Provider config falls back to direct file write if proot Node.js fails.

### 🚀 New Features

- **📸 Screenshot Capture** — Camera button on terminal and log screens to capture PNG images.
- **🎨 Custom Model Support (#46)** — Enter any custom model name via "Custom..." option.
- **Updated NVIDIA Models (#46)** — Added `meta/llama-3.3-70b-instruct` and `deepseek-ai/deepseek-r1`.

### 🔧 Reliability

- **resolv.conf at Every Entry Point** — Ensures DNS config at app launch, proot invocation, gateway start, SSH start.
- **APK Update Resilience** — Directories and DNS config recreated on engine init.

---

## 🚦 v1.8.0 <small>— AI Providers, SSH Access & Configure Menu</small>

### 🚀 New Features

- **🤖 AI Providers** — Configure API keys for 7 providers: Anthropic, OpenAI, Google Gemini, OpenRouter, NVIDIA NIM, DeepSeek, xAI.
- **🔒 SSH Remote Access** — Start/stop SSH server inside proot, set password, copyable connection info.
- **🔧 Configure Menu** — Run `openclaw configure` in built-in terminal.
- **🔗 Clickable URLs** — Terminal screens detect URLs at tap position.

### 🐛 Bug Fixes

- **Ctrl Key with Soft Keyboard (#37)** — Modifier state applies to soft keyboard input.
- **Ctrl+Arrow/Home/End (#38)** — Correct escape sequences for navigation keys.
- **resolv.conf ENOENT (#40)** — DNS resolution ensured on every app launch.

### 📊 Dashboard

- Added **AI Providers** and **SSH Access** quick action cards.

---

## 🚦 v1.7.3 <small>— DNS Fix, Snapshot & Version Sync</small>

### 🐛 Bug Fixes

- **DNS Breaks After a While (#34)** — `resolv.conf` written before every gateway start.
- **Version Mismatch (#35)** — Synced version across all files to `1.7.3`.

### 🚀 New Features

- **💾 Config Snapshot (#27)** — Export/Import `openclaw.json` and preferences.
- **📂 Storage Access** — Termux-style "Setup Storage" in Settings. Bind-mounts `/sdcard` into proot.

---

## 🚦 v1.7.2 <small>— Setup Fix</small>

### 🐛 Bug Fixes

- **node-gyp Python Error** — Installs `python3`, `make`, `g++` for native addon compilation.
- **tzdata Interactive Prompt** — Pre-configures timezone to UTC before installing python3.

---

## 🚦 v1.7.1 <small>— Background Persistence & Camera Fix</small>

> Requires Android 10+ (API 29)

### 🔄 Node Background Persistence

- **Lifecycle-Aware Reconnection** — Handles `resumed`/`paused` states.
- **Foreground Service Verification** — Watchdog ensures service is alive.
- **Stale Connection Recovery** — Forces reconnect after 90s+ of inactivity.
- **Live Notification Status** — Real-time node state in notification.

### 📷 Camera Fix

- **Immediate Camera Release** — `try/finally` ensures hardware release.
- **Auto-Exposure Settle** — 500ms settle time before snap.
- **Flash Conflict Prevention** — Camera released when torch is off.
- **Stale Controller Recovery** — Detects errored controllers and recreates.

---

## 🚦 v1.7.0 <small>— Clean Modern UI Redesign</small>

> Requires Android 10+ (API 29)

### 🎨 UI Overhaul

- **New Color System** — Professional black/white palette with red accent (#DC2626).
- **Inter Typography** — Google Fonts Inter across the entire app.
- **AppColors Class** — Centralized color constants.
- **Dark Mode** — Near-black backgrounds (#0A0A0A), subtle surfaces.
- **Light Mode** — Clean white backgrounds, light borders.

### 🧩 Component Redesign

- **Zero-Elevation Cards** — 1px borders instead of shadows.
- **Pill Status Badges** — Icon + label instead of 12px dots.
- **Monochrome Dashboard** — Neutral muted icon colors.
- **Uppercase Section Headers** — Letterspaced muted grey headers.
- **Red Accent Buttons** — Primary actions in red.
- **Terminal Toolbar** — Aligned to new palette.

### ✨ Splash Screen

- **Fade-In Animation** — 800ms easeOut.
- **App Icon Branding** — Uses `ic_launcher.png`.
- **Inter Bold Wordmark** — Weight 800 with letter-spacing.

### 🎯 Polish

- **Log Colors** — INFO in grey, WARN in amber.
- **Installed Badges** — Green (#22C55E).
- **Capability Icons** — Muted colors.
- **Input Focus** — Red border on focus.
- **Switches** — Red when active, grey when inactive.
- **Progress Indicators** — Red accent.

### 🔄 CI

- Removed OpenClaw Node app build (gateway-only CI).

---

## 🚦 v1.6.1 <small>— Node Capabilities & Background Resilience</small>

> Requires Android 10+ (API 29)

### 🚀 New Features

- **7 Node Capabilities (15 commands)** — Camera, Flash, Location, Screen, Sensor, Haptic, Canvas.
- **Proactive Permissions** — Requested upfront when node is enabled.
- **Battery Optimization Prompt** — Exempt from battery restrictions.

### 🔄 Background Resilience

- **WebSocket Keep-Alive** — 30-second periodic ping.
- **Connection Watchdog** — 45-second timer.
- **Stale Connection Detection** — Forces reconnect after 90s.
- **App Lifecycle Handling** — Auto-reconnects on foreground.
- **Exponential Backoff** — 350ms-8s reconnect backoff.

### 🐛 Fixes

- **Gateway Config** — Patches `openclaw.json` for all 15 commands.
- **Location Timeout** — 10-second GPS limit with fallback.
- **Canvas Errors** — Returns honest `NOT_IMPLEMENTED` errors.
- **Node Display Name** — Renamed to "OpenClawX Node".

---

## 🚦 v1.5.5 <small>— Initial Release</small>

- Initial release with gateway management, terminal emulator, and basic node support.
