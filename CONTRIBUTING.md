# 🤝 Guía de Contribución — OpenClaw

¡Gracias por tu interés en contribuir a **OpenClaw**! Este proyecto lleva el gateway de IA OpenClaw a Android, combinando una app Flutter nativa con un CLI de Node.js.

---

## 📋 Tabla de Contenidos

- [Código de Conducta](#-código-de-conducta)
- [¿Cómo Contribuir?](#-cómo-contribuir)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Configuración del Entorno](#-configuración-del-entorno)
- [Desarrollo de la App Flutter](#-desarrollo-de-la-app-flutter)
- [Desarrollo del CLI Node.js](#-desarrollo-del-cli-nodejs)
- [Estilo de Código](#-estilo-de-código)
- [Pruebas](#-pruebas)
- [Pull Requests](#-pull-requests)
- [Reportar Issues](#-reportar-issues)
- [Recursos](#-recursos)

---

## 📜 Código de Conducta

Este proyecto sigue un [Código de Conducta](CODE_OF_CONDUCT.md) basado en el **Contributor Covenant v2.0**. Al participar, te comprometes a mantener un entorno **respetuoso, inclusivo y libre de acoso**.

---

## 🎯 ¿Cómo Contribuir?

Hay muchas formas de contribuir, no solo escribiendo código:

### 🐛 Reportar Bugs

1. **Verifica** que el bug no haya sido reportado ya en [Issues](https://github.com/mithun50/openclaw-termux/issues)
2. **Abre un issue** usando la plantilla de bug report
3. **Incluye**:
   - Versión de OpenClaw (app + CLI)
   - Dispositivo Android y versión del SO
   - Pasos para reproducir
   - Comportamiento esperado vs. real
   - Capturas de pantalla o logs (si aplica)

### 💡 Sugerir Features

1. **Revisa** los issues existentes para ver si ya se ha sugerido
2. **Abre un issue** con la etiqueta `enhancement`
3. **Describe** el problema que resuelve y cómo debería funcionar

### 🛠️ Contribuir Código

1. **Elige o crea** un issue para trabajar
2. **Comenta** en el issue que estás trabajando en ello
3. **Sigue** los pasos de [Pull Requests](#-pull-requests)

---

## 📁 Estructura del Proyecto

```
openclaw-termux/
├── flutter_app/                  # 📱 App Flutter (Android)
│   ├── android/                  #   Configuración nativa Android
│   │   └── app/
│   │       ├── build.gradle      #     Build de Gradle
│   │       └── src/main/kotlin/  #     Código Kotlin nativo
│   ├── assets/                   #   Assets (fonts, configs)
│   ├── lib/                      #   Código Dart
│   │   ├── main.dart             #   Punto de entrada
│   │   ├── app.dart              #   Configuración de la app
│   │   ├── constants.dart        #   Constantes globales
│   │   ├── models/               #   Modelos de datos
│   │   ├── providers/            #   State management (Provider)
│   │   ├── screens/              #   Pantallas de la UI
│   │   ├── services/             #   Servicios (gateway, node, etc.)
│   │   │   └── capabilities/     #   Capacidades del nodo
│   │   └── widgets/              #   Widgets reutilizables
│   └── pubspec.yaml              #   Dependencias Flutter
├── bin/                          # CLI entry point
│   └── openclawx                 #   Script principal
├── lib/                          # 📦 Código Node.js (CLI)
│   ├── index.js                  #   Punto de entrada
│   ├── installer.js              #   Instalador de proot/Ubuntu
│   ├── postinstall.js            #   Post-instalación npm
│   └── bionic-bypass.js          #   Parche bionic
├── docs/                         # 📄 Documentación
│   └── privacy-policy.html       #   Política de privacidad
├── scripts/                      # 🔧 Scripts de build
│   ├── build-apk.sh              #   Build de APK
│   └── fetch-proot-binaries.sh   #   Descarga binarios proot
├── .github/workflows/            # 🤖 CI/CD
│   └── flutter-build.yml         #   Build automático
├── package.json                  # Dependencias Node.js
├── README.md                     # Este archivo
├── CODE_OF_CONDUCT.md            # Código de conducta
├── CHANGELOG.md                  # Registro de cambios
├── CONTRIBUTING.md               # Esta guía
├── install.sh                    # Instalación de un solo comando
└── eslint.config.js              # Configuración ESLint
```

---

## 🔧 Configuración del Entorno

### Requisitos Mínimos

| Herramienta | Versión | Propósito |
|---|---|---|
| **Flutter** | 3.24.x stable | Compilar la app Android |
| **Dart** | >=3.2.0 | Lenguaje de la app |
| **Node.js** | >=22.0.0 | CLI + scripts |
| **Java** | 17 (Temurin) | Compilación de Gradle |
| **Android SDK** | API 29+ | Build de APK |
| **Git** | — | Control de versiones |

### 1. Clonar el Repositorio

```bash
git clone https://github.com/mithun50/openclaw-termux.git
cd openclaw-termux
```

### 2. Configurar Flutter

```bash
# Instalar Flutter (si no lo tienes)
# Sigue: https://docs.flutter.dev/get-started/install

# Verificar instalación
flutter doctor

# Obtener dependencias
cd flutter_app
flutter pub get
```

### 3. Configurar Node.js

```bash
# Instalar dependencias del CLI
npm install

# Opcional: enlazar el CLI para desarrollo
npm link
```

### 4. Descargar Binarios PRoot

```bash
bash scripts/fetch-proot-binaries.sh
```

Esto descarga `libproot.so` y `libprootloader.so` en `flutter_app/android/app/src/main/jniLibs/` para las arquitecturas soportadas (arm64-v8a, armeabi-v7a, x86_64).

---

## 📱 Desarrollo de la App Flutter

### Comandos Principales

```bash
cd flutter_app

# Obtener dependencias (después de cambios en pubspec.yaml)
flutter pub get

# Análisis estático (corregir errores y warnings)
flutter analyze

# Ejecutar en dispositivo/emulador
flutter run

# Build de depuración
flutter build apk --debug

# Build de release
flutter build apk --release

# Build con división por ABI
flutter build apk --release --split-per-abi

# Build de App Bundle
flutter build appbundle --release
```

### Convenciones de la App

- **Provider** para state management (no BLoC, no Riverpod)
- **Service layer** separada de la UI (servicios en `services/`)
- **Modelos** tipados en `models/` con copyWith para inmutabilidad
- **Widgets reutilizables** en `widgets/`
- **Const constructors** siempre que sea posible (`prefer_const_constructors: true`)
- **null safety estricto** — sin operadores `!` de null assertion

### Arquitectura

```
Screen (StatefulWidget)
  └── Provider (ChangeNotifier)
        ├── Service (GatewayService, NodeService, etc.)
        └── Model (datos inmutables)
```

Los providers se registran en `app.dart` usando `MultiProvider` y `ChangeNotifierProxyProvider`.

---

## 💻 Desarrollo del CLI Node.js

### Comandos Principales

```bash
# Ejecutar pruebas
npm test

# Lint
npm run lint

# Lint con auto-corrección
npm run lint:fix
```

### Convenciones del CLI

- **ESM** (type: "module" en package.json)
- **ESLint** con configuración plana (`eslint.config.js`)
- **Chalk** para output con colores
- **Ora** para spinners de carga
- **Inquirer** para prompts interactivos

---

## 🎨 Estilo de Código

### Dart / Flutter

- **Sigue** las reglas de `flutter_lints` (incluidas en `analysis_options.yaml`)
- **Preferir** `const` constructores y declaraciones
- **`avoid_print: false`** — se permite `print()` para depuración (no es necesario usar `logging`)
- **Nombres**: `camelCase` para variables/funciones, `PascalCase` para clases
- **Tipado**: siempre explícito, evitar `dynamic`
- **Comentarios**: `///` para documentación pública, `//` para notas internas
- **Importaciones**: orden absoluto → paquete → relativo
- **Testing**: usa `flutter_test` para tests unitarios de widgets/providers

### JavaScript / Node.js

- **ESLint flat config**: formato moderno `eslint.config.js` (no `.eslintrc` tradicional)
- **ESM**: `import`/`export` en lugar de `require`
- **Async/await** en lugar de callbacks o promesas anidadas
- **Nombres**: `camelCase` para variables/funciones, `PascalCase` para clases

### Convenciones Generales

- **Espacios**: 2 espacios de indentación (Dart y JS)
- **Archivos**: un archivo por clase, nombrado en `snake_case`
- **Líneas**: máximo 80-100 caracteres
- **Commits**: usar [Commits Convencionales](https://www.conventionalcommits.org/)

---

## 🧪 Pruebas

### Flutter

```bash
cd flutter_app

# Ejecutar todos los tests
flutter test

# Ejecutar tests con coverage
flutter test --coverage

# Ejecutar un test específico
flutter test test/services/gateway_service_test.dart
```

### Node.js

```bash
# Ejecutar test suite
npm test
```

**Reglas:**
- Los tests deben pasar antes de enviar un PR
- Las nuevas funcionalidades deben incluir tests cuando sea práctico
- Corre `flutter analyze` para verificar que no hay errores de lint

---

## 🔀 Pull Requests

### Proceso

1. **Fork** el repositorio en GitHub
2. **Crea una rama** desde `main` con un nombre descriptivo:

   ```bash
   git checkout -b feat/nueva-funcionalidad
   git checkout -b fix/descripcion-del-bug
   ```

3. **Haz commits** pequeños y descriptivos:

   ```bash
   git commit -m "feat: agregar soporte para nuevo proveedor IA"
   git commit -m "fix: corregir error al reconectar WebSocket"
   git commit -m "docs: actualizar README con nuevos proveedores"
   ```

4. **Mantén tu rama actualizada** con `main`:

   ```bash
   git fetch origin
   git rebase origin/main
   ```

5. **Verifica** antes de enviar:

   ```bash
   cd flutter_app && flutter analyze --no-fatal-infos && flutter test
   cd .. && npm test && npm run lint
   ```

6. **Abre un Pull Request** con:
   - Título descriptivo siguiendo [Commits Convencionales](https://www.conventionalcommits.org/)
   - Descripción clara de los cambios
   - Referencia al issue que resuelve (ej: `Closes #123`)
   - Capturas de pantalla si hay cambios visuales

### Checklist para PRs

- [ ] El código sigue el estilo del proyecto
- [ ] `flutter analyze --no-fatal-infos` pasa sin errores
- [ ] Los tests existentes pasan
- [ ] Se agregaron tests nuevos si aplica
- [ ] La documentación se actualizó si es necesario
- [ ] El CHANGELOG se actualizó (si aplica)
- [ ] No hay dependencias nuevas sin justificación

### Revisión

- Un mantenedor revisará tu PR
- Puede solicitar cambios o discutir la implementación
- Una vez aprobado, se hará merge a `main`

---

## 🐛 Reportar Issues

Usa las plantillas de GitHub para cada tipo de issue:

### Bug Report

```
**Descripción:** [breve descripción del bug]

**Para reproducir:**
1. Ir a '...'
2. Tocar en '...'
3. Desplazar a '...'
4. Ver error

**Comportamiento esperado:**
[qué debería pasar]

**Capturas de pantalla:**
[si aplica]

**Dispositivo:**
- Android: [ej: 14]
- Dispositivo: [ej: Pixel 8]
- Versión OpenClaw: [ej: 1.8.7]

**Logs adicionales:**
[si aplica]
```

### Feature Request

```
**Problema:**
[qué problema resuelve esta funcionalidad]

**Solución propuesta:**
[cómo debería funcionar]

**Alternativas consideradas:**
[otras soluciones que consideraste]

**Contexto adicional:**
[capturas, ejemplos, etc.]
```

---

## 📚 Recursos

- [Documentación de Flutter](https://docs.flutter.dev/)
- [OpenClaw Gateway (oficial)](https://github.com/anthropics/openclaw)
- [Commits Convencionales](https://www.conventionalcommits.org/)
- [Contributor Covenant](https://www.contributor-covenant.org/)

---

<div align="center">

**¡Gracias por contribuir!** 💙

[Código de Conducta](CODE_OF_CONDUCT.md) · [Reportar Bug](https://github.com/mithun50/openclaw-termux/issues) · [GitHub](https://github.com/mithun50/openclaw-termux)

</div>
