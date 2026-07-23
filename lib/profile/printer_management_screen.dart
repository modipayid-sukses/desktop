import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/printer_models.dart';
import '../services/printer_service.dart';

class PrinterManagementScreen extends StatefulWidget {
  @override
  State<PrinterManagementScreen> createState() =>
      _PrinterManagementScreenState();
}

class _PrinterManagementScreenState extends State<PrinterManagementScreen> {
  bool _isScanning = false;
  String? _errorMessage;
  PrinterStatus? _printerStatus;

  @override
  void initState() {
    super.initState();
    _checkPrinterStatus();
  }

  Future<void> _checkPrinterStatus() async {
    try {
      final printerService =
          Provider.of<PrinterService>(context, listen: false);
      if (printerService.hasSelectedPrinter) {
        final status = await printerService.checkPrinterStatus();
        setState(() => _printerStatus = status);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _scanForPrinters() async {
    try {
      setState(() {
        _isScanning = true;
        _errorMessage = null;
      });

      final printerService =
          Provider.of<PrinterService>(context, listen: false);
      await printerService.discoverPrinters();

      if (mounted) {
        setState(() => _isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan complete'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _connectToPrinter(Printer printer) async {
    try {
      final printerService =
          Provider.of<PrinterService>(context, listen: false);
      final success = await printerService.connectToPrinter(printer);

      if (success && mounted) {
        _checkPrinterStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${printer.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  Future<void> _testPrint() async {
    try {
      final printerService =
          Provider.of<PrinterService>(context, listen: false);

      final testData = ReceiptData(
        transactionId: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
        type: 'test',
        recipientName: 'Test Recipient',
        recipientAccount: '1234567890',
        amount: 100000.0,
        fee: 2500.0,
        timestamp: DateTime.now(),
        status: 'success',
      );

      final result = await printerService.printReceipt(
        testData,
        template: ReceiptTemplate.transaction,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? 'Test print sent' : result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Printer Management'),
        elevation: 0,
      ),
      body: Consumer<PrinterService>(
        builder: (context, printerService, _) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[900]),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 20),
                          onPressed: () =>
                              setState(() => _errorMessage = null),
                        ),
                      ],
                    ),
                  ),

                // Scan section
                Text(
                  'Discover Printers',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanForPrinters,
                    icon: _isScanning
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(Icons.search),
                    label: Text(_isScanning
                        ? 'Scanning for printers...'
                        : 'Scan for Printers'),
                  ),
                ),
                SizedBox(height: 24),

                // Available printers
                Text(
                  'Available Printers (${printerService.availablePrinters.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 12),
                if (printerService.availablePrinters.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No printers found. Tap scan to search.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: printerService.availablePrinters.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final printer = printerService.availablePrinters[index];
                      final isSelected =
                          printerService.selectedPrinter?.id == printer.id;

                      return Card(
                        elevation: isSelected ? 4 : 0,
                        color: isSelected ? Colors.blue[50] : Colors.white,
                        child: ListTile(
                          leading: Icon(
                            _getIconForPrinterType(printer.type),
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                          title: Text(printer.displayName),
                          subtitle: Text(
                            '${printer.typeLabel} • ${printer.connectionInfo}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                          onTap: () => _connectToPrinter(printer),
                        ),
                      );
                    },
                  ),
                SizedBox(height: 24),

                // Connected printer section
                if (printerService.hasSelectedPrinter)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected Printer',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        color: Colors.green[50],
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        printerService.selectedPrinter!.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        printerService.selectedPrinter!.model,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Connected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[900],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              if (_printerStatus != null)
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _buildStatusRow(
                                      'Paper Status',
                                      _printerStatus!.paperLow
                                          ? 'Low'
                                          : 'OK',
                                      _printerStatus!.paperLow
                                          ? Colors.orange
                                          : Colors.green,
                                    ),
                                    SizedBox(height: 8),
                                    if (_printerStatus!.batteryLevel !=
                                        null)
                                      _buildStatusRow(
                                        'Battery',
                                        '${_printerStatus!.batteryLevel!.toStringAsFixed(0)}%',
                                        Colors.blue,
                                      ),
                                    SizedBox(height: 8),
                                    _buildStatusRow(
                                      'Jam Detection',
                                      _printerStatus!.paperJam
                                          ? 'Jam Detected'
                                          : 'Clear',
                                      _printerStatus!.paperJam
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ],
                                ),
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _testPrint,
                                  icon: Icon(Icons.print),
                                  label: Text('Test Print'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                    ],
                  ),

                // Print queue section
                Text(
                  'Print Queue (${printerService.printQueue.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 12),
                if (printerService.printQueue.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No pending print jobs',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: printerService.printQueue.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final job = printerService.printQueue[index];
                      return _buildPrintJobCard(job, printerService);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrintJobCard(PrintJob job, PrinterService printerService) {
    return Card(
      child: ListTile(
        leading: _getStatusIcon(job.status),
        title: Text(job.template.name.toUpperCase()),
        subtitle: Text(
          '${job.statusLabel} • ${job.durationLabel}',
          style: TextStyle(fontSize: 12),
        ),
        trailing: job.isFailed
            ? TextButton.icon(
                onPressed: () =>
                    printerService.retryPrintJob(job.id),
                icon: Icon(Icons.refresh, size: 18),
                label: Text('Retry'),
              )
            : null,
      ),
    );
  }

  IconData _getIconForPrinterType(PrinterType type) {
    switch (type) {
      case PrinterType.bluetooth:
        return Icons.bluetooth;
      case PrinterType.usb:
        return Icons.usb;
      case PrinterType.network:
        return Icons.router;
    }
  }

  Icon _getStatusIcon(PrintJobStatus status) {
    switch (status) {
      case PrintJobStatus.pending:
        return Icon(Icons.schedule, color: Colors.grey);
      case PrintJobStatus.printing:
        return Icon(Icons.hourglass_top, color: Colors.blue);
      case PrintJobStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green);
      case PrintJobStatus.failed:
        return Icon(Icons.error, color: Colors.red);
      case PrintJobStatus.cancelled:
        return Icon(Icons.cancel, color: Colors.orange);
    }
  }
}
