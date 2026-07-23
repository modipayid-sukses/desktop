import 'package:intl/intl.dart';

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String model;
  final String osVersion;
  final DateTime lastUsed;
  final bool isTrusted;
  final String platform; // Android, iOS, Windows, macOS, Linux
  final DateTime createdAt;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.model,
    required this.osVersion,
    required this.lastUsed,
    required this.isTrusted,
    required this.platform,
    required this.createdAt,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      model: json['model'] as String,
      osVersion: json['osVersion'] as String,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
      isTrusted: json['isTrusted'] as bool,
      platform: json['platform'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'model': model,
      'osVersion': osVersion,
      'lastUsed': lastUsed.toIso8601String(),
      'isTrusted': isTrusted,
      'platform': platform,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  DeviceInfo copyWith({
    String? deviceId,
    String? deviceName,
    String? model,
    String? osVersion,
    DateTime? lastUsed,
    bool? isTrusted,
    String? platform,
    DateTime? createdAt,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      model: model ?? this.model,
      osVersion: osVersion ?? this.osVersion,
      lastUsed: lastUsed ?? this.lastUsed,
      isTrusted: isTrusted ?? this.isTrusted,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayName => '$deviceName ($model)';

  String get lastUsedFormatted {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(lastUsed);
    }
  }

  String get statusLabel => isTrusted ? 'Trusted' : 'Not Trusted';
}
