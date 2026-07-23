import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../models/printer_models.dart';

class PrinterService extends ChangeNotifier {
  static final PrinterService _instance = PrinterService._internal();
  late SharedPreferences _prefs;

  List<Printer> _availablePrinters = [];
  Printer? _selectedPrinter;
  List<PrintJob> _printQueue = [];
  bool _isScanning = false;
  StreamController<PrintJob>? _jobStatusController;

  factory PrinterService() {
    return _instance;
  }

  PrinterService._internal();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _jobStatusController = StreamController<PrintJob>.broadcast();
    await _loadSavedPrinters();
    await _loadPrintQueue();
  }

  /// Getters
  List<Printer> get availablePrinters => _availablePrinters;
  Printer? get selectedPrinter => _selectedPrinter;
  List<PrintJob> get printQueue => _printQueue;
  bool get isScanning => _isScanning;
  bool get hasSelectedPrinter => _selectedPrinter != null;
  Stream<PrintJob> get jobStatusStream => _jobStatusController!.stream;

  /// Discover printers (Bluetooth, USB, Network)
  Future<void> discoverPrinters({PrinterType? filterType}) async {
    try {
      _isScanning = true;
      notifyListeners();

      _availablePrinters.clear();

      // Simulate printer discovery
      // In production, use actual packages like:
      // - blue_thermal_printer for Bluetooth
      // - esc_pos_printer for Network
      // - Platform channels for USB

      await Future.delayed(Duration(seconds: 2));

      // Example printers (would come from actual discovery)
      final examplePrinters = [
        Printer(
          id: 'bt_001',
          name: 'My Printer',
          model: 'ZJIANG ZJ-58',
          type: PrinterType.bluetooth,
          macAddress: '00:1A:7D:DA:71:13',
          isConnected: false,
          lastConnected: DateTime.now().subtract(Duration(hours: 2)),
        ),
      ];

      if (filterType != null) {
        _availablePrinters = examplePrinters
            .where((p) => p.type == filterType)
            .toList();
      } else {
        _availablePrinters = examplePrinters;
      }

      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _isScanning = false;
      notifyListeners();
      throw Exception('Failed to discover printers: $e');
    }
  }

  /// Connect to printer
  Future<bool> connectToPrinter(Printer printer) async {
    try {
      // Simulate connection
      await Future.delayed(Duration(seconds: 1));

      final connectedPrinter = printer.copyWith(
        isConnected: true,
        lastConnected: DateTime.now(),
      );

      _selectedPrinter = connectedPrinter;

      // Save as default printer
      await _saveDefaultPrinter(connectedPrinter);

      notifyListeners();
      return true;
    } catch (e) {
      throw Exception('Failed to connect to printer: $e');
    }
  }

  /// Disconnect from printer
  Future<void> disconnectPrinter() async {
    if (_selectedPrinter == null) return;

    try {
      _selectedPrinter = _selectedPrinter?.copyWith(isConnected: false);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to disconnect: $e');
    }
  }

  /// Print receipt
  Future<PrintResult> printReceipt(
    ReceiptData data, {
    ReceiptTemplate template = ReceiptTemplate.transaction,
  }) async {
    if (_selectedPrinter == null) {
      return PrintResult(
        success: false,
        errorCode: 'NO_PRINTER',
        message: 'No printer selected',
      );
    }

    try {
      final jobId = _generateJobId();
      final job = PrintJob(
        id: jobId,
        printerId: _selectedPrinter!.id,
        template: template,
        data: data.toJson(),
        status: PrintJobStatus.pending,
        createdAt: DateTime.now(),
      );

      _printQueue.add(job);
      await _savePrintQueue();

      // Simulate print processing
      _processPrintJob(job);

      return PrintResult(
        success: true,
        jobId: jobId,
        message: 'Print job queued',
      );
    } catch (e) {
      return PrintResult(
        success: false,
        errorCode: 'PRINT_ERROR',
        message: e.toString(),
      );
    }
  }

  /// Print report/document
  Future<PrintResult> printReport(Map<String, dynamic> reportData) async {
    if (_selectedPrinter == null) {
      return PrintResult(
        success: false,
        errorCode: 'NO_PRINTER',
        message: 'No printer selected',
      );
    }

    try {
      final jobId = _generateJobId();
      final job = PrintJob(
        id: jobId,
        printerId: _selectedPrinter!.id,
        template: ReceiptTemplate.report,
        data: reportData,
        status: PrintJobStatus.pending,
        createdAt: DateTime.now(),
      );

      _printQueue.add(job);
      await _savePrintQueue();

      _processPrintJob(job);

      return PrintResult(
        success: true,
        jobId: jobId,
        message: 'Report queued for printing',
      );
    } catch (e) {
      return PrintResult(
        success: false,
        errorCode: 'PRINT_ERROR',
        message: e.toString(),
      );
    }
  }

  /// Get print job status
  PrintJob? getPrintJobStatus(String jobId) {
    try {
      return _printQueue.firstWhere((job) => job.id == jobId);
    } catch (e) {
      return null;
    }
  }

  /// Get pending print jobs
  List<PrintJob> getPendingJobs() {
    return _printQueue.where((job) => job.isPending).toList();
  }

  /// Get failed print jobs
  List<PrintJob> getFailedJobs() {
    return _printQueue.where((job) => job.isFailed).toList();
  }

  /// Retry failed print job
  Future<PrintResult> retryPrintJob(String jobId) async {
    try {
      final jobIndex = _printQueue.indexWhere((job) => job.id == jobId);
      if (jobIndex == -1) {
        return PrintResult(
          success: false,
          errorCode: 'JOB_NOT_FOUND',
          message: 'Print job not found',
        );
      }

      final job = _printQueue[jobIndex];
      if (job.retryCount >= 3) {
        return PrintResult(
          success: false,
          errorCode: 'MAX_RETRIES',
          message: 'Maximum retry attempts reached',
        );
      }

      final retryJob = job.copyWith(
        status: PrintJobStatus.pending,
        retryCount: job.retryCount + 1,
        errorMessage: null,
      );

      _printQueue[jobIndex] = retryJob;
      await _savePrintQueue();

      _processPrintJob(retryJob);

      return PrintResult(
        success: true,
        jobId: jobId,
        message: 'Print job retried',
      );
    } catch (e) {
      return PrintResult(
        success: false,
        errorCode: 'RETRY_ERROR',
        message: e.toString(),
      );
    }
  }

  /// Cancel print job
  Future<void> cancelPrintJob(String jobId) async {
    try {
      final jobIndex = _printQueue.indexWhere((job) => job.id == jobId);
      if (jobIndex != -1) {
        final job = _printQueue[jobIndex];
        _printQueue[jobIndex] = job.copyWith(status: PrintJobStatus.cancelled);
        await _savePrintQueue();
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to cancel print job: $e');
    }
  }

  /// Clear print queue
  Future<void> clearPrintQueue() async {
    try {
      _printQueue.clear();
      await _prefs.remove('print_queue');
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to clear print queue: $e');
    }
  }

  /// Check printer status/health
  Future<PrinterStatus> checkPrinterStatus() async {
    if (_selectedPrinter == null) {
      throw Exception('No printer selected');
    }

    try {
      // Simulate status check
      await Future.delayed(Duration(milliseconds: 500));

      return PrinterStatus(
        isConnected: _selectedPrinter!.isConnected,
        paperLow: false,
        paperJam: false,
        batteryLevel: 85.0,
        errorMessage: null,
      );
    } catch (e) {
      throw Exception('Failed to check printer status: $e');
    }
  }

  /// Monitor printer health (stream)
  Stream<PrinterStatus> monitorPrinterHealth() async* {
    while (true) {
      try {
        final status = await checkPrinterStatus();
        yield status;
        await Future.delayed(Duration(seconds: 30)); // Check every 30s
      } catch (e) {
        // Continue monitoring despite errors
        await Future.delayed(Duration(seconds: 30));
      }
    }
  }

  /// Save printer preferences
  Future<void> savePrinterPreferences({
    int? paperWidth,
    double? printDensity,
    String? headerText,
    String? footerText,
  }) async {
    try {
      final prefs = {
        if (paperWidth != null) 'paperWidth': paperWidth,
        if (printDensity != null) 'printDensity': printDensity,
        if (headerText != null) 'headerText': headerText,
        if (footerText != null) 'footerText': footerText,
      };

      await _prefs.setString('printer_preferences', jsonEncode(prefs));
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to save printer preferences: $e');
    }
  }

  /// Get printer preferences
  Map<String, dynamic>? getPrinterPreferences() {
    try {
      final prefsStr = _prefs.getString('printer_preferences');
      if (prefsStr != null) {
        return jsonDecode(prefsStr) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Private helper methods

  void _processPrintJob(PrintJob job) async {
    try {
      final updatedJob = job.copyWith(
        status: PrintJobStatus.printing,
        startedAt: DateTime.now(),
      );

      final index = _printQueue.indexOf(job);
      if (index != -1) {
        _printQueue[index] = updatedJob;
        _jobStatusController?.add(updatedJob);
      }

      // Simulate printing
      await Future.delayed(Duration(seconds: 3));

      final completedJob = updatedJob.copyWith(
        status: PrintJobStatus.completed,
        completedAt: DateTime.now(),
      );

      if (index != -1) {
        _printQueue[index] = completedJob;
        _jobStatusController?.add(completedJob);
      }

      await _savePrintQueue();
      notifyListeners();
    } catch (e) {
      final failedJob = job.copyWith(
        status: PrintJobStatus.failed,
        errorMessage: e.toString(),
      );

      final index = _printQueue.indexOf(job);
      if (index != -1) {
        _printQueue[index] = failedJob;
        _jobStatusController?.add(failedJob);
      }

      await _savePrintQueue();
      notifyListeners();
    }
  }

  String _generateJobId() {
    return 'job_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _savePrintQueue() async {
    try {
      final jsonList = _printQueue.map((job) => job.toJson()).toList();
      await _prefs.setString('print_queue', jsonEncode(jsonList));
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadPrintQueue() async {
    try {
      final queueStr = _prefs.getString('print_queue');
      if (queueStr != null) {
        final jsonList = jsonDecode(queueStr) as List;
        _printQueue = jsonList
            .map((item) => PrintJob.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _printQueue = [];
    }
  }

  Future<void> _saveDefaultPrinter(Printer printer) async {
    try {
      await _prefs.setString('default_printer', jsonEncode(printer.toJson()));
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadSavedPrinters() async {
    try {
      final printerStr = _prefs.getString('default_printer');
      if (printerStr != null) {
        _selectedPrinter = Printer.fromJson(jsonDecode(printerStr));
      }
    } catch (e) {
      // Silently fail
    }
  }

  @override
  void dispose() {
    _jobStatusController?.close();
    super.dispose();
  }
}

class PrinterStatus {
  final bool isConnected;
  final bool paperLow;
  final bool paperJam;
  final double? batteryLevel;
  final String? errorMessage;

  PrinterStatus({
    required this.isConnected,
    required this.paperLow,
    required this.paperJam,
    this.batteryLevel,
    this.errorMessage,
  });

  bool get isHealthy => isConnected && !paperLow && !paperJam;
  bool get needsAttention => paperLow || paperJam || errorMessage != null;
}
