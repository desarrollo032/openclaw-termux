import 'dart:async';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';

class BootstrapService {
  final Dio _dio = Dio();

  void _updateSetupNotification(String text, {int progress = -1}) {
    try {
      NativeBridge.updateSetupNotification(text, progress: progress);
    } catch (_) {}
  }

  void _stopSetupService() {
    try {
      NativeBridge.stopSetupService();
    } catch (_) {}
  }

  Future<SetupState> checkStatus() async {
    try {
      final complete = await NativeBridge.isBootstrapComplete();
      if (complete) {
        return const SetupState(
          step: SetupStep.complete,
          progress: 1.0,
          message: 'Setup complete',
        );
      }
      return const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setup required',
      );
    } catch (e) {
      return SetupState(
        step: SetupStep.error,
        error: 'Failed to check status: $e',
      );
    }
  }

  void _log(void Function(String)? onLog, String msg) {
    if (onLog != null) onLog(msg);
  }

  Future<void> runFullSetup({
    required void Function(SetupState) onProgress,
    void Function(String)? onLog,
  }) async {
    try {
      // Start foreground service to keep app alive during setup
      try {
        await NativeBridge.startSetupService();
      } catch (_) {} // Non-fatal if service fails to start

      // Step 0: Setup directories
      onProgress(const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setting up directories...',
      ));
      _log(onLog, '[INFO] Preparando directorios del entorno...');
      _updateSetupNotification('Setting up directories...', progress: 2);
      // NativeBridge.ensureReady() is cached — only does real work once per 30s.
      await NativeBridge.ensureReady();

      // Step 1: Get arch + filesDir (now cached in NativeBridge)
      final arch = await NativeBridge.getArch();
      final filesDir = await NativeBridge.getFilesDir();
      final tarPath = '$filesDir/tmp/ubuntu-rootfs.tar.gz';
      final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

      // Step 2: Download rootfs AND Node.js in parallel — independent operations
      final rootfsUrl = AppConstants.getRootfsUrl(arch);
      final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);

      _log(onLog, '[DOWNLOAD] Iniciando descarga de Ubuntu rootfs...');
      _updateSetupNotification('Downloading Ubuntu rootfs...', progress: 5);
      onProgress(const SetupState(
        step: SetupStep.downloadingRootfs,
        progress: 0.0,
        message: 'Downloading Ubuntu rootfs...',
      ));

      // Run both downloads concurrently
      await Future.wait([
        _dio.download(
          rootfsUrl,
          tarPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final pct = received / total;
              final mb = (received / 1024 / 1024).toStringAsFixed(1);
              final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
              final notifProgress = 5 + (pct * 20).round();
              _updateSetupNotification('Downloading rootfs: $mb / $totalMb MB', progress: notifProgress);
              onProgress(SetupState(
                step: SetupStep.downloadingRootfs,
                progress: pct,
                message: 'Downloading rootfs: $mb MB / $totalMb MB',
              ));
              // Log download progress every ~5%
              final prevPct = (pct * 100).floor();
              if (prevPct % 5 == 0 || pct >= 1.0) {
                _log(onLog, '[DOWNLOAD] rootfs: $mb MB / $totalMb MB (${(pct * 100).toInt()}%)');
              }
            }
          },
        ),
        _dio.download(
          nodeTarUrl,
          nodeTarPath,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final mb = (received / 1024 / 1024).toStringAsFixed(1);
              _updateSetupNotification(
                'Downloading: rootfs ($mb MB Node.js)',
                progress: 30,
              );
            }
          },
        ),
      ]);

      _log(onLog, '[OK] Descargas completadas');
      onProgress(const SetupState(
        step: SetupStep.downloadingRootfs,
        progress: 1.0,
        message: 'Downloads complete',
      ));

      // Step 3: Extract rootfs (30-45%)
      _log(onLog, '[STEP] Extrayendo sistema base Ubuntu...');
      _updateSetupNotification('Extracting rootfs...', progress: 32);
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 0.0,
        message: 'Extracting rootfs (this takes a while)...',
      ));
      await NativeBridge.extractRootfs(tarPath);
      _log(onLog, '[OK] Sistema base extra\u00eddo correctamente');
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 1.0,
        message: 'Rootfs extracted',
      ));

      // Install bionic bypass + cwd-fix + node-wrapper BEFORE using node.
      _log(onLog, '[STEP] Instalando Bionic Bypass para compatibilidad...');
      await NativeBridge.installBionicBypass();
      _log(onLog, '[OK] Bionic Bypass instalado');

      // Step 4: Install Node.js (45-80%)
      // Fix permissions inside proot (Java extraction may miss execute bits)
      _log(onLog, '[STEP] Configurando permisos del sistema...');
      _updateSetupNotification('Fixing rootfs permissions...', progress: 45);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.0,
        message: 'Fixing rootfs permissions...',
      ));
      // Use timeout to prevent blocking indefinitely
      await _runInProotWithTimeout(
        'chmod -R 755 /usr/bin /usr/sbin /bin /sbin '
        '/usr/local/bin /usr/local/sbin 2>/dev/null; '
        'chmod -R +x /usr/lib/apt/ /usr/lib/dpkg/ /usr/libexec/ '
        '/var/lib/dpkg/info/ /usr/share/debconf/ 2>/dev/null; '
        'chmod 755 /lib/*/ld-linux-*.so* /usr/lib/*/ld-linux-*.so* 2>/dev/null; '
        'mkdir -p /var/lib/dpkg/updates /var/lib/dpkg/triggers; '
        'echo permissions_fixed',
        timeoutSeconds: 120,
      );

      // Install base packages via apt-get
      _log(onLog, '[STEP] Actualizando listas de paquetes...');
      _updateSetupNotification('Updating package lists...', progress: 48);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.1,
        message: 'Updating package lists...',
      ));
      try {
        await _runInProotWithTimeout('apt-get update -y', timeoutSeconds: 600);
        _log(onLog, '[OK] Paquetes actualizados');
      } catch (e) {
        _log(onLog, '[WARN] Error al actualizar paquetes, reintentando...');
        _updateSetupNotification('Updating packages (retrying)...', progress: 48);
        await _runInProotWithTimeout('apt-get update -y', timeoutSeconds: 600);
        _log(onLog, '[OK] Paquetes actualizados en el segundo intento');
      }

      _log(onLog, '[STEP] Instalando paquetes base (ca-certificates, git, python3, make, g++, curl, wget)...');
      _updateSetupNotification('Installing base packages...', progress: 52);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.15,
        message: 'Installing base packages...',
      ));
      // Pre-configure tzdata to avoid interactive prompts
      await _runInProotWithTimeout(
        'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
        'echo "Etc/UTC" > /etc/timezone',
        timeoutSeconds: 30,
      );
      await _runInProotWithTimeout(
        'apt-get install -y --no-install-recommends '
        'ca-certificates git python3 make g++ curl wget',
        timeoutSeconds: 900,
      );
      _log(onLog, '[OK] Paquetes base instalados');

      _log(onLog, '[STEP] Extrayendo Node.js...');
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.5,
        message: 'Extracting Node.js...',
      ));
      _updateSetupNotification('Extracting Node.js...', progress: 70);
      await NativeBridge.extractNodeTarball(nodeTarPath);
      _log(onLog, '[OK] Node.js extra\u00eddo');

      _log(onLog, '[STEP] Verificando Node.js...');
      _updateSetupNotification('Verifying Node.js...', progress: 78);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.75,
        message: 'Verifying Node.js...',
      ));
      const wrapper = '/root/.openclaw/node-wrapper.js';
      const nodeRun = 'node $wrapper';
      const npmCli = '/usr/local/lib/node_modules/npm/bin/npm-cli.js';
      await NativeBridge.runInProot(
        'node --version && $nodeRun $npmCli --version',
      );
      _log(onLog, '[OK] Node.js verificado correctamente');
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 1.0,
        message: 'Node.js installed',
      ));

      // Step 4: Install OpenClaw (80-98%)
      _log(onLog, '[STEP] Instalando OpenClaw (esto puede tomar varios minutos)...');
      _updateSetupNotification('Installing OpenClaw...', progress: 82);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.0,
        message: 'Installing OpenClaw (this may take a few minutes)...',
      ));
      await NativeBridge.runInProot(
        '$nodeRun $npmCli install -g openclaw',
        timeout: 1800,
      );
      _log(onLog, '[OK] OpenClaw instalado correctamente');

      _log(onLog, '[STEP] Creando wrappers de binarios...');
      _updateSetupNotification('Creating bin wrappers...', progress: 92);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.7,
        message: 'Creating bin wrappers...',
      ));
      await NativeBridge.createBinWrappers('openclaw');
      _log(onLog, '[OK] Wrappers creados');

      _log(onLog, '[STEP] Verificando OpenClaw...');
      _updateSetupNotification('Verifying OpenClaw...', progress: 96);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.9,
        message: 'Verifying OpenClaw...',
      ));
      await NativeBridge.runInProot('openclaw --version || echo openclaw_installed');
      _log(onLog, '[OK] OpenClaw verificado');
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 1.0,
        message: 'OpenClaw installed',
      ));

      // Step 5: Bionic Bypass already installed (before node verification)
      _log(onLog, '[OK] Bionic Bypass configurado');
      _updateSetupNotification('Setup complete!', progress: 100);
      onProgress(const SetupState(
        step: SetupStep.configuringBypass,
        progress: 1.0,
        message: 'Bionic Bypass configured',
      ));

      // Done
      _log(onLog, '[OK] Instalaci\u00f3n completada exitosamente!');
      _stopSetupService();
      onProgress(const SetupState(
        step: SetupStep.complete,
        progress: 1.0,
        message: 'Setup complete! Ready to start the gateway.',
      ));
    } on DioException catch (e) {
      _log(onLog, '[ERR] Error de descarga: ${e.message}');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Download failed: ${e.message}. Check your internet connection.',
      ));
    } catch (e) {
      _log(onLog, '[ERR] Error de instalaci\u00f3n: $e');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Setup failed: $e',
      ));
    }
  }

  /// Run a command in proot with a Dart-side timeout to prevent hanging.
  Future<String> _runInProotWithTimeout(
    String command, {
    int timeoutSeconds = 300,
  }) async {
    return NativeBridge.runInProot(command, timeout: timeoutSeconds)
        .timeout(
          Duration(seconds: timeoutSeconds + 30),
          onTimeout: () => throw TimeoutException(
            'Command timed out after ${timeoutSeconds}s: ${command.substring(0, command.length.clamp(0, 80))}',
          ),
        );
  }
}
