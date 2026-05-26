# 📋 Snippets Listos para Copiar - Widget Previewer

Copia y pega estos fragmentos en tus archivos de preview. Solo ajusta los nombres.

---

## 1️⃣ Preview Básico (el más simple)

```dart
@Preview(name: 'Mi Widget')
Widget miWidgetPreview() {
  return Material(
    child: Scaffold(
      appBar: AppBar(title: const Text('Mi Widget')),
      body: const Center(child: Text('¡Hola mundo!')),
    ),
  );
}
```

---

## 2️⃣ Preview con MaterialApp

```dart
@Preview(name: 'Mi Pantalla - Light')
Widget miPantallaPreviewLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.light(useMaterial3: true),
    home: const MiPantalla(),
  );
}

@Preview(name: 'Mi Pantalla - Dark')
Widget miPantallaPreviewDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    themeMode: ThemeMode.dark,
    home: const MiPantalla(),
  );
}
```

---

## 3️⃣ Preview con Provider

```dart
@Preview(name: 'Dashboard con Provider')
Widget dashboardWithProviderPreview() {
  return ChangeNotifierProvider(
    create: (_) => MyProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      home: const DashboardScreen(),
    ),
  );
}
```

---

## 4️⃣ Preview con MultiProvider

```dart
@Preview(name: 'Pantalla Completa')
Widget fullScreenPreview() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => GatewayProvider()),
      ChangeNotifierProvider(create: (_) => NodeProvider()),
      ChangeNotifierProvider(create: (_) => SetupProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const FullScreen(),
    ),
  );
}
```

---

## 5️⃣ Preview de Componente Aislado

```dart
@Preview(name: 'Botón Personalizado')
Widget customButtonPreview() {
  return Material(
    child: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.check),
          label: const Text('Guardar'),
        ),
      ),
    ),
  );
}
```

---

## 6️⃣ Preview con Tamaños Personalizados

```dart
@Preview(
  name: 'Mobile - Portrait',
  widgetWidth: 375,
  widgetHeight: 812,
)
Widget mobilePortraitPreview() {
  return MaterialApp(
    home: const MyScreen(),
  );
}

@Preview(
  name: 'Mobile - Landscape',
  widgetWidth: 812,
  widgetHeight: 375,
)
Widget mobileLandscapePreview() {
  return MaterialApp(
    home: const MyScreen(),
  );
}

@Preview(
  name: 'Tablet',
  widgetWidth: 768,
  widgetHeight: 1024,
)
Widget tabletPreview() {
  return MaterialApp(
    home: const MyScreen(),
  );
}
```

---

## 7️⃣ Preview con Temas Personalizados

```dart
final ThemeData _customLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF6C63FF),
    onPrimary: Colors.white,
    secondary: Color(0xFF6C63FF),
    onSecondary: Colors.white,
    surface: Color(0xFFF8F9FE),
    onSurface: Color(0xFF0A0A0A),
    error: Color(0xFFEF4444),
    onError: Colors.white,
    outline: Color(0xFFE4E5F0),
  ),
);

final ThemeData _customDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6C63FF),
    onPrimary: Colors.white,
    secondary: Color(0xFF6C63FF),
    onSecondary: Colors.white,
    surface: Color(0xFF16161E),
    onSurface: Colors.white,
    error: Color(0xFFEF4444),
    onError: Colors.white,
    outline: Color(0xFF2A2A3E),
  ),
);

@Preview(name: 'Con Tema Personalizado - Light')
Widget customThemeLightPreview() {
  return MaterialApp(
    theme: _customLightTheme,
    home: const MyScreen(),
  );
}

@Preview(name: 'Con Tema Personalizado - Dark')
Widget customThemeDarkPreview() {
  return MaterialApp(
    theme: _customLightTheme,
    darkTheme: _customDarkTheme,
    themeMode: ThemeMode.dark,
    home: const MyScreen(),
  );
}
```

---

## 8️⃣ Preview con Estados Simulados

```dart
@Preview(name: 'Lista Cargando')
Widget listLoadingPreview() {
  return Material(
    child: ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    ),
  );
}

@Preview(name: 'Lista con Datos')
Widget listWithDataPreview() {
  final items = ['Item 1', 'Item 2', 'Item 3', 'Item 4', 'Item 5'];
  
  return Material(
    child: ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(items[index]),
          leading: const Icon(Icons.check_circle),
          trailing: const Icon(Icons.chevron_right),
        );
      },
    ),
  );
}

@Preview(name: 'Lista Vacía')
Widget listEmptyPreview() {
  return Material(
    child: Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No hay elementos'),
            const SizedBox(height: 8),
            Text(
              'Intenta crear uno nuevo',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

## 9️⃣ Preview de Cards/Widgets Reutilizables

```dart
@Preview(name: 'Status Card - Activo')
Widget statusCardActivePreview() {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Estado: Activo'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tu servicio está funcionando correctamente',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

@Preview(name: 'Status Card - Inactivo')
Widget statusCardInactivePreview() {
  return Scaffold(
    backgroundColor: Colors.grey[100],
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Estado: Inactivo'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Haz clic para activar el servicio',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

---

## 🔟 Preview Completo (Ejemplo Real)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import '../providers/gateway_provider.dart';
import '../screens/gateway_screen.dart';

// Tema reutilizable
final ThemeData _appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6C63FF),
  ),
);

// Preview 1: Pantalla con datos
@Preview(name: 'Gateway - Con Datos')
Widget gatewayWithDataPreview() {
  return ChangeNotifierProvider(
    create: (_) => GatewayProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _appTheme,
      home: const GatewayScreen(),
    ),
  );
}

// Preview 2: Pantalla cargando
@Preview(name: 'Gateway - Cargando')
Widget gatewayLoadingPreview() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _appTheme,
    home: Scaffold(
      appBar: AppBar(title: const Text('Gateway')),
      body: const Center(child: CircularProgressIndicator()),
    ),
  );
}

// Preview 3: Pantalla con error
@Preview(name: 'Gateway - Error')
Widget gatewayErrorPreview() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _appTheme,
    home: Scaffold(
      appBar: AppBar(title: const Text('Gateway')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text('Error al cargar'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

## 📋 Cómo Usar Estos Snippets

1. **Copia el código que necesites**
2. **Pégalo en tu archivo de preview** (ej: `lib/previews/widget_previews.dart`)
3. **Ajusta los nombres** (reemplaza `MyWidget`, `MyProvider`, etc)
4. **Importa lo que necesites** al inicio del archivo
5. **¡Abre el preview en tu IDE!**

---

## 🎯 Tu Próxima Tarea

1. **Abre** `lib/previews/widget_previews.dart`
2. **Agrega más previews** usando estos snippets
3. **Prueba cada uno** en el panel Preview
4. **Edita y haz hot reload** para verlo al instante

¡Ahora tienes un arsenal completo de ejemplos! 🚀

