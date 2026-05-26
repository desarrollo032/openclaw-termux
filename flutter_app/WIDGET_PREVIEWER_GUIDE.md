# 🎨 Guía: Flutter Widget Previewer

## 📚 Tabla de Contenidos
1. [Qué es Widget Previewer](#qué-es-widget-previewer)
2. [Cómo activarlo](#cómo-activarlo)
3. [Sintaxis y configuración](#sintaxis-y-configuración)
4. [Mejores prácticas](#mejores-prácticas)
5. [Atajos de teclado](#atajos-de-teclado)

---

## Qué es Widget Previewer

**Flutter Widget Previewer** es una característica de Flutter 3.2+ que te permite:
- ✅ Ver tus widgets renderizados en tiempo real sin ejecutar la app completa
- ✅ Cambiar temas (light/dark) al vuelo
- ✅ Probar diferentes tamaños de pantalla
- ✅ Depurar UI sin recompilar toda la aplicación
- ✅ Iterar más rápido en el diseño

---

## Cómo Activarlo

### En Android Studio / IntelliJ IDEA

1. **Abre un archivo con `@Preview`**
   - Por ejemplo: `lib/previews/setup_previews.dart`

2. **Busca el panel "Preview"**
   - En el lado derecho del editor, verás un icono de dispositivo
   - Si no lo ves, ve a: **Tools → Flutter → Show Widget Previewer**

3. **Haz clic en el preview**
   - Se abrirá una ventana con tu widget renderizado
   - Cualquier cambio que hagas se actualiza automáticamente (Hot Reload)

### En VS Code

1. **Instala la extensión Dart**
2. **Abre un archivo con `@Preview`**
3. **Busca la opción "Run Preview" encima de la función anotada**
4. **Haz clic y verá el preview en la ventana emergente**

---

## Sintaxis y Configuración

### Estructura Básica

```dart
import 'package:flutter/widget_previews.dart';

@Preview(name: 'Mi Widget - Light Theme')
Widget myWidgetPreview() {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: const Center(child: Text('Hola!')),
    ),
  );
}
```

### Parámetros de @Preview

| Parámetro | Descripción | Ejemplo |
|-----------|-------------|---------|
| `name` | Nombre mostrado en el panel | `'Dashboard - Light'` |
| `widgetHeight` (opcional) | Altura personalizada | `800` |
| `widgetWidth` (opcional) | Ancho personalizado | `360` |

### Ejemplo Completo

```dart
@Preview(
  name: 'Dashboard - Portrait',
  widgetWidth: 360,
  widgetHeight: 800,
)
Widget dashboardPreview() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DashboardProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const DashboardScreen(),
    ),
  );
}
```

---

## Mejores Prácticas

### 1. **Agrupa previews por pantalla**
```dart
// setup_previews.dart
@Preview(name: 'Setup - Light')
Widget setupPreviewLight() { ... }

@Preview(name: 'Setup - Dark')
Widget setupPreviewDark() { ... }
```

### 2. **Incluye providers necesarios**
```dart
@Preview(name: 'Dashboard')
Widget dashboardPreview() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => GatewayProvider()),
    ],
    child: MaterialApp(
      home: const DashboardScreen(),
    ),
  );
}
```

### 3. **Reutiliza temas**
```dart
final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme(...),
);

final ThemeData _darkTheme = ThemeData(...);

@Preview(name: 'Widget - Light')
Widget previewLight() {
  return MaterialApp(
    theme: _lightTheme,
    home: const MyWidget(),
  );
}
```

### 4. **Desactiva elementos de debug**
```dart
MaterialApp(
  debugShowCheckedModeBanner: false,  // ✅ Recomendado
  home: const MyScreen(),
)
```

### 5. **Preview de componentes aislados**
```dart
@Preview(name: 'Button Component')
Widget buttonPreview() {
  return Material(
    child: Center(
      child: FilledButton(
        onPressed: () {},
        child: const Text('Click me'),
      ),
    ),
  );
}
```

---

## Características del Panel Preview

### Controles Disponibles

- 📱 **Device Selector**: Cambia entre diferentes dispositivos
- 🌙 **Theme Toggle**: Cambia entre light/dark
- 🔄 **Refresh**: Recarga el preview
- 📏 **Size**: Ajusta el tamaño del widget
- 📐 **Grid**: Muestra guía de alineación
- 🔍 **Zoom**: Zoom in/out

---

## Atajos de Teclado

| Atajo | Acción |
|-------|--------|
| `Ctrl + F5` (Windows/Linux) | Refresca preview |
| `Cmd + R` (macOS) | Refresca preview |
| `Ctrl + \` (Windows/Linux) | Abre/cierra panel preview |

---

## Troubleshooting

### ❌ No veo el botón de Preview

**Solución:**
```bash
# 1. Verifica que tienes Flutter 3.2+
flutter --version

# 2. Ejecuta pub get
flutter pub get

# 3. Reinicia tu IDE
```

### ❌ El provider no inicializa correctamente

**Solución:** Envuelve con `ChangeNotifierProvider`:
```dart
@Preview(name: 'My Screen')
Widget myScreenPreview() {
  return ChangeNotifierProvider(
    create: (_) => MyProvider(),
    child: MaterialApp(
      home: const MyScreen(),
    ),
  );
}
```

### ❌ Los temas no se aplican

**Solución:** Asegúrate que `MaterialApp` tenga los temas:
```dart
MaterialApp(
  theme: ThemeData.light(),
  darkTheme: ThemeData.dark(),
  themeMode: ThemeMode.system,
  home: const MyWidget(),
)
```

---

## Ejemplos en tu Proyecto

Ya tienes previews listos en:
- ✅ `lib/previews/setup_previews.dart` - SetupWizard
- ✅ `lib/previews/widget_previews.dart` - Dashboard, Terminal, Cards

### Cómo acceder:
1. Abre cualquier archivo `.dart` en la carpeta `previews`
2. Busca el icono 🎨 "Preview" en el editor
3. ¡Disfruta viendo tus widgets en tiempo real!

---

## 🚀 Próximos Pasos

1. **Abre `lib/previews/setup_previews.dart`** en tu IDE
2. **Haz clic en el botón Preview** (icono de dispositivo)
3. **Prueba cambiar de tema** (light ↔ dark)
4. **Edita algún widget** y observa el hot reload en tiempo real
5. **Crea más previews** para tus pantallas principales

¡Ahora tienes acceso rápido a vistas previas de todos tus widgets! 🎉

