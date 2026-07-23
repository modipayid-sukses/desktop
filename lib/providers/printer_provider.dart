import 'package:flutter/material.dart';
import '../models/printer_models.dart';
import '../services/printer_service.dart';

class PrinterProvider extends ChangeNotifier {
  final PrinterService _printerService = PrinterService();

  Printer? _selectedPrinter;
  List<Printer> _availablePrinters = [];
  List<PrintJob> _printQueue = [];
  bool _isInitialized = false;
  bool _isScanning = false;
  String? _errorMessage;

  // Preferences
  int _paperWidth = 58;
  double _printDensity = 1.0;
  String _headerText = 'MODIPAY';
  String _footerText = 'Thank you for your transaction';

  PrinterProvider() {
    _initializeService();
  }

  // Getters
  Printer? get selectedPrinter => _selectedPrinter;
  List<Printer> get availablePrinters => _availablePrinters;
  List<PrintJob> get printQueue => _printQueue;
  bool get isInitialized => _isInitialized;
  bool get isScanning => _isScanning;
  bool get hasSelectedPrinter => _selectedPrinter != null;
  bool get isConnected => _selectedPrinter?.isConnected ?? false;
  String? get errorMessage => _errorMessage;

  int get paperWidth => _paperWidth;
  double get printDensity => _printDensity;
  String get headerText => _headerText;
  String get footerText => _footerText;

  List<PrintJob> get pendingJobs =>
      _printQueue.where((job) => job.isPending).toList();
  List<PrintJob> get failedJobs =>
      _printQueue.where((job) => job.isFailed).toList();

  Future<void> _initializeService() async {
    try {
      await _printerService.initialize();
      _isInitialized = true;
      _loadPreferences();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> scanForPrinters({PrinterType? filterType}) async {
    try {
      _isScanning = true;
      _errorMessage = null;
      notifyListeners();

      await _printerService.discoverPrinters(filterType: filterType);
      _availablePrinters = _printerService.availablePrinters;

      _isScanning = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> connectToPrinter(Printer printer) async {
    try {
      _errorMessage = null;
      final success = await _printerService.connectToPrinter(printer);
      if (success) {
        _selectedPrinter = printer;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectPrinter() async {
    try {
      await _printerService.disconnectPrinter();
      _selectedPrinter = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<PrintResult> printReceipt(
    ReceiptData data, {
    ReceiptTemplate template = ReceiptTemplate.transaction,
  }) async {
    if (!hasSelectedPrinter) {
      return PrintResult(
        success: false,
        errorCode: 'NO_PRINTER',
        message: 'No printer selected',
      );
    }

    try {
      _errorMessage = null;
      final result = await _printerService.printReceipt(data, template: template);
      _printQueue = _printerService.printQueue;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return PrintResult(
        success: false,
        errorCode: 'PRINT_ERROR',
        message: e.toString(),
      );
    }
  }

  Future<PrintResult> printReport(Map<String, dynamic> reportData) async {
    if (!hasSelectedPrinter) {
      return PrintResult(
        success: false,
        errorCode: 'NO_PRINTER',
        message: 'No printer selected',
      );
    }

    try {
      _errorMessage = null;
      final result = await _printerService.printReport(reportData);
      _printQueue = _printerService.printQueue;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return PrintResult(
        success: false,
        errorCode: 'PRINT_ERROR',
        message: e.toString(),
      );
    }
  }

  Future<PrintResult> retryPrintJob(String jobId) async {
    try {
      _errorMessage = null;
      final result = await _printerService.retryPrintJob(jobId);
      _printQueue = _printerService.printQueue;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return PrintResult(
        success: false,
        errorCode: 'RETRY_ERROR',
        message: e.toString(),
      );
    }
  }

  Future<void> cancelPrintJob(String jobId) async {
    try {
      await _printerService.cancelPrintJob(jobId);
      _printQueue = _printerService.printQueue;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> clearPrintQueue() async {
    try {
      await _printerService.clearPrintQueue();
      _printQueue = [];
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<PrinterStatus> checkPrinterStatus() async {
    try {
      return await _printerService.checkPrinterStatus();
    } catch (e) {
      throw Exception('Failed to check printer status: $e');
    }
  }

  Stream<PrinterStatus> monitorPrinterHealth() {
    return _printerService.monitorPrinterHealth();
  }

  void setPaperWidth(int width) {
    _paperWidth = width;
    _savePaperWidth(width);
    notifyListeners();
  }

  void setPrintDensity(double density) {
    _printDensity = density;
    _savePrintDensity(density);
    notifyListeners();
  }

  void setHeaderText(String text) {
    _headerText = text;
    _saveHeaderText(text);
    notifyListeners();
  }

  void setFooterText(String text) {
    _footerText = text;
    _saveFooterText(text);
    notifyListeners();
  }

  void _loadPreferences() {
    final prefs = _printerService.getPrinterPreferences();
    if (prefs != null) {
      _paperWidth = prefs['paperWidth'] ?? 58;
      _printDensity = prefs['printDensity'] ?? 1.0;
      _headerText = prefs['headerText'] ?? 'MODIPAY';
      _footerText = prefs['footerText'] ?? 'Thank you for your transaction';
    }
  }

  void _savePaperWidth(int width) {
    _printerService.savePrinterPreferences(paperWidth: width);
  }

  void _savePrintDensity(double density) {
    _printerService.savePrinterPreferences(printDensity: density);
  }

  void _saveHeaderText(String text) {
    _printerService.savePrinterPreferences(headerText: text);
  }

  void _saveFooterText(String text) {
    _printerService.savePrinterPreferences(footerText: text);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _printerService.dispose();
    super.dispose();
  }
}
