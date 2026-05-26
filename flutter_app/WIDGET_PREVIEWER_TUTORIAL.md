# 📱 Flutter Widget Previewer - Guía Visual Paso a Paso

## 🎯 Objetivo
Ver tus widgets Flutter renderizarse en **tiempo real**, sin ejecutar la app completa.

---

## ✅ PASO 1: Verifica que tengas Flutter 3.2+

Abre una terminal y escribe:

```bash
flutter --version
```

**Debes ver algo como:**
```
Flutter 3.2.0 o superior ✅
```

Si tienes una versión anterior, actualiza:
```bash
flutter upgrade
```

---

## ✅ PASO 2: Abre un archivo con previews

En tu IDE (Android Studio, IntelliJ o VS Code), abre:

```
lib/previews/setup_previews.dart
```

El archivo se verá así:

```dart
import 'package:flutter/widget_previews.dart';

// ... código del tema ...

@Preview(name: 'SetupWizard - Light')  // ← Esto es lo importante
Widget setupWizardPreInstall() {
  return ChangeNotifierProvider(
    create: (_) => SetupProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      home: const SetupWizardScreen(),
    ),
  );
}
```

---

## ✅ PASO 3: Haz clic en "Preview"

En el **lado derecho del editor**, verás un icono de dispositivo (📱).

**Android Studio / IntelliJ:**
→ Busca un pequeño icono de teléfono en la esquina superior derecha
→ Haz clic ahí

**VS Code:**
→ Verás "Run Preview" como un link encima de `@Preview`
→ Haz clic en ese link

---

## ✅ PASO 4: ¡Usa el panel Preview!

Se abrirá una ventana que mostrará tu widget renderizado.

### Controles disponibles:

```
┌─────────────────────────────────────────────┐
│  SetupWizard - Light                        │
├─────────────────────────────────────────────┤
│  [ Pixel 5 ▼ ]  [ Light/Dark ☀️ ]         │
│  [ 📏 375x812 ]  [ 🔄 Refresh ]  [ 📐 ]   │
├─────────────────────────────────────────────┤
│                                             │
│        [Tu Widget aquí renderizado]         │
│        [Sin necesidad de ejecutar app]      │
│        [Hot reload al guardar cambios]      │
│                                             │
└─────────────────────────────────────────────┘
```

---

## ✅ PASO 5: Juega con los controles

### 🌙 Cambia entre Light y Dark
- Haz clic en el icono de tema (☀️ / 🌙)
- Verás tu widget cambiar al tema oscuro al instante

### 📱 Cambia dispositivo
- Haz clic en el dropdown (ej: "Pixel 5")
- Elige otro dispositivo (iPhone, tablet, etc)
- Tu widget se adaptará al nuevo tamaño

### 🔄 Refresca
- Haz clic en "Refresh" para recargar

---

## ✅ PASO 6: Edita tu código y prueba Hot Reload

Abre `setup_previews.dart` y cambia algo pequeño:

**Antes:**
```dart
@Preview(name: 'SetupWizard - Light')
Widget setupWizardPreInstall() {
  return ChangeNotifierProvider(
    create: (_) => SetupProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      home: const SetupWizardScreen(),
    ),
  );
}
```

**Después (cambia el color de un botón):**
```dart
// En el widget que quieras editar, cambia un Color:
const Color(0xFF6C63FF),  // Antes
const Color(0xFFFF6B9D),  // Después (ahora es rosado)
```

**Guarda (Ctrl+S) → ¡Verás el cambio en el preview al instante!** ⚡

---

## 💡 EJEMPLO PRÁCTICO

### Crea tu primer preview personalizado

1. **Abre `lib/previews/widget_previews.dart`**

2. **Crea una nueva función preview:**

```dart
@Preview(name: 'Mi Botón Personalizado')
Widget myButtonPreview() {
  return Material(
    child: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download),
            label: const Text('Mi Botón'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
```

3. **Abre el archivo en tu IDE**

4. **Haz clic en Preview → ¡Verás tu botón renderizado! 🎉**

5. **Edita el botón (ej: cambia el icono)**

6. **Guarda → ¡Hot reload instantáneamente! ⚡**

---

## 🚀 CASO DE USO REAL: Desarrollar una pantalla completa

### Sin Widget Previewer (lo antiguo):
```
Edita pantalla → Ejecuta app completa (5-10 seg) → 
Navega a la pantalla → No se ve como querías → 
Edita de nuevo → Ejecuta app (5-10 seg) → 
Repite 50 veces... 😫
```

### Con Widget Previewer (nuevo):
```
Edita pantalla → Guarda → ¡Ves el cambio en 0.5 seg! ⚡
No se ve bien → Edita → Guarda → ¡Ves el cambio! ⚡
Repite 50 veces muy rápido 🚀
```

**Aceleras el desarrollo 10x** 🎯

---

## 📂 Archivos con Previews en tu Proyecto

| Archivo | Para probar | Función |
|---------|------------|---------|
| `lib/previews/setup_previews.dart` | Pantalla Setup | SetupWizardScreen |
| `lib/previews/widget_previews.dart` | Dashboard, Terminal, Cards | DashboardScreen, TerminalScreen |

---

## 🎯 Checklist de verificación

- [ ] Tengo Flutter 3.2+ instalado
- [ ] He abierto un archivo con `@Preview`
- [ ] He encontrado el botón Preview en el editor
- [ ] He visto mi widget renderizarse
- [ ] He cambiado el tema (light ↔ dark)
- [ ] He editado el código y vi hot reload
- [ ] He probado múltiples dispositivos

**Si marcaste todos:** ¡Felicidades! 🎉 Ya dominas Widget Previewer

---

## ❓ Problema: No veo el botón Preview

**Solución 1:**
```bash
flutter pub get
```

**Solución 2:** Reinicia el IDE

**Solución 3:** Verifica que la función esté decorada con `@Preview`:
```dart
@Preview(name: 'algo')  // ← Esto debe estar
Widget myWidget() { ... }
```

**Solución 4:** Asegúrate que `flutter/widget_previews.dart` está importado:
```dart
import 'package:flutter/widget_previews.dart';  // ← Debe estar aquí
```

---

## 🔗 Recursos Útiles

- **Archivos de ejemplo en tu proyecto:**
  - `lib/previews/setup_previews.dart`
  - `lib/previews/widget_previews.dart`
  - `lib/previews/README.md`

- **Documentación oficial:**
  - Google "Flutter Widget Previewer" en docs.flutter.dev

- **Video tutoriales:**
  - YouTube: "Flutter Widget Previewer 3.2"

---

## 🎓 Siguiente Paso

Ahora que sabes usar Widget Previewer:

1. **Crea previews para todas tus pantallas principales**
2. **Usa previews durante el desarrollo**
3. **Acelera tu flujo de diseño UI**
4. **Colabora compartiendo screenshots del preview**

¡Eres un experto en Widget Previewer! 🚀✨

