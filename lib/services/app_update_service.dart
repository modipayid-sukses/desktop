import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdateInfo {
  final String latestVersion;
  final String minimumVersion;
  final String releaseNotes;
  final String downloadUrl;
  final bool forceUpdate;
  final DateTime releaseDate;

  UpdateInfo({
    required this.latestVersion,
    required this.minimumVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.forceUpdate,
    required this.releaseDate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      latestVersion: json['latestVersion'] as String,
      minimumVersion: json['minimumVersion'] as String,
      releaseNotes: json['releaseNotes'] as String,
      downloadUrl: json['downloadUrl'] as String,
      forceUpdate: json['forceUpdate'] as bool,
      releaseDate: DateTime.parse(json['releaseDate'] as String),
    );
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  late SharedPreferences _prefs;
  late PackageInfo _packageInfo;

  factory AppUpdateService() {
    return _instance;
  }

  AppUpdateService._internal();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Get current app version
  Future<String> getCurrentVersion() async {
    return _packageInfo.version;
  }

  /// Get current build number
  Future<String> getCurrentBuildNumber() async {
    return _packageInfo.buildNumber;
  }

  /// Check for updates from server
  Future<UpdateInfo?> checkForUpdates() async {
    try {
      // Replace with actual API endpoint
      const String apiUrl = 'https://api.modipay.local/app/version';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final updateInfo = UpdateInfo.fromJson(json);

        // Cache the update info
        await _cacheUpdateInfo(updateInfo);

        return updateInfo;
      }

      return null;
    } catch (e) {
      // Return cached update info if available
      return _getCachedUpdateInfo();
    }
  }

  /// Check if update is required (critical)
  Future<bool> isUpdateRequired() async {
    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo == null) return false;

      if (!updateInfo.forceUpdate) return false;

      // Compare versions
      final currentVersion = await getCurrentVersion();
      final isCurrentBelowMinimum =
          _compareVersions(currentVersion, updateInfo.minimumVersion) < 0;

      return isCurrentBelowMinimum;
    } catch (e) {
      return false;
    }
  }

  /// Check if optional update is available
  Future<bool> isUpdateAvailable() async {
    try {
      final updateInfo = await checkForUpdates();
      if (updateInfo == null) return false;

      final currentVersion = await getCurrentVersion();
      final isCurrentBelowLatest =
          _compareVersions(currentVersion, updateInfo.latestVersion) < 0;

      return isCurrentBelowLatest;
    } catch (e) {
      return false;
    }
  }

  /// Get last dismissed update version
  Future<String?> getLastDismissedVersion() async {
    return _prefs.getString('last_dismissed_update_version');
  }

  /// Save dismissed update version
  Future<void> saveDismissedUpdateVersion(String version) async {
    await _prefs.setString('last_dismissed_update_version', version);
    await _prefs.setString(
      'last_dismissed_update_time',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get last dismissed update time
  Future<DateTime?> getLastDismissedUpdateTime() async {
    final timeStr = _prefs.getString('last_dismissed_update_time');
    if (timeStr == null) return null;
    return DateTime.parse(timeStr);
  }

  /// Check if should show update reminder (24 hours after dismiss)
  Future<bool> shouldShowUpdateReminder() async {
    final lastDismissedTime = await getLastDismissedUpdateTime();
    if (lastDismissedTime == null) return false;

    final now = DateTime.now();
    final difference = now.difference(lastDismissedTime);

    return difference.inHours >= 24;
  }

  /// Compare semantic versions (returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2)
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    // Pad with zeros to make same length
    while (parts1.length < parts2.length) parts1.add(0);
    while (parts2.length < parts1.length) parts2.add(0);

    for (int i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0;
  }

  /// Cache update info locally
  Future<void> _cacheUpdateInfo(UpdateInfo info) async {
    await _prefs.setString('cached_update_info', jsonEncode({
      'latestVersion': info.latestVersion,
      'minimumVersion': info.minimumVersion,
      'releaseNotes': info.releaseNotes,
      'downloadUrl': info.downloadUrl,
      'forceUpdate': info.forceUpdate,
      'releaseDate': info.releaseDate.toIso8601String(),
    }));
    await _prefs.setString(
      'cached_update_info_time',
      DateTime.now().toIso8601String(),
    );
  }

  /// Get cached update info (if available and recent)
  Future<UpdateInfo?> _getCachedUpdateInfo() async {
    try {
      final infoStr = _prefs.getString('cached_update_info');
      final timeStr = _prefs.getString('cached_update_info_time');

      if (infoStr == null || timeStr == null) return null;

      // Only use cache if less than 24 hours old
      final cachedTime = DateTime.parse(timeStr);
      final now = DateTime.now();
      final difference = now.difference(cachedTime);

      if (difference.inHours > 24) return null;

      return UpdateInfo.fromJson(jsonDecode(infoStr));
    } catch (e) {
      return null;
    }
  }

  /// Clear cached update info
  Future<void> clearCachedUpdateInfo() async {
    await _prefs.remove('cached_update_info');
    await _prefs.remove('cached_update_info_time');
  }

  /// Log update action for analytics
  Future<void> logUpdateAction(String action, String version) async {
    try {
      final logs = _prefs.getStringList('update_logs') ?? [];
      final log = {
        'action': action, // 'shown', 'dismissed', 'accepted', 'completed'
        'version': version,
        'timestamp': DateTime.now().toIso8601String(),
      };
      logs.add(log.toString());
      await _prefs.setStringList('update_logs', logs);
    } catch (e) {
      // Silently fail for logging
    }
  }

  /// Get update logs
  Future<List<String>> getUpdateLogs() async {
    return _prefs.getStringList('update_logs') ?? [];
  }
}
