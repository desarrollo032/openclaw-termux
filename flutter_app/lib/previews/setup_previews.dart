import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import '../providers/setup_provider.dart';
import '../screens/setup_wizard_screen.dart';

// Temas que coinciden con OpenClawApp (app.dart) para previews precisas.

const _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF6C63FF),
    onPrimary: Colors.white,
    secondary: Color(0xFF6C63FF),
    onSecondary: Colors.white,
    surface: Color(0xFFF8F9FE),
    onSurface: Color(0xFF0A0A0A),
    onSurfaceVariant: Color(0xFF6B7280),
    error: Color(0xFFEF4444),
    onError: Colors.white,
    outline: Color(0xFFE4E5F0),
    surfaceContainerLow: Color(0xFFF7F2FA),
    surfaceContainerHighest: Color(0xFFE6E0EB),
  ),
  scaffoldBackgroundColor: Color(0xFFF8F9FE),
);

const _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6C63FF),
    onPrimary: Colors.white,
    secondary: Color(0xFF6C63FF),
    onSecondary: Colors.white,
    surface: Color(0xFF16161E),
    onSurface: Colors.white,
    onSurfaceVariant: Color(0xFF9CA3AF),
    error: Color(0xFFEF4444),
    onError: Colors.white,
    outline: Color(0xFF2A2A3E),
    surfaceContainerLow: Color(0xFF1E1E2A),
    surfaceContainerHighest: Color(0xFF2A2A3E),
  ),
  scaffoldBackgroundColor: Color(0xFF0D0D12),
);

/// Preview del SetupWizardScreen en su estado inicial (pre-instalación).
/// Útil para identificar visualmente el rectángulo blanco.
/// Usa el tema real de la app (OpenClawApp) para coincidir con el dispositivo.
@Preview(name: 'SetupWizard - Pre-install')
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

/// Preview del SetupWizardScreen forzado a tema dark.
@Preview(name: 'SetupWizard - Pre-install (dark)')
Widget setupWizardPreInstallDark() {
  return ChangeNotifierProvider(
    create: (_) => SetupProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _darkTheme,
      darkTheme: _darkTheme,
      home: const SetupWizardScreen(),
    ),
  );
}

/// Aísla la tarjeta de pre-instalación para debug del rectángulo blanco.
@Preview(name: 'PreInstallInfo card solo')
Widget preInstallCardOnly() {
  // Tema claro con el gradiente actual
  const lightGradient = [
    Color(0xFFEBE6F8),
    Color(0xFFE2DCF5),
    Color(0xFFD8D1EE),
  ];

  return Material(
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: lightGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header simulado
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE4E5F0).withAlpha(160),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withAlpha(20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 22, color: Color(0xFF6C63FF)),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configurar OpenClaw',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Descargar Ubuntu, Node.js y OpenClaw',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ⚠️ Área del Expanded que antes contenía el rectángulo blanco
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE4E5F0).withAlpha(160),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6C63FF).withAlpha(120),
                                    const Color(0xFF6C63FF).withAlpha(60),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.download_for_offline_rounded,
                                size: 40,
                                color: Color(0xFF6C63FF),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Instalación del Entorno',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Este proceso descargará e instalará Ubuntu rootfs, '
                              'Node.js y OpenClaw en tu dispositivo.\n\n'
                              '• ~500 MB de descarga\n'
                              '• Conexión a internet requerida\n'
                              '• El proceso puede tomar 5-15 minutos',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _soloItem(
                              Icons.cloud_download_rounded,
                              'Ubuntu 24.04 Base',
                              'Sistema base ARM64',
                              const Color(0xFF6C63FF),
                            ),
                            const SizedBox(height: 8),
                            _soloItem(
                              Icons.javascript_rounded,
                              'Node.js 22',
                              'Entorno JavaScript',
                              const Color(0xFF22C55E),
                            ),
                            const SizedBox(height: 8),
                            _soloItem(
                              Icons.auto_awesome_rounded,
                              'OpenClaw',
                              'AI Gateway',
                              const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Iniciar Instalación'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _soloItem(IconData icon, String name, String desc, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withAlpha(12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(30)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              desc,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
