import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../models/setup_state.dart';
import 'native_bridge.dart';

/// Maximum retry attempts for recoverable proot commands.
const _maxRetries = 3;

class BootstrapService {
  final Dio _dio = Dio();

  /// Tracks whether pre-flight dpkg recovery has already been attempted
  /// within the current [runFullSetup] call to avoid redundant checks.
  bool _recoveryAttempted = false;


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

  // ── Recovery-aware proot execution ────────────────────────────────────────

  /// Run a command in proot with automatic dpkg/apt recovery and retry.
  ///
  /// The Kotlin [ProcessManager.runInProotWithRecovery] handles low-level
  /// dpkg lock cleanup, `dpkg --configure -a`, and `apt --fix-broken install`.
  /// This Dart wrapper adds:
  /// - [PlatformException] → [PROOT_ERROR] mapping
  /// - Timeout safety
  /// - Pre-flight recovery step before apt commands
  /// - Detailed logging
  Future<String> _runProotWithRecovery({
    required String command,
    required String stepLabel,
    int timeoutSeconds = 300,
    void Function(String)? onLog,
    bool isAptCommand = false,
  }) async {
    _log(onLog, '[STEP] $stepLabel');

    // Pre-flight recovery for apt/dpkg commands — only if not already done
    if (isAptCommand && !_recoveryAttempted) {
      await _runPreFlightRecovery(onLog: onLog);
    }

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final result = await NativeBridge.runInProot(command, timeout: timeoutSeconds)
            .timeout(
              Duration(seconds: timeoutSeconds + 30),
              onTimeout: () => throw TimeoutException(
                'Command timed out after ${timeoutSeconds}s',
              ),
            );
        _log(onLog, '[OK] $stepLabel');
        return result;
      } on PlatformException catch (e) {
        final msg = e.message ?? 'Unknown proot error';
        final isDpkgError = _isDpkgInterruptionError(msg);

        if (attempt < _maxRetries && isDpkgError) {
          _log(onLog, '[WARN] Intento $attempt/$_maxRetries — recuperando dpkg/apt...');
          await _runDpkgRecovery(onLog: onLog);
          continue;
        }

        if (isDpkgError) {
          _log(onLog, '[ERR] $stepLabel falló tras $_maxRetries intentos');
          _log(onLog, '[ERR] Entorno corrupto — se requiere reinstalación');
          throw _CorruptEnvironmentException(msg);
        }

        _log(onLog, '[ERR] $stepLabel: $msg');
        rethrow;
      } catch (e) {
        _log(onLog, '[ERR] $stepLabel: $e');

        if (attempt < _maxRetries && e is TimeoutException) {
          _log(onLog, '[WARN] Intento $attempt/$_maxRetries — timeout, reintentando...');
          continue;
        }
        rethrow;
      }
    }

    throw const _CorruptEnvironmentException(
      'Command failed after $_maxRetries attempts',
    );
  }

  /// Detect dpkg interruption / exit code 100 errors.
  bool _isDpkgInterruptionError(String message) {
    final msg = message.toLowerCase();
    return msg.contains('dpkg was interrupted') ||
        msg.contains('exit code 100') ||
        msg.contains('dpkg --configure -a') ||
        msg.contains('could not exec dpkg') ||
        msg.contains('unable to lock the administration directory') ||
        msg.contains('could not get lock') ||
        msg.contains('package is in a very bad inconsistent state') ||
        msg.contains('sub-process /usr/bin/dpkg returned an error code') ||
        msg.contains('status database area is locked');
  }

  /// Quick pre-flight check before apt commands.
  /// Runs dpkg --audit and recovers if needed.
  /// After execution, sets [_recoveryAttempted] to true so subsequent
  /// calls in the same [runFullSetup] invocation are skipped.
  Future<void> _runPreFlightRecovery({
    void Function(String)? onLog,
  }) async {
    if (_recoveryAttempted) {
      _log(onLog, '[STEP] dpkg ya verificado — saltando...');
      return;
    }

    _log(onLog, '[STEP] Verificando estado de dpkg...');
    try {
      final audit = await NativeBridge.runInProot(
        'dpkg --audit 2>&1 || echo audit_failed',
        timeout: 60,
      );
      if (audit.contains('problem') ||
          audit.contains('error') ||
          audit.contains('interrupted') ||
          audit.contains('inconsistent')) {
        _log(onLog, '[WARN] dpkg reporta paquetes interrumpidos — recuperando...');
        await _runDpkgRecovery(onLog: onLog);
      } else {
        _log(onLog, '[OK] dpkg en estado limpio');
      }
    } catch (e) {
      _log(onLog, '[WARN] No se pudo auditar dpkg ($e) — continuando...');
    }

    _recoveryAttempted = true;
  }

  /// Run dpkg/apt recovery sequence.
  ///
  /// 1. Remove lock files
  /// 2. dpkg --configure -a (reconfigure interrupted packages)
  /// 3. apt --fix-broken install -y (fix broken dependencies)
  /// 4. apt update && apt upgrade -y (refresh package state)
  Future<void> _runDpkgRecovery({
    void Function(String)? onLog,
  }) async {
    _log(onLog, '[STEP] Modo recuperación activado');

    // Step 1: Lock cleanup
    _log(onLog, '[STEP] Eliminando locks de dpkg/apt...');
    const lockCleanup = [
      '/bin/rm -f /var/lib/dpkg/lock-frontend 2>/dev/null',
      '/bin/rm -f /var/lib/dpkg/lock 2>/dev/null',
      '/bin/rm -f /var/cache/apt/archives/lock 2>/dev/null',
      '/bin/rm -f /var/lib/apt/lists/lock 2>/dev/null',
    ];
    for (final cmd in lockCleanup) {
      try {
        await _runProotSilent(cmd, timeoutSeconds: 15);
      } catch (_) {}
    }
    _log(onLog, '[OK] Locks eliminados');

    // Step 2: Configure interrupted packages
    _log(onLog, '[STEP] Reconfigurando paquetes interrumpidos...');
    try {
      await _runProotSilent(
        'DEBIAN_FRONTEND=noninteractive dpkg --configure -a',
        timeoutSeconds: 300,
      );
      _log(onLog, '[OK] dpkg --configure -a completado');
    } catch (e) {
      _log(onLog, '[WARN] dpkg --configure -a tuvo errores ($e) — continuando...');
    }

    // Step 3: Fix broken dependencies
    _log(onLog, '[STEP] Reparando dependencias rotas...');
    try {
      await _runProotSilent(
        'DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -q 2>/dev/null',
        timeoutSeconds: 300,
      );
      _log(onLog, '[OK] apt --fix-broken completado');
    } catch (e) {
      _log(onLog, '[WARN] apt --fix-broken tuvo errores ($e) — continuando...');
    }

    // Step 4: Update package lists & upgrade (user requirement #2)
    _log(onLog, '[STEP] Actualizando listas de paquetes...');
    try {
      await _runProotSilent(
        'DEBIAN_FRONTEND=noninteractive apt update -y -q 2>/dev/null',
        timeoutSeconds: 300,
      );
      _log(onLog, '[OK] apt update completado');
    } catch (e) {
      _log(onLog, '[WARN] apt update tuvo errores ($e) — continuando...');
    }

    _log(onLog, '[STEP] Actualizando paquetes existentes...');
    try {
      await _runProotSilent(
        'DEBIAN_FRONTEND=noninteractive apt upgrade -y -q 2>/dev/null',
        timeoutSeconds: 300,
      );
      _log(onLog, '[OK] apt upgrade completado');
    } catch (e) {
      _log(onLog, '[WARN] apt upgrade tuvo errores ($e) — continuando...');
    }

    _log(onLog, '[OK] Recuperación completada');
  }

  /// Fetch the SHA256 hash for a rootfs tarball from Ubuntu's official SHA256SUMS.
  ///
  /// This ensures verification always works even when Ubuntu updates the tarball,
  /// because the hash is fetched live from the mirror at install time.
  Future<String?> _fetchSha256Sum(
    String tarballUrl, {
    void Function(String)? onLog,
  }) async {
    try {
      // Extract filename (e.g. ubuntu-base-24.04.4-base-arm64.tar.gz)
      final filename = tarballUrl.split('/').last;
      if (filename.isEmpty) return null;

      // Derive SHA256SUMS URL (same directory as the tarball)
      final baseUrl = tarballUrl.substring(
        0, tarballUrl.length - filename.length,
      );
      final sha256sumsUrl = '${baseUrl}SHA256SUMS';

      _log(onLog, '[STEP] Obteniendo hash SHA256 desde SHA256SUMS...');
      final response = await _dio.get<String>(
        sha256sumsUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data == null) {
        _log(onLog, '[WARN] SHA256SUMS response vacío');
        return null;
      }
      final lines = data.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        // Format: "<hash>  *<filename>" or "<hash>  <filename>"
        if (trimmed.contains(filename)) {
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            _log(onLog, '[OK] Hash encontrado para $filename');
            return parts[0];
          }
        }
      }

      _log(onLog, '[WARN] No se encontró $filename en SHA256SUMS');
      return null;
    } catch (e) {
      _log(onLog, '[WARN] Error al obtener SHA256SUMS ($e) — continuando sin verificación');
      return null;
    }
  }

  /// Run a proot command silently (no log output).
  Future<String> _runProotSilent(String command, {int timeoutSeconds = 60}) async {
    return NativeBridge.runInProot(command, timeout: timeoutSeconds).timeout(
      Duration(seconds: timeoutSeconds + 15),
      onTimeout: () => throw TimeoutException('Silent proot command timed out'),
    );
  }

  /// Run a command in proot with a Dart-side timeout.
  /// Preferred for non-apt/dpkg commands that don't need recovery.
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

  // ── Full setup orchestration ──────────────────────────────────────────────

  Future<void> runFullSetup({
    required void Function(SetupState) onProgress,
    void Function(String)? onLog,
  }) async {
    // Reset recovery flag for a fresh run
    _recoveryAttempted = false;

    try {
      // Start foreground service to keep app alive during setup
      try {
        await NativeBridge.startSetupService();
      } catch (_) {}

      // ===================================================================
      // Step 0: Setup directories
      // ===================================================================
      _log(onLog, '[STEP] Preparando directorios del entorno...');
      onProgress(const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Setting up directories...',
      ));
      _updateSetupNotification('Setting up directories...', progress: 2);
      await NativeBridge.ensureReady();
      _log(onLog, '[OK] Directorios listos');

      // ===================================================================
      // Get arch + filesDir
      // ===================================================================
      final arch = await NativeBridge.getArch();
      final filesDir = await NativeBridge.getFilesDir();
      final tarPath = '$filesDir/tmp/ubuntu-rootfs.tar.gz';
      final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

      // ===================================================================
      // Step 1: Download rootfs AND Node.js in parallel
      // ===================================================================
      final rootfsUrl = AppConstants.getRootfsUrl(arch);
      final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);

      _log(onLog, '[DOWNLOAD] Iniciando descarga de Ubuntu rootfs...');
      _updateSetupNotification('Downloading Ubuntu rootfs...', progress: 5);
      onProgress(const SetupState(
        step: SetupStep.downloadingRootfs,
        progress: 0.0,
        message: 'Downloading Ubuntu rootfs...',
      ));

      // Throttle helpers to avoid excessive UI/log updates during download
      int lastLoggedDownloadPct = -10; // ensure first threshold fires
      String lastNotifMb = '';
      DateTime lastOnProgressUpdate = DateTime(2000);
      int lastOnProgressPct = -10;


      await Future.wait([
        _dio.download(
          rootfsUrl,
          tarPath,
          onReceiveProgress: (received, total) {
            if (total <= 0) return;

            final pct = received / total;
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            final pctInt = (pct * 100).floor();

            // ── Log: only when crossing a new 5% threshold ──
            if (pctInt >= lastLoggedDownloadPct + 5 || pct >= 1.0) {
              lastLoggedDownloadPct = pctInt;
              _log(onLog,
                  '[DOWNLOAD] rootfs: $mb MB / $totalMb MB (${(pct * 100).toInt()}%)');
            }

            // ── Notification: only when MB value changes ──
            if (mb != lastNotifMb) {
              lastNotifMb = mb;
              final notifProgress = 5 + (pct * 20).round();
              _updateSetupNotification(
                'Downloading rootfs: $mb / $totalMb MB',
                progress: notifProgress,
              );
            }

            // ── UI state: at most every 500ms or every 10% threshold ──
            final now = DateTime.now();
            if (now.difference(lastOnProgressUpdate).inMilliseconds >= 500 ||
                pctInt >= lastOnProgressPct + 10) {
              lastOnProgressUpdate = now;
              lastOnProgressPct = pctInt;
              onProgress(SetupState(
                step: SetupStep.downloadingRootfs,
                progress: pct,
                message: 'Downloading rootfs: $mb MB / $totalMb MB',
              ));
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

      // ── Final 100% state ──
      _log(onLog, '[DOWNLOAD] rootfs: 100% completado');
      _log(onLog, '[OK] Descargas completadas');
      onProgress(const SetupState(
        step: SetupStep.downloadingRootfs,
        progress: 1.0,
        message: 'Downloads complete',
      ));

      // ===================================================================
      // Step 2: Extract rootfs
      // ===================================================================
      _log(onLog, '[STEP] Extrayendo sistema base Ubuntu...');
      _updateSetupNotification('Extracting rootfs...', progress: 32);
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 0.0,
        message: 'Extracting rootfs (this takes a while)...',
      ));
      
      final sha256Hash = await _fetchSha256Sum(rootfsUrl, onLog: onLog);
      if (sha256Hash != null) {
        _log(onLog, '[OK] Hash SHA256 obtenido dinámicamente desde SHA256SUMS');
      } else {
        _log(onLog, '[WARN] No se pudo obtener hash SHA256 — continuando sin verificación');
      }
      await NativeBridge.extractRootfs(tarPath, sha256: sha256Hash);
      
      _log(onLog, '[OK] Sistema base extraído y verificado');
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 1.0,
        message: 'Rootfs extracted',
      ));

      // ===================================================================
      // Step 2b: Install bionic bypass (before using apt/node)
      // ===================================================================
      _log(onLog, '[STEP] Instalando Bionic Bypass para compatibilidad...');
      await NativeBridge.installBionicBypass();
      _log(onLog, '[OK] Bionic Bypass instalado');

      // ===================================================================
      // Step 3: Fix permissions + pre-flight dpkg recovery
      // ===================================================================
      _log(onLog, '[STEP] Configurando permisos del sistema...');
      _updateSetupNotification('Fixing rootfs permissions...', progress: 45);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.0,
        message: 'Fixing rootfs permissions...',
      ));

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
      _log(onLog, '[OK] Permisos configurados');

      // Pre-flight dpkg recovery before first apt command
      _log(onLog, '[STEP] Verificando integridad de dpkg...');
      await _runPreFlightRecovery(onLog: onLog);

      // ===================================================================
      // Step 3b: Update package lists (with recovery)
      // ===================================================================
      try {
        await _runProotWithRecovery(
          command: 'apt-get update -y -q 2>/dev/null',
          stepLabel: 'Actualizando listas de paquetes',
          timeoutSeconds: 600,
          onLog: onLog,
          isAptCommand: true,
        );
      } on _CorruptEnvironmentException catch (e) {
        _log(onLog, '[ERR] Entorno dpkg corrupto: ${e.message}');
        _log(onLog, '[STEP] Ofreciendo reinstalación limpia...');
        onProgress(const SetupState(
          step: SetupStep.error,
          error:
              'El entorno de paquetes está corrupto. Por favor, reinstala la app desde cero.',
        ));
        _stopSetupService();
        return;
      }

      // ===================================================================
      // Step 3c: Install base packages (with recovery)
      // ===================================================================
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

      try {
        await _runProotWithRecovery(
          command:
              'apt-get install -y --no-install-recommends -q 2>/dev/null '
              'ca-certificates git python3 make g++ curl wget',
          stepLabel: 'Instalando paquetes base',
          timeoutSeconds: 900,
          onLog: onLog,
          isAptCommand: true,
        );
      } on _CorruptEnvironmentException catch (e) {
        _log(onLog, '[ERR] Entorno dpkg corrupto: ${e.message}');
        onProgress(const SetupState(
          step: SetupStep.error,
          error:
              'El entorno de paquetes está corrupto. Por favor, reinstala la app desde cero.',
        ));
        _stopSetupService();
        return;
      }

      // ===================================================================
      // Step 3d: Extract Node.js
      // ===================================================================
      _log(onLog, '[STEP] Extrayendo Node.js...');
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.5,
        message: 'Extracting Node.js...',
      ));
      _updateSetupNotification('Extracting Node.js...', progress: 70);
      await NativeBridge.extractNodeTarball(nodeTarPath);
      _log(onLog, '[OK] Node.js extraído');

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
      await NativeBridge.runInProot('node --version && $nodeRun $npmCli --version');
      _log(onLog, '[OK] Node.js verificado correctamente');
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 1.0,
        message: 'Node.js installed',
      ));

      // ===================================================================
      // Step 4: Install OpenClaw via npm
      // ===================================================================
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
      await NativeBridge.runInProot(
          'openclaw --version || echo openclaw_installed');
      _log(onLog, '[OK] OpenClaw verificado');
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 1.0,
        message: 'OpenClaw installed',
      ));

      // ===================================================================
      // Step 5: Bionic Bypass (already installed)
      // ===================================================================
      _log(onLog, '[OK] Bionic Bypass configurado');
      _updateSetupNotification('Setup complete!', progress: 100);
      onProgress(const SetupState(
        step: SetupStep.configuringBypass,
        progress: 1.0,
        message: 'Bionic Bypass configured',
      ));

      // ===================================================================
      // Done
      // ===================================================================
      _log(onLog, '[OK] Instalación completada exitosamente!');
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
        error:
            'Download failed: ${e.message}. Check your internet connection.',
      ));
    } on _CorruptEnvironmentException catch (e) {
      _log(onLog, '[ERR] Entorno corrupto: ${e.message}');
      _log(onLog,
          '[INFO] Reinstale la app o ejecute "dpkg --configure -a" manualmente');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error:
            'El entorno de paquetes está en un estado inconsistente. '
            'Por favor, reinicia la app o reinstala desde cero.\n'
            'Detalles: ${e.message}',
      ));
    } on PlatformException catch (e) {
      _log(onLog, '[ERR] Error del sistema: ${e.message}');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Error del sistema: ${e.message}',
      ));
    } catch (e) {
      _log(onLog, '[ERR] Error de instalación: $e');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Setup failed: $e',
      ));
    }
  }
}

/// Exception thrown when the dpkg/apt environment is too corrupted to recover.
class _CorruptEnvironmentException implements Exception {
  final String message;
  const _CorruptEnvironmentException(this.message);

  @override
  String toString() => 'CorruptEnvironmentException: $message';
}
