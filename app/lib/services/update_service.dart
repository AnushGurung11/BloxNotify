import 'dart:convert';

import 'package:http/http.dart' as http;

/// An available app update found on GitHub Releases.
class AppUpdate {
  const AppUpdate({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    this.notes,
  });

  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String? notes;
}

/// Checks the GitHub Releases API of the public repo for a newer APK.
///
/// Release assets follow the naming convention
/// `blox-notify-<versionName>+<versionCode>.apk` (produced by the Release
/// workflow), so the versionCode can be read from the file name and compared
/// against the installed one.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String repo = 'AnushGurung11/BloxNotify';
  static const String apiUrl = 'https://api.github.com/repos/$repo/releases/latest';
  static final RegExp _assetPattern =
      RegExp(r'^blox-notify-(\d+\.\d+\.\d+)\+(\d+)\.apk$');

  /// Returns the newest release when it is newer than [installedVersionCode],
  /// otherwise null (also null on network/API errors — never throw).
  Future<AppUpdate?> checkForUpdate(int installedVersionCode) async {
    try {
      final response = await _client
          .get(Uri.parse(apiUrl), headers: const {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final assets = (release['assets'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        final match = _assetPattern.firstMatch(name);
        if (match == null) continue;

        final versionCode = int.parse(match.group(2)!);
        if (versionCode <= installedVersionCode) return null;

        return AppUpdate(
          versionName: match.group(1)!,
          versionCode: versionCode,
          downloadUrl: asset['browser_download_url'] as String,
          notes: release['body'] as String?,
        );
      }
    } catch (_) {
      // offline / rate-limited / malformed — silently skip the check
    }
    return null;
  }
}