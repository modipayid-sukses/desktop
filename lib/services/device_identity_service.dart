import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a stable per-install device identity plus human-readable metadata
/// (name, platform, app version) used by the auth API for single-device login
/// enforcement and for showing the active device on the admin panel.
class DeviceIdentityService {
  static const String _prefKey = 'device_identity_v1';
  static const String _prefName = 'device_identity_name_v1';
  static const String _prefPlatform = 'device_identity_platform_v1';

  static const String appVersion = '1.0.1';

  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static String? _deviceId;
  static String? _deviceName;
  static String? _devicePlatform;

  static String? get currentDeviceId => _deviceId;
  static String? get currentDeviceName => _deviceName;
  static String? get currentDevicePlatform => _devicePlatform;

  static Future<void> initialize() async {
    if (_deviceId != null && _deviceId!.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    _deviceName = prefs.getString(_prefName);
    _devicePlatform = prefs.getString(_prefPlatform);

    final stored = prefs.getString(_prefKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      _deviceId = stored;
      // Make sure metadata is up-to-date even if the id is reused.
      await _refreshMetadata(prefs);
      debugPrint('[DeviceIdentity] Using stored device ID: $stored');
      return;
    }

    String? resolved;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use Android device identifier - id is more stable than fingerprint
        resolved = androidInfo.id.isNotEmpty ? androidInfo.id : androidInfo.fingerprint;
        _deviceName = '${androidInfo.manufacturer} ${androidInfo.model}'.trim();
        _devicePlatform = 'android ${androidInfo.version.release}';
        debugPrint('[DeviceIdentity] Android device ID: $resolved (fingerprint: ${androidInfo.fingerprint})');
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        resolved = iosInfo.identifierForVendor;
        _deviceName = iosInfo.name.isNotEmpty ? iosInfo.name : iosInfo.utsname.machine;
        _devicePlatform = 'ios ${iosInfo.systemVersion}';
        debugPrint('[DeviceIdentity] iOS identifierForVendor: $resolved');
      } else {
        _devicePlatform = 'web';
      }
    } catch (e) {
      debugPrint('[DeviceIdentity] Error reading device info: $e');
    }

    resolved = _normalizeDeviceId(resolved) ?? _generateFallbackDeviceId();
    _deviceId = resolved;
    await prefs.setString(_prefKey, resolved);
    if (_deviceName != null && _deviceName!.isNotEmpty) {
      await prefs.setString(_prefName, _deviceName!);
    }
    if (_devicePlatform != null && _devicePlatform!.isNotEmpty) {
      await prefs.setString(_prefPlatform, _devicePlatform!);
    }
    debugPrint('[DeviceIdentity] Final device ID: $resolved name=$_deviceName platform=$_devicePlatform');
  }

  static Future<void> _refreshMetadata(SharedPreferences prefs) async {
    if ((_deviceName != null && _deviceName!.isNotEmpty) &&
        (_devicePlatform != null && _devicePlatform!.isNotEmpty)) {
      return;
    }
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceName ??= '${androidInfo.manufacturer} ${androidInfo.model}'.trim();
        _devicePlatform ??= 'android ${androidInfo.version.release}';
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceName ??= iosInfo.name.isNotEmpty ? iosInfo.name : iosInfo.utsname.machine;
        _devicePlatform ??= 'ios ${iosInfo.systemVersion}';
      }
      if (_deviceName != null && _deviceName!.isNotEmpty) {
        await prefs.setString(_prefName, _deviceName!);
      }
      if (_devicePlatform != null && _devicePlatform!.isNotEmpty) {
        await prefs.setString(_prefPlatform, _devicePlatform!);
      }
    } catch (e) {
      debugPrint('[DeviceIdentity] Refresh metadata failed: $e');
    }
  }

  static Future<String> getDeviceId() async {
    await initialize();
    return _deviceId!;
  }

  /// Returns the device metadata as a map. Safe to call after [initialize].
  /// Values fall back to a sensible default when not yet resolved.
  static Map<String, String> metadata() {
    return {
      'device_id': _deviceId ?? '',
      'device_name': _deviceName ?? 'Unknown Device',
      'device_platform': _devicePlatform ?? _platformFallback(),
      'app_version': appVersion,
    };
  }

  static String _platformFallback() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }

  static String? _normalizeDeviceId(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text == 'null') {
      debugPrint('[DeviceIdentity] Invalid device ID, will use fallback');
      return null;
    }
    return text;
  }

  static String _generateFallbackDeviceId() {
    final random = Random.secure();
    final buffer = StringBuffer('modipay_');
    for (var i = 0; i < 16; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}
