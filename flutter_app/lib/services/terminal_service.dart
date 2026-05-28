import 'dart:io';
import 'native_bridge.dart';

/// Provides shell configuration for proot-based terminals.
///
/// - [getProotShellConfig] / [buildProotArgs] / [buildHostEnv]:
///   Used for the proot-based Ubuntu rootfs.
class TerminalService {
  // ── Proot config ──────────────────────────────────────────────────────────

  static const _fakeKernelRelease = '6.17.0-PRoot-Distro';
  static const _fakeKernelVersion =
      '#1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000';

  static Map<String, String>? _cachedProotConfig;

  /// Get paths and host-side proot environment variables.
  /// Host env should ONLY contain proot-specific vars — guest env is
  /// set via `env -i` inside the command, matching proot-distro.
  static Future<Map<String, String>> getProotShellConfig() async {
    try { await NativeBridge.ensureReady(); } catch (_) {}

    if (_cachedProotConfig == null) {
      final filesDir = await NativeBridge.getFilesDir();
      final nativeLibDir = await NativeBridge.getNativeLibDir();

      final rootfsDir = '$filesDir/rootfs/ubuntu';
      final tmpDir = '$filesDir/tmp';
      final configDir = '$filesDir/config';
      final homeDir = '$filesDir/home';
      final prootPath = '$nativeLibDir/libproot.so';
      final libDir = '$filesDir/lib';

      const resolvContent = 'nameserver 8.8.8.8\nnameserver 1.1.1.1\nnameserver 8.8.4.4\nnameserver 1.0.0.1\n';
      try {
        final resolvFile = File('$configDir/resolv.conf');
        if (!resolvFile.existsSync()) {
          Directory(configDir).createSync(recursive: true);
          resolvFile.writeAsStringSync(resolvContent);
        }
      } catch (_) {}
      try {
        final rootfsResolv = File('$rootfsDir/etc/resolv.conf');
        if (!rootfsResolv.existsSync()) {
          rootfsResolv.parent.createSync(recursive: true);
          rootfsResolv.writeAsStringSync(resolvContent);
        }
      } catch (_) {}

      _cachedProotConfig = {
        'executable': prootPath,
        'rootfsDir': rootfsDir,
        'tmpDir': tmpDir,
        'configDir': configDir,
        'homeDir': homeDir,
        'libDir': libDir,
        'nativeLibDir': nativeLibDir,
        'PROOT_TMP_DIR': tmpDir,
        'PROOT_LOADER': '$nativeLibDir/libprootloader.so',
        'PROOT_LOADER_32': '$nativeLibDir/libprootloader32.so',
        'LD_LIBRARY_PATH': '$libDir:$nativeLibDir',
      };
    }

    final storageGranted = await NativeBridge.hasStoragePermission();
    final result = Map<String, String>.from(_cachedProotConfig!);
    result['storageGranted'] = storageGranted.toString();
    return result;
  }

  /// Build proot arguments matching ProcessManager.kt's gateway mode.
  static List<String> buildProotArgs(Map<String, String> config,
      {int columns = 80, int rows = 24}) {
    final procFakes = '${config['configDir']}/proc_fakes';
    final sysFakes = '${config['configDir']}/sys_fakes';
    final rootfsDir = config['rootfsDir']!;
    String machine = 'aarch64';

    final kernelRelease = '\\Linux\\localhost\\$_fakeKernelRelease'
        '\\$_fakeKernelVersion\\$machine\\localdomain\\-1\\';

    final args = <String>[
      '--change-id=0:0',
      '--sysvipc',
      '--kernel-release=$kernelRelease',
      '--link2symlink',
      '-L',
      '--kill-on-exit',
      '--rootfs=$rootfsDir',
      '--cwd=/root',
      '--bind=/dev',
      '--bind=/dev/urandom:/dev/random',
      '--bind=/proc',
      '--bind=/proc/self/fd:/dev/fd',
      '--bind=/proc/self/fd/0:/dev/stdin',
      '--bind=/proc/self/fd/1:/dev/stdout',
      '--bind=/proc/self/fd/2:/dev/stderr',
      '--bind=/sys',
      '--bind=$procFakes/loadavg:/proc/loadavg',
      '--bind=$procFakes/stat:/proc/stat',
      '--bind=$procFakes/uptime:/proc/uptime',
      '--bind=$procFakes/version:/proc/version',
      '--bind=$procFakes/vmstat:/proc/vmstat',
      '--bind=$procFakes/cap_last_cap:/proc/sys/kernel/cap_last_cap',
      '--bind=$procFakes/max_user_watches:/proc/sys/fs/inotify/max_user_watches',
      '--bind=$procFakes/fips_enabled:/proc/sys/crypto/fips_enabled',
      '--bind=$rootfsDir/tmp:/dev/shm',
      '--bind=$sysFakes/empty:/sys/fs/selinux',
      '--bind=${config['configDir']}/resolv.conf:/etc/resolv.conf',
      '--bind=${config['homeDir']}:/root/home',
    ];

    if (config['storageGranted'] == 'true') {
      args.addAll([
        '--bind=/storage:/storage',
        '--bind=/storage/emulated/0:/sdcard',
      ]);
    }

    args.addAll([
      '/usr/bin/env', '-i',
      'HOME=/root',
      'USER=root',
      'LANG=C.UTF-8',
      'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'TERM=xterm-256color',
      'TMPDIR=/tmp',
      'COLUMNS=$columns',
      'LINES=$rows',
      'NODE_OPTIONS=--require /root/.openclaw/bionic-bypass.js',
      '/bin/bash',
      '-l',
    ]);

    return args;
  }

  /// Host-side environment map for Pty.start() (proot mode).
  static Map<String, String> buildHostEnv(Map<String, String> config) {
    return {
      'PROOT_TMP_DIR': config['PROOT_TMP_DIR']!,
      'PROOT_LOADER': config['PROOT_LOADER']!,
      'PROOT_LOADER_32': config['PROOT_LOADER_32']!,
      'LD_LIBRARY_PATH': config['LD_LIBRARY_PATH']!,
    };
  }
}
