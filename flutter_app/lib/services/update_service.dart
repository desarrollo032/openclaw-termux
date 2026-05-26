import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class UpdateResult {
  final String latest;
  final String url;
  final bool available;

  const UpdateResult({
    required this.latest,
    required this.url,
    required this.available,
  });
}

class UpdateService {
  static Future<UpdateResult> check() async {
    final response = await http.get(
      Uri.parse(AppConstants.githubApiLatestRelease),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );

    if (response.statusCode != 200) {
      throw Exception('GitHub API returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String;
    final htmlUrl = data['html_url'] as String;

    // Strip leading 'v' if present
    final latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    final available = _isNewer(latest, AppConstants.version);

    return UpdateResult(latest: latest, url: htmlUrl, available: available);
  }

  /// Parse a semver string into its numeric parts and optional pre-release suffix.
  /// Returns (major, minor, patch, preRelease) where preRelease is null for
  /// stable releases or e.g. "beta", "rc.1", "alpha.2".
  static (int, int, int, String?) _parseVersion(String version) {
    final preReleaseIdx = version.indexOf('-');
    final core = preReleaseIdx >= 0
        ? version.substring(0, preReleaseIdx)
        : version;
    final preRelease =
        preReleaseIdx >= 0 ? version.substring(preReleaseIdx + 1) : null;

    final parts = core.split('.');
    final major = int.parse(parts[0]);
    final minor = parts.length > 1 ? int.parse(parts[1]) : 0;
    final patch = parts.length > 2 ? int.parse(parts[2]) : 0;

    return (major, minor, patch, preRelease);
  }

  /// Compare two pre-release identifiers.
  /// Returns negative if a < b, positive if a > b, 0 if equal.
  static int _comparePreRelease(String a, String b) {
    final aParts = a.split('.');
    final bParts = b.split('.');
    final maxLen = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < maxLen; i++) {
      if (i >= aParts.length) return -1; // shorter = lower precedence
      if (i >= bParts.length) return 1;

      final aPart = aParts[i];
      final bPart = bParts[i];

      final aNum = int.tryParse(aPart);
      final bNum = int.tryParse(bPart);

      if (aNum != null && bNum != null) {
        if (aNum != bNum) return aNum.compareTo(bNum);
      } else {
        final cmp = aPart.compareTo(bPart);
        if (cmp != 0) return cmp;
      }
    }
    return 0;
  }

  /// Returns true if [remote] is newer than [local] by semver comparison.
  /// Handles pre-release suffixes: -beta, -rc, -alpha, etc.
  /// Per semver spec, pre-release versions have LOWER precedence than
  /// the release version (e.g. 1.8.8 > 1.8.8-beta).
  static bool _isNewer(String remote, String local) {
    final (rMajor, rMinor, rPatch, rPre) = _parseVersion(remote);
    final (lMajor, lMinor, lPatch, lPre) = _parseVersion(local);

    // Compare numeric core
    if (rMajor != lMajor) return rMajor > lMajor;
    if (rMinor != lMinor) return rMinor > lMinor;
    if (rPatch != lPatch) return rPatch > lPatch;

    // Numeric core is equal — compare pre-release
    if (rPre == null && lPre == null) return false; // identical
    if (rPre == null) return true; // stable > pre-release
    if (lPre == null) return false; // pre-release < stable

    // Both are pre-release — compare identifiers
    return _comparePreRelease(rPre, lPre) > 0;
  }
}
