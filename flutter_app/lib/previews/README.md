# 🎨 Widget Previews - Guía Rápida

## ⚡ Inicio Rápido (30 segundos)

### Paso 1: Abre un archivo de preview
```
lib/previews/setup_previews.dart
lib/previews/widget_previews.dart
```

### Paso 2: Busca el icono "Preview"
En el lado derecho del editor (icono de dispositivo), haz clic ahí.

### Paso 3: ¡Listo!
Verás tu widget renderizarse en tiempo real. Cualquier cambio se actualiza al guardar (Hot Reload).

---

## 📁 Estructura Actual

| Archivo | Contenido | Previews |
|---------|-----------|----------|
| `setup_previews.dart` | SetupWizard screen | 2 (Light + Dark) |
| `widget_previews.dart` | Dashboard, Terminal, Cards | 6+ (Light + Dark) |

---

## 🎯 Cómo Crear Tus Propios Previews

### Paso 1: Importa
```dart
import 'package:flutter/widget_previews.dart';
```

### Paso 2: Crea una función widget con @Preview
```dart
@Preview(name: 'Mi Pantalla - Light')
Widget miPantallaPreview() {
  return MaterialApp(
    theme: ThemeData.light(),
    home: const MiPantalla(),
  );
}
```

### Paso 3: ¡Listo!
El preview aparecerá automáticamente en el panel.

---

## 💡 Tips Pro

✅ **Agrupa previews por pantalla**
```dart
// Setup previews
@Preview(name: 'Setup - Light')
Widget setupLight() { ... }

@Preview(name: 'Setup - Dark')
Widget setupDark() { ... }

// Dashboard previews
@Preview(name: 'Dashboard - Light')
Widget dashboardLight() { ... }

@Preview(name: 'Dashboard - Dark')
Widget dashboardDark() { ... }
```

✅ **Incluye providers que necesita tu widget**
```dart
@Preview(name: 'Dashboard')
Widget dashboardPreview() {
  return ChangeNotifierProvider(
    create: (_) => DashboardProvider(),
    child: MaterialApp(
      home: const DashboardScreen(),
    ),
  );
}
```

✅ **Reutiliza temas para consistencia**
```dart
final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme(...),
);

@Preview(name: 'Widget - Light')
Widget widgetPreview() {
  return MaterialApp(
    theme: _lightTheme,
    home: const MyWidget(),
  );
}
```

---

## 🔧 Controles en el Panel Preview

- 📱 **Device Selector**: Elige dispositivo (Pixel 5, iPhone 14, etc)
- 🌙 **Theme Toggle**: Cambia entre light ↔ dark
- 📏 **Size**: Ajusta ancho/alto del preview
- 🔄 **Refresh**: Fuerza refresco
- 📐 **Show Grid**: Muestra rejilla de alineación
- 🔍 **Zoom**: Amplía/reduce el preview

---

## 🎬 Video Tutorial (si necesitas)

Busca "Flutter Widget Previewer" en YouTube para ver demos interactivas.

---

## ❓ Preguntas Frecuentes

**P: ¿Por qué no veo el botón Preview?**
R: Asegúrate que:
1. Tu función está decorada con `@Preview`
2. Tienes Flutter 3.2+ (`flutter --version`)
3. Reinicia el IDE

**P: ¿Puedo previewear múltiples tamaños de dispositivo?**
R: Sí, crea múltiples previews:
```dart
@Preview(name: 'Mobile', widgetWidth: 375, widgetHeight: 812)
Widget preview1() { ... }

@Preview(name: 'Tablet', widgetWidth: 768, widgetHeight: 1024)
Widget preview2() { ... }
```

**P: ¿Funciona con hot reload?**
R: ¡Sí! Edita el código, guarda (Ctrl+S), y ¡verás los cambios instantáneamente!

---

## 📚 Más Información

- [Flutter Docs - Widget Preview](https://flutter.dev/docs/development/ui/widgets/previewer)
- `WIDGET_PREVIEWER_GUIDE.md` (guía completa en el raíz del proyecto)

---

**¡Ahora estás listo para usar Widget Previewer! 🚀**

