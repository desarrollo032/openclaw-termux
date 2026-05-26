import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';
import '../providers/gateway_provider.dart';
import '../providers/node_provider.dart';
import '../providers/setup_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/terminal_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/packages_screen.dart';
import '../screens/providers_screen.dart';
import '../screens/ssh_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/configure_screen.dart';
import '../screens/node_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/setup_wizard_screen.dart';

// =============================================================================
// TEMA COMPARTIDO
// =============================================================================

final ThemeData _lightTheme = ThemeData.light(useMaterial3: true);
final ThemeData _darkTheme = ThemeData.dark(useMaterial3: true);

// =============================================================================
// DASHBOARD
// =============================================================================

@Preview(name: 'Dashboard - Light')
Widget dashboardLight() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => GatewayProvider()),
      ChangeNotifierProvider(create: (_) => NodeProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      home: const DashboardScreen(),
    ),
  );
}

@Preview(name: 'Dashboard - Dark')
Widget dashboardDark() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => GatewayProvider()),
      ChangeNotifierProvider(create: (_) => NodeProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.dark,
      home: const DashboardScreen(),
    ),
  );
}

// =============================================================================
// TERMINAL
// =============================================================================

@Preview(name: 'Terminal - Light')
Widget terminalLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const TerminalScreen(),
  );
}

@Preview(name: 'Terminal - Dark')
Widget terminalDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const TerminalScreen(),
  );
}

// =============================================================================
// SETTINGS
// =============================================================================

@Preview(name: 'Settings - Light')
Widget settingsLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const SettingsScreen(),
  );
}

@Preview(name: 'Settings - Dark')
Widget settingsDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const SettingsScreen(),
  );
}

// =============================================================================
// PACKAGES
// =============================================================================

@Preview(name: 'Packages - Light')
Widget packagesLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const PackagesScreen(),
  );
}

@Preview(name: 'Packages - Dark')
Widget packagesDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const PackagesScreen(),
  );
}

// =============================================================================
// PROVIDERS (IA)
// =============================================================================

@Preview(name: 'Providers - Light')
Widget providersLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const ProvidersScreen(),
  );
}

@Preview(name: 'Providers - Dark')
Widget providersDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const ProvidersScreen(),
  );
}

// =============================================================================
// SSH
// =============================================================================

@Preview(name: 'SSH - Light')
Widget sshLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const SshScreen(),
  );
}

@Preview(name: 'SSH - Dark')
Widget sshDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const SshScreen(),
  );
}

// =============================================================================
// LOGS
// =============================================================================

@Preview(name: 'Logs - Light')
Widget logsLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const LogsScreen(),
  );
}

@Preview(name: 'Logs - Dark')
Widget logsDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const LogsScreen(),
  );
}

// =============================================================================
// CONFIGURE
// =============================================================================

@Preview(name: 'Configure - Light')
Widget configureLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const ConfigureScreen(),
  );
}

@Preview(name: 'Configure - Dark')
Widget configureDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const ConfigureScreen(),
  );
}

// =============================================================================
// NODE
// =============================================================================

@Preview(name: 'Node - Light')
Widget nodeLight() {
  return ChangeNotifierProvider(
    create: (_) => NodeProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      home: const NodeScreen(),
    ),
  );
}

@Preview(name: 'Node - Dark')
Widget nodeDark() {
  return ChangeNotifierProvider(
    create: (_) => NodeProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.dark,
      home: const NodeScreen(),
    ),
  );
}

// =============================================================================
// SPLASH
// =============================================================================

@Preview(name: 'Splash - Light')
Widget splashLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const SplashScreen(),
  );
}

@Preview(name: 'Splash - Dark')
Widget splashDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const SplashScreen(),
  );
}

// =============================================================================
// ONBOARDING
// =============================================================================

@Preview(name: 'Onboarding - Light')
Widget onboardingLight() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    home: const OnboardingScreen(),
  );
}

@Preview(name: 'Onboarding - Dark')
Widget onboardingDark() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _lightTheme,
    darkTheme: _darkTheme,
    themeMode: ThemeMode.dark,
    home: const OnboardingScreen(),
  );
}

// =============================================================================
// SETUP WIZARD
// =============================================================================

@Preview(name: 'Setup Wizard - Light')
Widget setupWizardLight() {
  return ChangeNotifierProvider(
    create: (_) => SetupProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      home: const SetupWizardScreen(),
    ),
  );
}

@Preview(name: 'Setup Wizard - Dark')
Widget setupWizardDark() {
  return ChangeNotifierProvider(
    create: (_) => SetupProvider(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.dark,
      home: const SetupWizardScreen(),
    ),
  );
}

