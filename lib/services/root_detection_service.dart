import 'dart:io';
import 'package:flutter/services.dart';

class RootDetectionService {
  static const MethodChannel _securityChannel = MethodChannel('modipay/security');

  /// Check if device is rooted (Android) or jailbroken (iOS)
  static Future<bool> isDeviceRooted() async {
    try {
      if (Platform.isAndroid) {
        return await _isAndroidRooted();
      } else if (Platform.isIOS) {
        return await _isIOSJailbroken();
      }
      return false;
    } catch (e) {
      print('Root detection error: $e');
      return false;
    }
  }

  /// Check whether Developer Mode / USB debugging is enabled.
  static Future<bool> isDeveloperModeEnabled() async {
    try {
      if (Platform.isAndroid) {
        final result = await _securityChannel.invokeMethod<bool>(
          'isDeveloperModeEnabled',
        );
        return result ?? false;
      }

      // iOS does not expose a reliable public API for Developer Mode state.
      return false;
    } catch (e) {
      print('Developer mode detection error: $e');
      return false;
    }
  }

  /// Returns true when device should be blocked for security reasons.
  static Future<bool> isDeviceCompromised() async {
    final isRooted = await isDeviceRooted();
    final isDeveloperMode = await isDeveloperModeEnabled();
    return isRooted || isDeveloperMode;
  }

  /// Check if Android device is rooted
  static Future<bool> _isAndroidRooted() async {
    try {
      // Check for common root binaries
      final List<String> rootBinaries = [
        '/system/bin/su',
        '/system/bin/busybox',
        '/system/xbin/su',
        '/data/local/tmp/su',
        '/data/local/su',
        '/system/su',
      ];

      for (String binary in rootBinaries) {
        if (await File(binary).exists()) {
          return true;
        }
      }

      // Check for Magisk
      if (await Directory('/data/adb/modules').exists()) {
        return true;
      }

      // Check for SuperSU
      if (await File('/system/app/Superuser.apk').exists() ||
          await File('/system/app/superuser.apk').exists()) {
        return true;
      }

      return false;
    } catch (e) {
      print('Android root detection error: $e');
      return false;
    }
  }

  /// Check if iOS device is jailbroken (basic check - iOS has limitations)
  static Future<bool> _isIOSJailbroken() async {
    try {
      final List<String> jailbreakPaths = [
        '/Applications/Cydia.app',
        '/Library/MobileSubstrate/MobileSubstrate.dylib',
        '/bin/bash',
        '/usr/sbin/sshd',
        '/etc/apt',
        '/Applications/FakeCarrier.app',
        '/Applications/blackra1n.app',
      ];

      for (String path in jailbreakPaths) {
        if (await File(path).exists() || await Directory(path).exists()) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('iOS jailbreak detection error: $e');
      return false;
    }
  }

  /// Get device security status
  /// Returns true if device is safe (not rooted)
  static Future<bool> isDeviceSafe() async {
    final isCompromised = await isDeviceCompromised();
    return !isCompromised;
  }
}
