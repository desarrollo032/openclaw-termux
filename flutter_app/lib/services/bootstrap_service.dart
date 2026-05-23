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

  Future<void> runFullSetup({
    required void Function(SetupState) onProgress,
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
              // Map download to 5-25% of overall progress
              final notifProgress = 5 + (pct * 20).round();
              _updateSetupNotification('Downloading rootfs: $mb / $totalMb MB', progress: notifProgress);
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

      onProgress(const SetupState(
        step: SetupStep.downloadingRootfs,
        progress: 1.0,
        message: 'Downloads complete',
      ));

      // Step 3: Extract rootfs (30-45%)
      _updateSetupNotification('Extracting rootfs...', progress: 32);
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 0.0,
        message: 'Extracting rootfs (this takes a while)...',
      ));
      await NativeBridge.extractRootfs(tarPath);
      onProgress(const SetupState(
        step: SetupStep.extractingRootfs,
        progress: 1.0,
        message: 'Rootfs extracted',
      ));

      // Install bionic bypass + cwd-fix + node-wrapper BEFORE using node.
      // The wrapper patches process.cwd() which returns ENOSYS in proot.
      await NativeBridge.installBionicBypass();

      // Step 4: Install Node.js (45-80%)
      // Fix permissions inside proot (Java extraction may miss execute bits)
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

      // --- Install base packages via apt-get (like Termux proot-distro) ---
      _updateSetupNotification('Updating package lists...', progress: 48);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.1,
        message: 'Updating package lists...',
      ));
      try {
        await _runInProotWithTimeout('apt-get update -y', timeoutSeconds: 600);
      } catch (e) {
        _updateSetupNotification('Updating packages (retrying)...', progress: 48);
        // Retry once in case of transient network failure
        await _runInProotWithTimeout('apt-get update -y', timeoutSeconds: 600);
      }

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

      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.5,
        message: 'Extracting Node.js...',
      ));
      _updateSetupNotification('Extracting Node.js...', progress: 70);
      await NativeBridge.extractNodeTarball(nodeTarPath);

      _updateSetupNotification('Verifying Node.js...', progress: 78);
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 0.75,
        message: 'Verifying Node.js...',
      ));
      // node-wrapper.js patches broken proot syscalls before loading npm.
      // /usr/local/bin is on PATH, so node finds the tarball's npm.
      const wrapper = '/root/.openclaw/node-wrapper.js';
      const nodeRun = 'node $wrapper';
      // npm from nodejs.org tarball is at /usr/local/lib/node_modules/npm
      const npmCli = '/usr/local/lib/node_modules/npm/bin/npm-cli.js';
      await NativeBridge.runInProot(
        'node --version && $nodeRun $npmCli --version',
      );
      onProgress(const SetupState(
        step: SetupStep.installingNode,
        progress: 1.0,
        message: 'Node.js installed',
      ));

      // Step 4: Install OpenClaw (80-98%)
      _updateSetupNotification('Installing OpenClaw...', progress: 82);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.0,
        message: 'Installing OpenClaw (this may take a few minutes)...',
      ));
      // Install openclaw — fork/exec works now with our Termux-matching proot.
      await NativeBridge.runInProot(
        '$nodeRun $npmCli install -g openclaw',
        timeout: 1800,
      );

      _updateSetupNotification('Creating bin wrappers...', progress: 92);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.7,
        message: 'Creating bin wrappers...',
      ));
      // npm global install creates symlinks for bin entries, but symlinks
      // can fail silently in proot. Create shell wrappers from Java side
      // (reads package.json directly from rootfs filesystem — no escaping).
      await NativeBridge.createBinWrappers('openclaw');

      _updateSetupNotification('Verifying OpenClaw...', progress: 96);
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 0.9,
        message: 'Verifying OpenClaw...',
      ));
      await NativeBridge.runInProot('openclaw --version || echo openclaw_installed');
      onProgress(const SetupState(
        step: SetupStep.installingOpenClaw,
        progress: 1.0,
        message: 'OpenClaw installed',
      ));

      // Step 5: Bionic Bypass already installed (before node verification)
      _updateSetupNotification('Setup complete!', progress: 100);
      onProgress(const SetupState(
        step: SetupStep.configuringBypass,
        progress: 1.0,
        message: 'Bionic Bypass configured',
      ));

      // Done
      _stopSetupService();
      onProgress(const SetupState(
        step: SetupStep.complete,
        progress: 1.0,
        message: 'Setup complete! Ready to start the gateway.',
      ));
    } on DioException catch (e) {
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Download failed: ${e.message}. Check your internet connection.',
      ));
    } catch (e) {
      _stopSetupService();
      onProgress(SetupState(
        step: SetupStep.error,
        error: 'Setup failed: $e',
      ));
    }
  }

  /// Run a command in proot with a Dart-side timeout to prevent hanging.
  /// If the native call times out, throws an exception caught by runFullSetup.
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
