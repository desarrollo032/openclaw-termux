import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/native_bridge.dart';
import '../services/preferences_service.dart';
import 'setup_wizard_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'Loading...';
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
    _checkAndRoute();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRoute() async {
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      setState(() => _status = 'Checking setup...');

      try { await NativeBridge.setupDirs(); } catch (_) {}
      try { await NativeBridge.writeResolv(); } catch (_) {}

      try {
        final filesDir = await NativeBridge.getFilesDir();
        const resolvContent = 'nameserver 8.8.8.8\nnameserver 8.8.4.4\n';
        final configDir = '$filesDir/config';
        final resolvFile = File('$configDir/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory(configDir).createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
        final rootfsResolv = File('$filesDir/rootfs/ubuntu/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}

      final prefs = PreferencesService();
      await prefs.init();

      try {
        final oldVersion = prefs.lastAppVersion;
        if (oldVersion != null && oldVersion != AppConstants.version) {
          final hasPermission = await NativeBridge.hasStoragePermission();
          if (hasPermission) {
            final sdcard = await NativeBridge.getExternalStoragePath();
            final downloadDir = Directory('$sdcard/Download');
            if (!await downloadDir.exists()) {
              await downloadDir.create(recursive: true);
            }
            final snapshotPath = '$sdcard/Download/openclaw-snapshot-$oldVersion.json';
            final openclawJson = await NativeBridge.readRootfsFile('root/.openclaw/openclaw.json');
            final snapshot = {
              'version': oldVersion,
              'timestamp': DateTime.now().toIso8601String(),
              'openclawConfig': openclawJson,
              'dashboardUrl': prefs.dashboardUrl,
              'autoStart': prefs.autoStartGateway,
              'nodeEnabled': prefs.nodeEnabled,
              'nodeDeviceToken': prefs.nodeDeviceToken,
              'nodeGatewayHost': prefs.nodeGatewayHost,
              'nodeGatewayPort': prefs.nodeGatewayPort,
              'nodeGatewayToken': prefs.nodeGatewayToken,
            };
            await File(snapshotPath).writeAsString(
              const JsonEncoder.withIndent('  ').convert(snapshot),
            );
          }
        }
        prefs.lastAppVersion = AppConstants.version;
      } catch (_) {}

      bool setupComplete;
      try {
        setupComplete = await NativeBridge.isBootstrapComplete();
      } catch (_) {
        setupComplete = false;
      }

      if (!setupComplete) {
        try {
          final status = await NativeBridge.getBootstrapStatus();
          final rootfsOk = status['rootfsExists'] == true;
          final bashOk = status['binBashExists'] == true;
          final nodeOk = status['nodeInstalled'] == true;
          final openclawOk = status['openclawInstalled'] == true;
          final bypassOk = status['bypassInstalled'] == true;

          if (rootfsOk && bashOk) {
            if (!bypassOk) {
              setState(() => _status = 'Repairing bypass...');
              await NativeBridge.installBionicBypass();
            }
            if (!nodeOk) {
              setState(() => _status = 'Reinstalling Node.js...');
              try {
                final arch = await NativeBridge.getArch();
                final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);
                final filesDir = await NativeBridge.getFilesDir();
                final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';
                final dio = Dio();
                await dio.download(nodeTarUrl, nodeTarPath);
                await NativeBridge.extractNodeTarball(nodeTarPath);
              } catch (_) {}
            }
            if (!openclawOk && nodeOk) {
              setState(() => _status = 'Reinstalling OpenClaw...');
              try {
                const wrapper = '/root/.openclaw/node-wrapper.js';
                const nodeRun = 'node $wrapper';
                const npmCli = '/usr/local/lib/node_modules/npm/bin/npm-cli.js';
                await NativeBridge.runInProot(
                  '$nodeRun $npmCli install -g openclaw',
                  timeout: 1800,
                );
                await NativeBridge.createBinWrappers('openclaw');
              } catch (_) {}
            }
            setupComplete = await NativeBridge.isBootstrapComplete();
          }
        } catch (_) {}
      }

      if (!mounted) return;

      if (setupComplete) {
        prefs.setupComplete = true;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DashboardScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const SetupWizardScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow effect
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(30),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.bolt,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'OpenClaw',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI Gateway for Android',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${AppConstants.authorName} · ${AppConstants.orgName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _status,
                    key: ValueKey(_status),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
