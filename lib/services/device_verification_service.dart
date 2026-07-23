import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/device_info_model.dart';

class DeviceVerificationService {
  static final DeviceVerificationService _instance =
      DeviceVerificationService._internal();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  late SharedPreferences _prefs;

  factory DeviceVerificationService() {
    return _instance;
  }

  DeviceVerificationService._internal();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get unique device fingerprint
  Future<String> getDeviceFingerprint() async {
    try {
      final deviceId = await _getDeviceId();
      final model = await _getDeviceModel();
      final osVersion = await _getOsVersion();

      final fingerprint = '$deviceId-$model-$osVersion';
      return fingerprint;
    } catch (e) {
      throw Exception('Failed to get device fingerprint: $e');
    }
  }

  /// Get device identifier
  Future<String> _getDeviceId() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get device model
  Future<String> _getDeviceModel() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer}-${androidInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model;
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get OS version
  Future<String> _getOsVersion() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.version.release;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.systemVersion;
      }
      return 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  /// Get device name (customizable)
  Future<String> _getDeviceName() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model;
      }
      return 'Device';
    } catch (e) {
      return 'Device';
    }
  }

  /// Get current device info
  Future<DeviceInfo> getCurrentDeviceInfo() async {
    final fingerprint = await getDeviceFingerprint();
    final model = await _getDeviceModel();
    final osVersion = await _getOsVersion();
    final deviceName = await _getDeviceName();

    return DeviceInfo(
      deviceId: fingerprint,
      deviceName: deviceName,
      model: model,
      osVersion: osVersion,
      lastUsed: DateTime.now(),
      isTrusted: false,
      platform: defaultTargetPlatform.toString().split('.').last,
      createdAt: DateTime.now(),
    );
  }

  /// Save device as trusted
  Future<void> trustDevice(DeviceInfo device) async {
    final trustedDevices = await getTrustedDevices();
    final updatedDevice = device.copyWith(isTrusted: true);

    // Remove if already exists
    trustedDevices.removeWhere((d) => d.deviceId == device.deviceId);

    trustedDevices.add(updatedDevice);
    await _saveTrustedDevices(trustedDevices);
  }

  /// Remove device from trusted
  Future<void> removeTrustedDevice(String deviceId) async {
    final trustedDevices = await getTrustedDevices();
    trustedDevices.removeWhere((d) => d.deviceId == deviceId);
    await _saveTrustedDevices(trustedDevices);
  }

  /// Get list of trusted devices
  Future<List<DeviceInfo>> getTrustedDevices() async {
    try {
      final jsonString = _prefs.getString('trusted_devices') ?? '[]';
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => DeviceInfo.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if current device is trusted
  Future<bool> isCurrentDeviceTrusted() async {
    final fingerprint = await getDeviceFingerprint();
    final trustedDevices = await getTrustedDevices();
    return trustedDevices.any((d) => d.deviceId == fingerprint);
  }

  /// Save trusted devices locally (encrypted)
  Future<void> _saveTrustedDevices(List<DeviceInfo> devices) async {
    try {
      final jsonList = devices.map((d) => d.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString('trusted_devices', jsonString);
    } catch (e) {
      throw Exception('Failed to save trusted devices: $e');
    }
  }

  /// Update last used time for device
  Future<void> updateLastUsed(String deviceId) async {
    final trustedDevices = await getTrustedDevices();
    final index = trustedDevices.indexWhere((d) => d.deviceId == deviceId);

    if (index != -1) {
      final updated = trustedDevices[index].copyWith(
        lastUsed: DateTime.now(),
      );
      trustedDevices[index] = updated;
      await _saveTrustedDevices(trustedDevices);
    }
  }

  /// Clear all trusted devices
  Future<void> clearAllTrustedDevices() async {
    await _prefs.setString('trusted_devices', '[]');
  }
}
