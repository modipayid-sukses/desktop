import 'package:flutter/material.dart';
import '../services/device_verification_service.dart';
import '../services/location_security_service.dart';
import '../services/app_update_service.dart';
import '../models/device_info_model.dart';

class SecurityManager {
  static final SecurityManager _instance = SecurityManager._internal();

  late DeviceVerificationService _deviceService;
  late LocationSecurityService _locationService;
  late AppUpdateService _updateService;

  bool _initialized = false;

  factory SecurityManager() {
    return _instance;
  }

  SecurityManager._internal();

  /// Initialize all security services
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _deviceService = DeviceVerificationService();
      _locationService = LocationSecurityService();
      _updateService = AppUpdateService();

      await Future.wait([
        _deviceService.initialize(),
        _locationService.initialize(),
        _updateService.initialize(),
      ]);

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize SecurityManager: $e');
    }
  }

  /// Check if device is verified (trusted)
  Future<bool> isDeviceVerified() async {
    return await _deviceService.isCurrentDeviceTrusted();
  }

  /// Get current device info
  Future<DeviceInfo> getCurrentDeviceInfo() async {
    return await _deviceService.getCurrentDeviceInfo();
  }

  /// Verify device (add to trusted list)
  Future<void> verifyDevice(DeviceInfo device) async {
    await _deviceService.trustDevice(device);
  }

  /// Get trusted devices
  Future<List<DeviceInfo>> getTrustedDevices() async {
    return await _deviceService.getTrustedDevices();
  }

  /// Remove trusted device
  Future<void> removeTrustedDevice(String deviceId) async {
    await _deviceService.removeTrustedDevice(deviceId);
  }

  /// Validate transaction location
  Future<bool> validateTransactionLocation(double amount) async {
    return await _locationService.validateTransactionLocation(amount);
  }

  /// Check for app updates
  Future<UpdateInfo?> checkForUpdates() async {
    return await _updateService.checkForUpdates();
  }

  /// Check if update is required
  Future<bool> isUpdateRequired() async {
    return await _updateService.isUpdateRequired();
  }

  /// Check if optional update available
  Future<bool> isUpdateAvailable() async {
    return await _updateService.isUpdateAvailable();
  }

  /// Get app version
  Future<String> getAppVersion() async {
    return await _updateService.getCurrentVersion();
  }

  /// Pre-login security checks
  Future<SecurityCheckResult> preLoginSecurityCheck() async {
    try {
      final isDeviceVerified = await this.isDeviceVerified();
      final updateRequired = await isUpdateRequired();

      if (updateRequired) {
        return SecurityCheckResult(
          canProceed: false,
          reason: 'Force update required',
          updateRequired: true,
        );
      }

      return SecurityCheckResult(
        canProceed: true,
        deviceVerified: isDeviceVerified,
        updateAvailable: await isUpdateAvailable(),
      );
    } catch (e) {
      return SecurityCheckResult(
        canProceed: true,
        error: e.toString(),
      );
    }
  }

  /// Pre-transaction security checks
  Future<SecurityCheckResult> preTransactionSecurityCheck(
    double amount,
  ) async {
    try {
      final isDeviceVerified = await this.isDeviceVerified();
      final locationValid = await _locationService.validateTransactionLocation(amount);

      if (!isDeviceVerified) {
        return SecurityCheckResult(
          canProceed: false,
          reason: 'Device not verified',
          requiresDeviceVerification: true,
        );
      }

      if (!locationValid) {
        return SecurityCheckResult(
          canProceed: false,
          reason: 'Suspicious location or VPN detected',
          requiresAdditionalVerification: true,
        );
      }

      return SecurityCheckResult(
        canProceed: true,
        deviceVerified: isDeviceVerified,
      );
    } catch (e) {
      // Allow transaction on error, but log
      return SecurityCheckResult(
        canProceed: true,
        error: e.toString(),
      );
    }
  }

  /// Cleanup
  Future<void> dispose() async {
    await _locationService.clearLocationHistory();
  }

  /// Get all security services
  DeviceVerificationService get deviceService => _deviceService;
  LocationSecurityService get locationService => _locationService;
  AppUpdateService get updateService => _updateService;
}

class SecurityCheckResult {
  final bool canProceed;
  final String? reason;
  final bool deviceVerified;
  final bool updateRequired;
  final bool updateAvailable;
  final bool requiresDeviceVerification;
  final bool requiresAdditionalVerification;
  final String? error;

  SecurityCheckResult({
    this.canProceed = true,
    this.reason,
    this.deviceVerified = false,
    this.updateRequired = false,
    this.updateAvailable = false,
    this.requiresDeviceVerification = false,
    this.requiresAdditionalVerification = false,
    this.error,
  });

  @override
  String toString() {
    return 'SecurityCheckResult('
        'canProceed: $canProceed, '
        'deviceVerified: $deviceVerified, '
        'updateRequired: $updateRequired, '
        'updateAvailable: $updateAvailable, '
        'requiresDeviceVerification: $requiresDeviceVerification, '
        'requiresAdditionalVerification: $requiresAdditionalVerification, '
        'reason: $reason, '
        'error: $error)';
  }
}
