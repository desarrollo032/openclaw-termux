import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import '../providers/setup_provider.dart';
import '../screens/setup_wizard_screen.dart';

/// Preview del SetupWizardScreen en su estado inicial (pre-instalación).
/// Útil para identificar visualmente el rectángulo blanco.
@Preview(name: 'SetupWizard - Pre-install')
Widget setupWizardPreInstall() {
  return ChangeNotifierProvider(
    create: (_) => SetupProvider(),
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SetupWizardScreen(),
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
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          onPrimary: Colors.white,
          surface: Color(0xFF16161E),
          onSurface: Colors.white,
          onSurfaceVariant: Color(0xFF9CA3AF),
          error: Color(0xFFEF4444),
          onError: Colors.white,
          outline: Color(0xFF2A2A3E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
      ),
      home: const SetupWizardScreen(),
    ),
  );
}
