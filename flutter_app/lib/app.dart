import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'design/tokens.dart';
import 'providers/setup_provider.dart';
import 'providers/gateway_provider.dart';
import 'providers/node_provider.dart';
import 'screens/splash_screen.dart';
import 'widgets/orb/constellation_banner_controller.dart';

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
        home: const _BannerInitializer(
          child: SplashScreen(),
        ),
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

/// Small stateful widget that initializes the [ConstellationBannerController]
/// with a [BuildContext] that is inside the MaterialApp's Navigator tree.
/// This ensures [Overlay.of] works correctly when showing the banner.
class _BannerInitializer extends StatefulWidget {
  final Widget child;
  const _BannerInitializer({required this.child});

  @override
  State<_BannerInitializer> createState() => _BannerInitializerState();
}

class _BannerInitializerState extends State<_BannerInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConstellationBannerController.instance.init(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
