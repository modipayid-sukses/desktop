import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'timestamp': timestamp.toIso8601String(),
      };
}

class LocationSecurityService {
  static final LocationSecurityService _instance =
      LocationSecurityService._internal();
  late SharedPreferences _prefs;
  LocationData? _lastKnownLocation;

  factory LocationSecurityService() {
    return _instance;
  }

  LocationSecurityService._internal();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLastKnownLocation();
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        return result == LocationPermission.whileInUse ||
            result == LocationPermission.always;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      return false;
    }
  }

  /// Get current device location
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      final location = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );

      _lastKnownLocation = location;
      await _saveLastKnownLocation(location);

      return location;
    } catch (e) {
      return null;
    }
  }

  /// Check if location is suspicious
  Future<bool> isLocationSuspicious() async {
    try {
      if (_lastKnownLocation == null) return false;

      final currentLocation = await getCurrentLocation();
      if (currentLocation == null) return false;

      // Calculate distance between last and current location
      final distance = _calculateDistance(
        _lastKnownLocation!.latitude,
        _lastKnownLocation!.longitude,
        currentLocation.latitude,
        currentLocation.longitude,
      );

      // Time difference in hours
      final timeDifference =
          currentLocation.timestamp.difference(_lastKnownLocation!.timestamp);
      final hours = timeDifference.inMinutes / 60;

      // Flag if traveled > 100km in < 1 hour (average speed: 100km/h)
      if (distance > 100 && hours < 1) {
        return true;
      }

      // Flag if impossible speed (> 900 km/h typical plane speed)
      if (distance > 900 && hours < 1) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Detect VPN/Proxy usage (basic detection via connectivity)
  Future<bool> isVPNDetected() async {
    try {
      // Note: Complete VPN detection requires platform-specific implementation
      // This is a simplified check - would need native code for accurate detection
      final lastVpnStatus =
          _prefs.getBool('last_known_vpn_status') ?? false;
      return lastVpnStatus;
    } catch (e) {
      return false;
    }
  }

  /// Validate transaction based on location
  Future<bool> validateTransactionLocation(double transactionAmount) async {
    try {
      final isSuspicious = await isLocationSuspicious();
      final isVpn = await isVPNDetected();

      // Rp 1,000,000 = 1M
      const vpnThreshold = 1000000.0;

      // Block if VPN detected and transaction > Rp 1M
      if (isVpn && transactionAmount > vpnThreshold) {
        return false;
      }

      // Allow suspicious locations (but may require verification)
      if (isSuspicious) {
        await _logLocationAnomalies('suspicious_location', transactionAmount);
        return true; // Still allow, but log for verification
      }

      return true;
    } catch (e) {
      return true; // Default allow on error
    }
  }

  /// Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Log location anomalies for audit
  Future<void> _logLocationAnomalies(String type, double amount) async {
    try {
      final currentLocation = await getCurrentLocation();
      if (currentLocation == null) return;

      final logs = _prefs.getStringList('location_anomalies') ?? [];
      final log = {
        'type': type,
        'amount': amount,
        'location': {
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };

      logs.add(log.toString());
      await _prefs.setStringList('location_anomalies', logs);
    } catch (e) {
      // Silently fail for logging
    }
  }

  /// Get location history for audit
  Future<List<String>> getLocationAnomalyLog() async {
    return _prefs.getStringList('location_anomalies') ?? [];
  }

  /// Save last known location
  Future<void> _saveLastKnownLocation(LocationData location) async {
    try {
      await _prefs.setString('last_location', location.toJson().toString());
    } catch (e) {
      // Silently fail
    }
  }

  /// Load last known location
  Future<void> _loadLastKnownLocation() async {
    try {
      final locationStr = _prefs.getString('last_location');
      if (locationStr != null) {
        // Parse and restore location (simplified)
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear location history
  Future<void> clearLocationHistory() async {
    await _prefs.remove('last_location');
    await _prefs.remove('location_anomalies');
    _lastKnownLocation = null;
  }
}
