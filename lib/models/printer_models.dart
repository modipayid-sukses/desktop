import 'package:intl/intl.dart';

enum PrinterType {
  bluetooth,
  usb,
  network,
}

enum ReceiptTemplate {
  transaction,
  topup,
  transfer,
  ppob,
  settlement,
  report,
}

enum PrintJobStatus {
  pending,
  printing,
  completed,
  failed,
  cancelled,
}

class Printer {
  final String id;
  final String name;
  final String model;
  final PrinterType type;
  final String? macAddress;
  final String? ipAddress;
  final int? port;
  final bool isConnected;
  final DateTime lastConnected;
  final int paperWidth; // 58mm or 80mm
  final double? batteryLevel; // Percentage, null if not applicable
  final String? status; // Paper jam, low paper, etc.

  Printer({
    required this.id,
    required this.name,
    required this.model,
    required this.type,
    this.macAddress,
    this.ipAddress,
    this.port,
    required this.isConnected,
    required this.lastConnected,
    this.paperWidth = 58,
    this.batteryLevel,
    this.status,
  });

  factory Printer.fromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String,
      type: PrinterType.values.byName(json['type'] as String),
      macAddress: json['macAddress'] as String?,
      ipAddress: json['ipAddress'] as String?,
      port: json['port'] as int?,
      isConnected: json['isConnected'] as bool,
      lastConnected: DateTime.parse(json['lastConnected'] as String),
      paperWidth: json['paperWidth'] as int? ?? 58,
      batteryLevel: json['batteryLevel'] as double?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      'type': type.name,
      'macAddress': macAddress,
      'ipAddress': ipAddress,
      'port': port,
      'isConnected': isConnected,
      'lastConnected': lastConnected.toIso8601String(),
      'paperWidth': paperWidth,
      'batteryLevel': batteryLevel,
      'status': status,
    };
  }

  Printer copyWith({
    String? id,
    String? name,
    String? model,
    PrinterType? type,
    String? macAddress,
    String? ipAddress,
    int? port,
    bool? isConnected,
    DateTime? lastConnected,
    int? paperWidth,
    double? batteryLevel,
    String? status,
  }) {
    return Printer(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      type: type ?? this.type,
      macAddress: macAddress ?? this.macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      isConnected: isConnected ?? this.isConnected,
      lastConnected: lastConnected ?? this.lastConnected,
      paperWidth: paperWidth ?? this.paperWidth,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      status: status ?? this.status,
    );
  }

  String get typeLabel {
    switch (type) {
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.usb:
        return 'USB';
      case PrinterType.network:
        return 'Network';
    }
  }

  String get displayName => '$name ($model)';

  String get connectionInfo {
    if (type == PrinterType.bluetooth) {
      return macAddress ?? 'Unknown';
    } else if (type == PrinterType.network) {
      return '$ipAddress${port != null ? ':$port' : ''}';
    }
    return 'USB';
  }
}

class PrintJob {
  final String id;
  final String printerId;
  final ReceiptTemplate template;
  final Map<String, dynamic> data;
  final PrintJobStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int retryCount;
  final String? errorMessage;

  PrintJob({
    required this.id,
    required this.printerId,
    required this.template,
    required this.data,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.retryCount = 0,
    this.errorMessage,
  });

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    return PrintJob(
      id: json['id'] as String,
      printerId: json['printerId'] as String,
      template: ReceiptTemplate.values.byName(json['template'] as String),
      data: json['data'] as Map<String, dynamic>,
      status: PrintJobStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt:
          json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      retryCount: json['retryCount'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'printerId': printerId,
      'template': template.name,
      'data': data,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'retryCount': retryCount,
      'errorMessage': errorMessage,
    };
  }

  PrintJob copyWith({
    String? id,
    String? printerId,
    ReceiptTemplate? template,
    Map<String, dynamic>? data,
    PrintJobStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? retryCount,
    String? errorMessage,
  }) {
    return PrintJob(
      id: id ?? this.id,
      printerId: printerId ?? this.printerId,
      template: template ?? this.template,
      data: data ?? this.data,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isPending => status == PrintJobStatus.pending;
  bool get isPrinting => status == PrintJobStatus.printing;
  bool get isCompleted => status == PrintJobStatus.completed;
  bool get isFailed => status == PrintJobStatus.failed;
  bool get isCancelled => status == PrintJobStatus.cancelled;

  String get statusLabel {
    switch (status) {
      case PrintJobStatus.pending:
        return 'Pending';
      case PrintJobStatus.printing:
        return 'Printing';
      case PrintJobStatus.completed:
        return 'Completed';
      case PrintJobStatus.failed:
        return 'Failed';
      case PrintJobStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get durationLabel {
    if (startedAt == null || completedAt == null) {
      return '';
    }
    final duration = completedAt!.difference(startedAt!);
    return '${duration.inSeconds}s';
  }
}

class PrintResult {
  final bool success;
  final String? message;
  final String? jobId;
  final String? errorCode;

  PrintResult({
    required this.success,
    this.message,
    this.jobId,
    this.errorCode,
  });
}

class ReceiptData {
  final String transactionId;
  final String type; // transaction, topup, transfer, etc.
  final String? recipientName;
  final String? recipientAccount;
  final String? recipientBank;
  final double amount;
  final double? fee;
  final double? commission;
  final DateTime timestamp;
  final String status;
  final Map<String, dynamic>? additionalData;

  ReceiptData({
    required this.transactionId,
    required this.type,
    this.recipientName,
    this.recipientAccount,
    this.recipientBank,
    required this.amount,
    this.fee,
    this.commission,
    required this.timestamp,
    required this.status,
    this.additionalData,
  });

  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      transactionId: json['transactionId'] as String,
      type: json['type'] as String,
      recipientName: json['recipientName'] as String?,
      recipientAccount: json['recipientAccount'] as String?,
      recipientBank: json['recipientBank'] as String?,
      amount: (json['amount'] as num).toDouble(),
      fee: json['fee'] != null ? (json['fee'] as num).toDouble() : null,
      commission: json['commission'] != null
          ? (json['commission'] as num).toDouble()
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: json['status'] as String,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'type': type,
      'recipientName': recipientName,
      'recipientAccount': recipientAccount,
      'recipientBank': recipientBank,
      'amount': amount,
      'fee': fee,
      'commission': commission,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'additionalData': additionalData,
    };
  }

  String get formattedAmount => 'Rp ${amount.toStringAsFixed(0)}';
  String get formattedFee => fee != null ? 'Rp ${fee!.toStringAsFixed(0)}' : '-';
  String get formattedCommission =>
      commission != null ? 'Rp ${commission!.toStringAsFixed(0)}' : '-';
  String get formattedTotal =>
      'Rp ${(amount + (fee ?? 0)).toStringAsFixed(0)}';
  String get formattedTime => DateFormat('HH:mm:ss').format(timestamp);
  String get formattedDate => DateFormat('dd MMM yyyy').format(timestamp);
}
