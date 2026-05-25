///
/// sync_local_plugins.dart
///
/// Refreshes local copies of Flutter plugins that have been patched to use
/// Kotlin built-in (instead of KGP). Run this after `flutter pub upgrade`
/// to update the local plugin sources while preserving the patches.
///
/// Usage:
///   cd flutter_app && dart run ../scripts/sync_local_plugins.dart
///
/// Or from project root:
///   dart run flutter_app/../scripts/sync_local_plugins.dart
///

import 'dart:io';

// ---------------------------------------------------------------------------
// Configuration: plugins we maintain local copies of and the patches to apply
// ---------------------------------------------------------------------------

/// Describes a single text replacement to apply to a build file.
class _Patch {
  final String oldText;
  final String newText;

  const _Patch({required this.oldText, required this.newText});
}

/// Describes a plugin we have patched locally.
class _PluginConfig {
  /// Package name as it appears in pub.dev / pubspec.yaml
  final String packageName;

  /// Relative path (from plugin root) to the android build file
  final String buildFilePath;

  /// Patches to apply, in order
  final List<_Patch> patches;

  const _PluginConfig({
    required this.packageName,
    required this.buildFilePath,
    required this.patches,
  });
}

/// All plugins with local copies + patches.
///
/// When a newer upstream version is released, re-run this script to
/// re-copy the source from the pub cache and re-apply these patches.
const _plugins = <_PluginConfig>[
  // ── camera_android_camerax (build.gradle.kts) ──────────────────────
  _PluginConfig(
    packageName: 'camera_android_camerax',
    buildFilePath: 'android/build.gradle.kts',
    patches: [
      // Remove KGP classpath from buildscript
      _Patch(
        oldText: '''buildscript {
    val kotlinVersion = "2.3.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:\$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}''',
        newText: '''buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}''',
      ),
    ],
  ),

  // ── package_info_plus (build.gradle - Groovy DSL) ─────────────────
  _PluginConfig(
    packageName: 'package_info_plus',
    buildFilePath: 'android/build.gradle',
    patches: [
      _Patch(
        oldText: '''buildscript {
    ext.kotlin_version = '2.2.0'

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.12.1'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:\$kotlin_version"
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: 'com.android.library'
apply plugin: 'kotlin-android'

android {
    namespace 'dev.fluttercommunity.plus.packageinfo'
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = 17
    }

    defaultConfig {
        minSdk 19
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    lintOptions {
        disable 'InvalidPackage'
    }

    dependencies {
        implementation "org.jetbrains.kotlin:kotlin-stdlib:\$kotlin_version"
    }
}''',
        newText: '''buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.12.1'
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: 'com.android.library'

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace 'dev.fluttercommunity.plus.packageinfo'
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk 19
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    lintOptions {
        disable 'InvalidPackage'
    }
}''',
      ),
    ],
  ),

  // ── shared_preferences_android (build.gradle.kts) ─────────────────
  _PluginConfig(
    packageName: 'shared_preferences_android',
    buildFilePath: 'android/build.gradle.kts',
    patches: [
      _Patch(
        oldText: '''buildscript {
    val kotlinVersion = "2.3.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:\$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// TODO(stuartmorgan): See if this can be removed.
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:deprecation")
    options.compilerArgs.add("-Xlint:unchecked")
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}''',
        newText: '''buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// TODO(stuartmorgan): See if this can be removed.
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:deprecation")
    options.compilerArgs.add("-Xlint:unchecked")
}

plugins {
    id("com.android.library")
}''',
      ),
    ],
  ),

  // ── url_launcher_android (build.gradle.kts) ───────────────────────
  _PluginConfig(
    packageName: 'url_launcher_android',
    buildFilePath: 'android/build.gradle.kts',
    patches: [
      _Patch(
        oldText: '''buildscript {
    val kotlinVersion = "2.3.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:\$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}''',
        newText: '''buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}''',
      ),
    ],
  ),

  // ── webview_flutter_android (build.gradle.kts) ────────────────────
  _PluginConfig(
    packageName: 'webview_flutter_android',
    buildFilePath: 'android/build.gradle.kts',
    patches: [
      _Patch(
        oldText: '''buildscript {
    val kotlinVersion = "2.3.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:\$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}''',
        newText: '''buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.13.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}''',
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Detect if terminal likely supports ANSI escape codes.
final _ansiSupported = Platform.environment.containsKey('TERM') ||
    Platform.environment.containsKey('WT_SESSION') ||
    Platform.environment.containsKey('VSCODE_PID') ||
    !Platform.isWindows;

final _stdout = stdout;
String _c(String code, String msg) =>
    _ansiSupported ? '$code$msg\x1b[0m' : msg;

void _log(String msg) => _stdout.writeln('  $msg');
void _info(String msg) => _stdout.writeln('  ${_c('\x1b[36m', msg)}');
void _ok(String msg) =>
    _stdout.writeln('  ${_c('\x1b[32m', _ansiSupported ? '✓ ' : '')}$msg');
void _warn(String msg) =>
    _stdout.writeln('  ${_c('\x1b[33m', _ansiSupported ? '⚠ ' : '')}$msg');
void _err(String msg) =>
    _stdout.writeln('  ${_c('\x1b[31m', _ansiSupported ? '✗ ' : '')}$msg');

void _heading(String msg) {
  _stdout.writeln('');
  _stdout.writeln('━━━ $msg ━━━');
  _stdout.writeln('');
}

/// Locate the pub cache directory.
String _findPubCache() {
  // Check PUB_CACHE env var first
  final envCache = Platform.environment['PUB_CACHE'];
  if (envCache != null && Directory(envCache).existsSync()) {
    return '$envCache/hosted/pub.dev';
  }

  if (Platform.isWindows) {
    // Windows: %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null) {
      final candidate = '$localAppData\\Pub\\Cache\\hosted\\pub.dev';
      if (Directory(candidate).existsSync()) return candidate;
    }
    // Fallback: %APPDATA%\Pub\Cache\hosted\pub.dev
    final appData = Platform.environment['APPDATA'];
    if (appData != null) {
      final candidate = '$appData\\Pub\\Cache\\hosted\\pub.dev';
      if (Directory(candidate).existsSync()) return candidate;
    }
  } else {
    // macOS / Linux: ~/.pub-cache/hosted/pub.dev
    final home = Platform.environment['HOME'];
    if (home != null) {
      final candidate = '$home/.pub-cache/hosted/pub.dev';
      if (Directory(candidate).existsSync()) return candidate;
    }
  }

  throw Exception(
    'Cannot locate pub cache. Set the PUB_CACHE environment variable.',
  );
}

/// Find the exact version of [packageName] from pubspec.lock.
String? _versionFromPubspecLock(String lockPath, String packageName) {
  final file = File(lockPath);
  if (!file.existsSync()) return null;

  final lines = file.readAsLinesSync();
  bool inPackage = false;
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed == '$packageName:') {
      inPackage = true;
      continue;
    }
    if (inPackage) {
      if (trimmed.startsWith('version: ')) {
        return trimmed.substring('version: '.length).replaceAll('"', '');
      }
      // If we hit another top-level key, we've left the package block
      if (!line.startsWith(' ') && !line.startsWith('\t')) {
        inPackage = false;
      }
    }
  }
  return null;
}

/// Recursively copy a directory. Removes [to] first if it exists.
void _copyDirectory(Directory from, Directory to) {
  if (to.existsSync()) {
    to.deleteSync(recursive: true);
  }
  to.createSync(recursive: true);

  for (final entry in from.listSync(recursive: true)) {
    if (entry is File) {
      final relative = entry.path.substring(from.path.length + 1);
      final dest = File('${to.path}/$relative');
      dest.parent.createSync(recursive: true);
      entry.copySync(dest.path);
    }
  }
}

/// Apply text patches to a file.
bool _applyPatches(File file, List<_Patch> patches) {
  if (!file.existsSync()) {
    _err('File not found: ${file.path}');
    return false;
  }

  var content = file.readAsStringSync();
  bool changed = false;

  for (final patch in patches) {
    if (content.contains(patch.oldText)) {
      content = content.replaceAll(patch.oldText, patch.newText);
      _ok('Applied patch to ${file.path}');
      changed = true;
    } else {
      _warn('Patch pattern not found in ${file.path} — '
          'the source may have changed upstream. Skipping.');
    }
  }

  if (changed) {
    file.writeAsStringSync(content);
  }
  return changed;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main(List<String> args) async {
  // Resolve the flutter_app directory
  final scriptDir = Directory(Platform.script.toFilePath()).parent;
  // If running from scripts/, the project root is ..
  // If running from flutter_app/, the project root is ..
  // We need to find flutter_app/ relative to script location
  String flutterDir;
  if (Directory('${scriptDir.path}/../flutter_app').existsSync()) {
    // script is in scripts/
    flutterDir = '${scriptDir.path}/../flutter_app';
  } else if (Directory('${scriptDir.path}/flutter_app').existsSync()) {
    // script is at project root
    flutterDir = '${scriptDir.path}/flutter_app';
  } else if (Directory('flutter_app').existsSync()) {
    // running from project root
    flutterDir = 'flutter_app';
  } else {
    flutterDir = '.';
  }
  flutterDir = Directory(flutterDir).resolveSymbolicLinksSync();

  // Parse arguments
  final skipPubGet = args.contains('--skip-pub-get');

  _heading('Syncing local plugin patches');
  _log('Flutter app dir: $flutterDir');
  _log('');

  // 1. Locate pub cache
  _info('Locating pub cache...');
  String pubCacheDir;
  try {
    pubCacheDir = _findPubCache();
  } catch (e) {
    _err('$e');
    exit(1);
  }
  _ok('Pub cache: $pubCacheDir');

  // 2. Read pubspec.lock for versions
  final lockPath = '$flutterDir/pubspec.lock';
  if (!File(lockPath).existsSync()) {
    _err('pubspec.lock not found at $lockPath. Run flutter pub get first.');
    exit(1);
  }

  final localPluginsDir = '$flutterDir/local_plugins';
  if (!Directory(localPluginsDir).existsSync()) {
    _err('local_plugins/ not found at $localPluginsDir');
    exit(1);
  }

  int successCount = 0;
  int failCount = 0;

  for (final plugin in _plugins) {
    _heading('${plugin.packageName}');

    // Find version in pubspec.lock
    final version = _versionFromPubspecLock(lockPath, plugin.packageName);
    if (version == null) {
      _err('Version not found in pubspec.lock');
      failCount++;
      continue;
    }
    _info('Version from pubspec.lock: $version');

    // Locate cached plugin directory
    final cacheDir = '$pubCacheDir/${plugin.packageName}-$version';
    if (!Directory(cacheDir).existsSync()) {
      // Try finding by listing directory (in case version has build metadata)
      _warn('Exact version not found at: $cacheDir');
      _info('Searching for cached version...');

      final cacheParent = Directory(pubCacheDir);
      final candidates = cacheParent
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.contains('${plugin.packageName}-$version'))
          .toList();

      if (candidates.isEmpty) {
        _err('Plugin ${plugin.packageName}-$version not found in pub cache.\n'
            '  Run "dart pub cache list" or "flutter pub get" to download it.');
        failCount++;
        continue;
      }
      // Use the first match
      final cachePath = candidates.first.path;
      _info('Found at: $cachePath');
      _copyDirectory(Directory(cachePath), Directory('$localPluginsDir/${plugin.packageName}'));
    } else {
      _info('Pub cache: $cacheDir');
      // Copy fresh source
      _copyDirectory(
        Directory(cacheDir),
        Directory('$localPluginsDir/${plugin.packageName}'),
      );
    }

    _info('Copied fresh source to local_plugins/${plugin.packageName}');

    // Apply patches
    final buildFile = File(
      '$localPluginsDir/${plugin.packageName}/${plugin.buildFilePath}',
    );
    _applyPatches(buildFile, plugin.patches);

    successCount++;
  }

  // Summary
  _heading('Summary');
  _ok('$successCount plugins synced');
  if (failCount > 0) {
    _err('$failCount plugins failed');
  }
  _log('');

  // Run flutter pub get
  if (!skipPubGet) {
    _info('Running flutter pub get to sync dependency resolution...');
    _log('');

    final result = await Process.run(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      ['pub', 'get'],
      workingDirectory: flutterDir,
      runInShell: true,
    );

    if (result.exitCode == 0) {
      _ok('flutter pub get completed');
    } else {
      _err('flutter pub get failed (exit ${result.exitCode})');
      _log(result.stderr as String);
      exit(1);
    }
  } else {
    _info('Skipped flutter pub get (--skip-pub-get)');
  }

  _log('');
  _ok('Done. Run "flutter build apk --debug" to verify the build.');
  _log('If build errors occur, the upstream plugin source may have changed.');
  _log('Update the patches in scripts/sync_local_plugins.dart as needed.');
}
