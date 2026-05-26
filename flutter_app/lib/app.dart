import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'design/tokens.dart';
import 'providers/setup_provider.dart';
import 'providers/gateway_provider.dart';
import 'providers/node_provider.dart';
import 'screens/splash_screen.dart';

class OpenClawApp extends StatelessWidget {
  const OpenClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SetupProvider()),
        ChangeNotifierProvider(create: (_) => GatewayProvider()),
        ChangeNotifierProxyProvider<GatewayProvider, NodeProvider>(
          create: (_) => NodeProvider(),
          update: (_, gatewayProvider, nodeProvider) {
            nodeProvider?.onGatewayStateChanged(gatewayProvider.state);
            return nodeProvider ?? NodeProvider();
          },
        ),
      ],
      child: MaterialApp(
        title: 'OpenClaw',
        debugShowCheckedModeBanner: false,
        theme: buildOpenClawTheme(isDark: false),
        darkTheme: buildOpenClawTheme(isDark: true),
        themeMode: ThemeMode.system,
        home: const SplashScreen(),
      ),
    );
  }

  /// Transición de ruta — deslizamiento con fade
  static Route<T> fadeUpRoute<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: AppDurations.pageTransition,
    );
  }
}
