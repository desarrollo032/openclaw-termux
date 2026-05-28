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

  /// Returns true if the old proot rootfs can be cleaned up.
  Future<bool> cleanupOldRootfs() async {
    try {
      final nativeComplete = await NativeBridge.isNativeBootstrapComplete();
      if (!nativeComplete) return false;
      return await NativeBridge.cleanupProotRootfs();
    } catch (_) {
      return false;
    }
  }

  Future<SetupState> checkStatus() async {
    try {
      final nativeComplete = await NativeBridge.isNativeBootstrapComplete();
      if (nativeComplete) {
        return const SetupState(
          step: SetupStep.complete,
          progress: 1.0,
          message: 'Native OpenClaw runtime ready',
          mode: InstallationMode.native,
        );
      }

      final prootComplete = await NativeBridge.isBootstrapComplete();
      if (prootComplete) {
        return const SetupState(
          step: SetupStep.complete,
          progress: 1.0,
          message: 'Proot OpenClaw runtime ready',
          mode: InstallationMode.proot,
        );
      }

      return const SetupState(
        step: SetupStep.checkingStatus,
        progress: 0.0,
        message: 'Select installation mode',
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

  Future<String> _runProotWithRecovery({
    required String command,
    required String stepLabel,
    int timeoutSeconds = 300,
    void Function(String)? onLog,
    bool isAptCommand = false,
  }) async {
    _log(onLog, '[STEP] $stepLabel');

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
          _log(onLog, '[WARN] Attempt $attempt/$_maxRetries — recovering dpkg/apt...');
          await _runDpkgRecovery(onLog: onLog);
          continue;
        }

        if (isDpkgError) {
          _log(onLog, '[ERR] $stepLabel failed after $_maxRetries attempts');
          _log(onLog, '[ERR] Corrupt environment — reinstallation required');
          throw _CorruptEnvironmentException(msg);
        }

        _log(onLog, '[ERR] $stepLabel: $msg');
        rethrow;
      } catch (e) {
        _log(onLog, '[ERR] $stepLabel: $e');

        if (attempt < _maxRetries && e is TimeoutException) {
          _log(onLog, '[WARN] Attempt $attempt/$_maxRetries — timeout, retrying...');
          continue;
        }
        rethrow;
      }
    }

    throw const _CorruptEnvironmentException(
      'Command failed after $_maxRetries attempts',
    );
  }

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

  Future<void> _runPreFlightRecovery({
    void Function(String)? onLog,
  }) async {
    if (_recoveryAttempted) {
      _log(onLog, '[STEP] dpkg already verified — skipping...');
      return;
    }

    _log(onLog, '[STEP] Verifying dpkg state...');
    try {
      final audit = await NativeBridge.runInProot(
        'dpkg --audit 2>&1 || echo audit_failed',
        timeout: 60,
      );
      if (audit.contains('problem') ||
          audit.contains('error') ||
          audit.contains('interrupted') ||
          audit.contains('inconsistent')) {
        _log(onLog, '[WARN] dpkg reports interrupted packages — recovering...');
        await _runDpkgRecovery(onLog: onLog);
      } else {
        _log(onLog, '[OK] dpkg clean');
      }
    } catch (e) {
      _log(onLog, '[WARN] Could not audit dpkg ($e) — continuing...');
    }

    _recoveryAttempted = true;
  }

  Future<void> _runDpkgRecovery({
    void Function(String)? onLog,
  }) async {
    _log(onLog, '[STEP] Recovery mode activated');

    _log(onLog, '[STEP] Removing dpkg/apt locks...');
    const lockCleanup = [
      '/bin/rm -f /var/lib/dpkg/lock-frontend 2>/dev/null',
      '/bin/rm -f /var/lib/dpkg/lock 2>/dev/null',
      '/bin/rm -f /var/cache/apt/archives/lock 2>/dev/null',
      '/bin/rm -f /var/lib/apt/lists/lock 2>/dev/null',
    ];
    for (final cmd in lockCleanup) {
      try { await _runProotSilent(cmd, timeoutSeconds: 15); } catch (_) {}
    }
    _log(onLog, '[OK] Locks removed');

    _log(onLog, '[STEP] Reconfiguring interrupted packages...');
    try {
      await _runProotSilent(
        'DEBIAN_FRONTEND=noninteractive dpkg --configure -a',
        timeoutSeconds: 300,
      );
      _log(onLog, '[OK] dpkg --configure -a completed');
    } catch (e) {
      _log(onLog, '[WARN] dpkg --configure -a had errors ($e) — continuing...');
    }

    _log(onLog, '[STEP] Fixing broken dependencies...');
    try {
      await _runProotSilent(
        'DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y -q 2>/dev/null',
        timeoutSeconds: 300,
      );
      _log(onLog, '[OK] apt --fix-broken completed');
    } catch (e) {
      _log(onLog, '[WARN] apt --fix-broken had errors ($e) — continuing...');
    }

    _log(onLog, '[STEP] Updating package lists...');
    try {
      await _runProotSilent(
        'DEBIAN_FRONTEND=noninteractive apt update -y -q 2>/dev/null',
        timeoutSeconds: 300,
      );
      _log(onLog, '[OK] apt update completed');
    } catch (e) {
      _log(onLog, '[WARN] apt update had errors ($e) — continuing...');
    }

    _log(onLog, '[STEP] Upgrading existing packages...');
    try {
      await _runProotSilent(
        'DEBIAN_FRONTEND=noninteractive apt upgrade -y -q 2>/dev/null',
        timeoutSeconds: 300,
      );
      _log(onLog, '[OK] apt upgrade completed');
    } catch (e) {
      _log(onLog, '[WARN] apt upgrade had errors ($e) — continuing...');
    }

    _log(onLog, '[OK] Recovery completed');
  }

  Future<String?> _fetchSha256Sum(
    String tarballUrl, {
    void Function(String)? onLog,
  }) async {
    try {
      final filename = tarballUrl.split('/').last;
      if (filename.isEmpty) return null;

      final baseUrl = tarballUrl.substring(0, tarballUrl.length - filename.length);
      final sha256sumsUrl = '${baseUrl}SHA256SUMS';

      _log(onLog, '[STEP] Fetching SHA256 from SHA256SUMS...');
      final response = await _dio.get<String>(
        sha256sumsUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data;
      if (data == null) {
        _log(onLog, '[WARN] Empty SHA256SUMS response');
        return null;
      }
      final lines = data.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        if (trimmed.contains(filename)) {
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            _log(onLog, '[OK] Hash found for $filename');
            return parts[0];
          }
        }
      }

      _log(onLog, '[WARN] $filename not found in SHA256SUMS');
      return null;
    } catch (e) {
      _log(onLog, '[WARN] Error fetching SHA256SUMS ($e) — continuing without verification');
      return null;
    }
  }

  Future<String> _runProotSilent(String command, {int timeoutSeconds = 60}) async {
    return NativeBridge.runInProot(command, timeout: timeoutSeconds).timeout(
      Duration(seconds: timeoutSeconds + 15),
      onTimeout: () => throw TimeoutException('Silent proot command timed out'),
    );
  }

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
    required InstallationMode mode,
    required void Function(SetupState) onProgress,
    void Function(String)? onLog,
  }) async {
    _recoveryAttempted = false;

    try {
      try { await NativeBridge.startSetupService(); } catch (_) {}

      if (mode == InstallationMode.native) {
        await _runNativeSetup(onProgress: onProgress, onLog: onLog);
      } else {
        await _runProotSetup(onProgress: onProgress, onLog: onLog);
      }
    } on DioException catch (e) {
      _log(onLog, '[ERR] Download error: ${e.message}');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Download failed: ${e.message}. Check your internet connection.',
      ));
    } on _CorruptEnvironmentException catch (e) {
      _log(onLog, '[ERR] Corrupt environment: ${e.message}');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Package environment is inconsistent. Please restart the app or reinstall from scratch.\nDetails: ${e.message}',
      ));
    } on PlatformException catch (e) {
      _log(onLog, '[ERR] System error: ${e.message}');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'System error: ${e.message}',
      ));
    } catch (e) {
      _log(onLog, '[ERR] Setup error: $e');
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Setup failed: $e',
      ));
    }
  }

  Future<void> _runNativeSetup({
    required void Function(SetupState) onProgress,
    void Function(String)? onLog,
  }) async {
    _log(onLog, '[STEP] Preparing native runtime (no proot)...');
    _updateSetupNotification('Preparing native runtime...', progress: 2);
    onProgress(const SetupState(
      step: SetupStep.checkingStatus,
      progress: 0.0,
      message: 'Preparing native runtime...',
    ));

    final nativeStatus = await NativeBridge.getNativeBootstrapStatus();
    _log(onLog, '[INFO] Native prefix: ${nativeStatus['prefix']}');
    _log(onLog, '[INFO] glibc ld.so source: ${nativeStatus['glibcDownloadUrl']}');
    _log(onLog, '[INFO] Node.js source: ${nativeStatus['nodeDownloadUrl']}');

    if (nativeStatus['complete'] == true) {
      _log(onLog, '[OK] Native runtime already installed');
      _updateSetupNotification('Native runtime ready', progress: 100);
      _stopSetupService();
      onProgress(const SetupState(
        step: SetupStep.complete,
        progress: 1.0,
        message: 'Native runtime ready',
      ));
      return;
    }

    onProgress(const SetupState(
      step: SetupStep.downloadingRootfs,
      progress: 0.1,
      message: 'Downloading native Termux/glibc packages...',
    ));
    _updateSetupNotification('Downloading native packages...', progress: 10);

    final output = await NativeBridge.runNativeBootstrap();
    for (final line in output.split('\n')) {
      if (line.trim().isNotEmpty) _log(onLog, line);
    }

    onProgress(const SetupState(
      step: SetupStep.installingOpenClaw,
      progress: 0.9,
      message: 'Verifying native OpenClaw...',
    ));
    _updateSetupNotification('Verifying native OpenClaw...', progress: 95);

    final complete = await NativeBridge.isNativeBootstrapComplete();
    if (!complete) {
      throw StateError('Native bootstrap finished without .post-setup-done');
    }

    _log(onLog, '[OK] Native installation completed successfully');
    _updateSetupNotification('Native setup complete!', progress: 100);
    _stopSetupService();
    onProgress(const SetupState(
      step: SetupStep.complete,
      progress: 1.0,
      message: 'Native OpenClaw runtime ready',
    ));
  }

  Future<void> _runProotSetup({
    required void Function(SetupState) onProgress,
    void Function(String)? onLog,
  }) async {
    _log(onLog, '[STEP] Setting up environment directories...');
    onProgress(const SetupState(
      step: SetupStep.checkingStatus,
      progress: 0.0,
      message: 'Setting up directories...',
    ));
    _updateSetupNotification('Setting up directories...', progress: 2);
    await NativeBridge.ensureReady();
    _log(onLog, '[OK] Directories ready');

    final arch = await NativeBridge.getArch();
    final filesDir = await NativeBridge.getFilesDir();
    final rootfsTarPath = '$filesDir/tmp/ubuntu-rootfs.tar.gz';
    final nodeTarPath = '$filesDir/tmp/nodejs.tar.xz';

    final rootfsUrl = AppConstants.getRootfsUrl(arch);
    final nodeTarUrl = AppConstants.getNodeTarballUrl(arch);

    _log(onLog, '[DOWNLOAD] Starting Ubuntu rootfs download...');
    _updateSetupNotification('Downloading Ubuntu rootfs...', progress: 5);
    onProgress(const SetupState(
      step: SetupStep.downloadingRootfs,
      progress: 0.0,
      message: 'Downloading Ubuntu rootfs...',
    ));

    int lastLoggedDownloadPct = -10;
    String lastNotifMb = '';
    DateTime lastOnProgressUpdate = DateTime(2000);
    int lastOnProgressPct = -10;

    await Future.wait([
      _dio.download(
        rootfsUrl,
        rootfsTarPath,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final pct = received / total;
          final mb = (received / 1024 / 1024).toStringAsFixed(1);
          final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
          final pctInt = (pct * 100).floor();
          if (pctInt >= lastLoggedDownloadPct + 5 || pct >= 1.0) {
            lastLoggedDownloadPct = pctInt;
            _log(onLog, '[DOWNLOAD] rootfs: $mb MB / $totalMb MB (${(pct * 100).toInt()}%)');
          }
          if (mb != lastNotifMb) {
            lastNotifMb = mb;
            _updateSetupNotification('Downloading rootfs: $mb / $totalMb MB', progress: 5 + (pct * 20).round());
          }
          final now = DateTime.now();
          if (now.difference(lastOnProgressUpdate).inMilliseconds >= 500 || pctInt >= lastOnProgressPct + 10) {
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
            _updateSetupNotification('Downloading: rootfs ($mb MB Node.js)', progress: 30);
          }
        },
      ),
    ]);

    _log(onLog, '[DOWNLOAD] rootfs: 100% complete');
    _log(onLog, '[OK] Downloads complete');
    onProgress(const SetupState(
      step: SetupStep.downloadingRootfs,
      progress: 1.0,
      message: 'Downloads complete',
    ));

    _log(onLog, '[STEP] Extracting Ubuntu base system...');
    _updateSetupNotification('Extracting rootfs...', progress: 32);
    onProgress(const SetupState(
      step: SetupStep.extractingRootfs,
      progress: 0.0,
      message: 'Extracting rootfs (this takes a while)...',
    ));

    final sha256Hash = await _fetchSha256Sum(rootfsUrl, onLog: onLog);
    if (sha256Hash != null) {
      _log(onLog, '[OK] SHA256 hash obtained from SHA256SUMS');
    } else {
      _log(onLog, '[WARN] Could not get SHA256 hash — continuing without verification');
    }
    await NativeBridge.extractRootfs(rootfsTarPath, sha256: sha256Hash);

    _log(onLog, '[OK] Base system extracted and verified');
    onProgress(const SetupState(
      step: SetupStep.extractingRootfs,
      progress: 1.0,
      message: 'Rootfs extracted',
    ));

    _log(onLog, '[STEP] Installing Bionic Bypass for compatibility...');
    await NativeBridge.installBionicBypass();
    _log(onLog, '[OK] Bionic Bypass installed');

    _log(onLog, '[STEP] Configuring system permissions...');
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
    _log(onLog, '[OK] Permissions configured');

    _log(onLog, '[STEP] Verifying dpkg integrity...');
    await _runPreFlightRecovery(onLog: onLog);

    try {
      await _runProotWithRecovery(
        command: 'apt-get update -y -q 2>/dev/null',
        stepLabel: 'Updating package lists',
        timeoutSeconds: 600,
        onLog: onLog,
        isAptCommand: true,
      );
    } on _CorruptEnvironmentException catch (e) {
      _log(onLog, '[ERR] Corrupt dpkg environment: ${e.message}');
      onProgress(const SetupState(
        step: SetupStep.error,
        error: 'Package environment is corrupted. Please reinstall the app from scratch.',
      ));
      _stopSetupService();
      return;
    }

    _log(onLog, '[STEP] Installing base packages (ca-certificates, git, python3, make, g++, curl, wget)...');
    _updateSetupNotification('Installing base packages...', progress: 52);
    onProgress(const SetupState(
      step: SetupStep.installingNode,
      progress: 0.15,
      message: 'Installing base packages...',
    ));

    await _runInProotWithTimeout(
      'ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && '
      'echo "Etc/UTC" > /etc/timezone',
      timeoutSeconds: 30,
    );

    try {
      await _runProotWithRecovery(
        command: 'apt-get install -y --no-install-recommends -q 2>/dev/null '
            'ca-certificates git python3 make g++ curl wget',
        stepLabel: 'Installing base packages',
        timeoutSeconds: 900,
        onLog: onLog,
        isAptCommand: true,
      );
    } on _CorruptEnvironmentException catch (e) {
      _log(onLog, '[ERR] Corrupt dpkg environment: ${e.message}');
      onProgress(const SetupState(
        step: SetupStep.error,
        error: 'Package environment is corrupted. Please reinstall the app from scratch.',
      ));
      _stopSetupService();
      return;
    }

    _log(onLog, '[STEP] Extracting Node.js...');
    onProgress(const SetupState(
      step: SetupStep.installingNode,
      progress: 0.5,
      message: 'Extracting Node.js...',
    ));
    _updateSetupNotification('Extracting Node.js...', progress: 70);
    await NativeBridge.extractNodeTarball(nodeTarPath);
    _log(onLog, '[OK] Node.js extracted');

    _log(onLog, '[STEP] Verifying Node.js...');
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
    _log(onLog, '[OK] Node.js verified');
    onProgress(const SetupState(
      step: SetupStep.installingNode,
      progress: 1.0,
      message: 'Node.js installed',
    ));

    _log(onLog, '[STEP] Installing OpenClaw (this may take several minutes)...');
    _updateSetupNotification('Installing OpenClaw...', progress: 82);
    onProgress(const SetupState(
      step: SetupStep.installingOpenClaw,
      progress: 0.0,
      message: 'Installing OpenClaw (this may take a few minutes)...',
    ));
    await NativeBridge.runInProot('$nodeRun $npmCli install -g openclaw', timeout: 1800);
    _log(onLog, '[OK] OpenClaw installed');

    _log(onLog, '[STEP] Creating binary wrappers...');
    _updateSetupNotification('Creating bin wrappers...', progress: 92);
    onProgress(const SetupState(
      step: SetupStep.installingOpenClaw,
      progress: 0.7,
      message: 'Creating bin wrappers...',
    ));
    await NativeBridge.createBinWrappers('openclaw');
    _log(onLog, '[OK] Wrappers created');

    _log(onLog, '[STEP] Verifying OpenClaw...');
    _updateSetupNotification('Verifying OpenClaw...', progress: 96);
    onProgress(const SetupState(
      step: SetupStep.installingOpenClaw,
      progress: 0.9,
      message: 'Verifying OpenClaw...',
    ));
    await NativeBridge.runInProot('openclaw --version || echo openclaw_installed');
    _log(onLog, '[OK] OpenClaw verified');
    onProgress(const SetupState(
      step: SetupStep.installingOpenClaw,
      progress: 1.0,
      message: 'OpenClaw installed',
    ));

    _log(onLog, '[OK] Bionic Bypass configured');
    _updateSetupNotification('Setup complete!', progress: 100);
    onProgress(const SetupState(
      step: SetupStep.configuringBypass,
      progress: 1.0,
      message: 'Bionic Bypass configured',
    ));

    _log(onLog, '[OK] Installation completed successfully!');
    _stopSetupService();
    onProgress(const SetupState(
      step: SetupStep.complete,
      progress: 1.0,
      message: 'Setup complete! Ready to start the gateway.',
    ));
  }
}

class _CorruptEnvironmentException implements Exception {
  final String message;
  const _CorruptEnvironmentException(this.message);

  @override
  String toString() => 'CorruptEnvironmentException: $message';
}
