import '../models/printer_models.dart';
import 'package:intl/intl.dart';

class ReceiptTemplate {
  final int paperWidth; // 58 or 80mm
  final double printDensity;
  final String headerText;
  final String footerText;

  ReceiptTemplate({
    this.paperWidth = 58,
    this.printDensity = 1.0,
    this.headerText = 'MODIPAY',
    this.footerText = 'Thank you',
  });

  /// Generate ESC/POS receipt data
  List<int> generateReceiptData(
    ReceiptData data,
    ReceiptTemplateType templateType,
  ) {
    final buffer = <int>[];

    // Initialize printer
    buffer.addAll(_initializePrinter());

    // Header
    buffer.addAll(_addHeader());

    // Content based on template type
    switch (templateType) {
      case ReceiptTemplateType.transaction:
        buffer.addAll(_addTransactionReceipt(data));
        break;
      case ReceiptTemplateType.topup:
        buffer.addAll(_addTopupReceipt(data));
        break;
      case ReceiptTemplateType.transfer:
        buffer.addAll(_addTransferReceipt(data));
        break;
      case ReceiptTemplateType.ppob:
        buffer.addAll(_addPpobReceipt(data));
        break;
      case ReceiptTemplateType.settlement:
        buffer.addAll(_addSettlementReceipt(data));
        break;
      case ReceiptTemplateType.report:
        buffer.addAll(_addReportReceipt(data));
        break;
    }

    // Footer
    buffer.addAll(_addFooter());

    // Cut paper
    buffer.addAll(_cutPaper());

    return buffer;
  }

  List<int> _initializePrinter() {
    return [
      0x1B, 0x40, // ESC @ - Initialize printer
      0x1B, 0x43, 0x00, // ESC C - Set print area
    ];
  }

  List<int> _addHeader() {
    final buffer = <int>[];

    // Set font size
    buffer.addAll([0x1D, 0x21, 0x11]); // GS ! - Double height, double width

    // Center alignment
    buffer.addAll([0x1B, 0x61, 0x01]); // ESC a - Center

    // Print header text
    buffer.addAll(_stringToBytes(headerText));
    buffer.addAll(_stringToBytes('\n'));

    // Reset font size
    buffer.addAll([0x1D, 0x21, 0x00]); // GS ! - Normal size

    // Separator line
    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    return buffer;
  }

  List<int> _addTransactionReceipt(ReceiptData data) {
    final buffer = <int>[];

    // Left alignment
    buffer.addAll([0x1B, 0x61, 0x00]); // ESC a - Left

    // Transaction ID
    buffer.addAll(_addRow('Transaction ID', data.transactionId));

    // Type and Date
    buffer.addAll(_addRow('Type', data.type.toUpperCase()));
    buffer.addAll(_addRow('Date', data.formattedDate));
    buffer.addAll(_addRow('Time', data.formattedTime));

    buffer.addAll(_stringToBytes('\n'));

    // Recipient info (if available)
    if (data.recipientName != null) {
      buffer.addAll(_addRow('To', data.recipientName!));
    }
    if (data.recipientAccount != null) {
      buffer.addAll(_addRow('Account', data.recipientAccount!));
    }
    if (data.recipientBank != null) {
      buffer.addAll(_addRow('Bank', data.recipientBank!));
    }

    if (data.recipientName != null ||
        data.recipientAccount != null ||
        data.recipientBank != null) {
      buffer.addAll(_stringToBytes('\n'));
    }

    // Separator
    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    // Amount details
    buffer.addAll(_addDoubleRow('Amount', data.formattedAmount));
    if (data.fee != null && data.fee! > 0) {
      buffer.addAll(_addDoubleRow('Fee', data.formattedFee));
    }

    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    // Total (highlighted)
    buffer.addAll([0x1D, 0x21, 0x11]); // GS ! - Double size
    buffer.addAll(_addDoubleRow('TOTAL', data.formattedTotal));
    buffer.addAll([0x1D, 0x21, 0x00]); // GS ! - Normal size

    buffer.addAll(_stringToBytes('\n'));

    // Status
    final statusText = 'Status: ${data.status.toUpperCase()}';
    buffer.addAll(_addCenteredText(statusText));

    return buffer;
  }

  List<int> _addTopupReceipt(ReceiptData data) {
    final buffer = <int>[];

    // Left alignment
    buffer.addAll([0x1B, 0x61, 0x00]); // ESC a - Left

    buffer.addAll(_addRow('Transaction ID', data.transactionId));
    buffer.addAll(_addRow('Type', 'TOP UP'));
    buffer.addAll(_addRow('Date', data.formattedDate));
    buffer.addAll(_addRow('Time', data.formattedTime));

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll(_addDoubleRow('Amount', data.formattedAmount));
    if (data.fee != null && data.fee! > 0) {
      buffer.addAll(_addDoubleRow('Fee', data.formattedFee));
    }

    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll([0x1D, 0x21, 0x11]); // GS ! - Double size
    buffer.addAll(_addDoubleRow('TOTAL', data.formattedTotal));
    buffer.addAll([0x1D, 0x21, 0x00]); // GS ! - Normal size

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_addCenteredText('Status: ${data.status.toUpperCase()}'));

    return buffer;
  }

  List<int> _addTransferReceipt(ReceiptData data) {
    final buffer = <int>[];

    // Left alignment
    buffer.addAll([0x1B, 0x61, 0x00]); // ESC a - Left

    buffer.addAll(_addRow('Transaction ID', data.transactionId));
    buffer.addAll(_addRow('Type', 'TRANSFER'));
    buffer.addAll(_addRow('Date', data.formattedDate));
    buffer.addAll(_addRow('Time', data.formattedTime));

    buffer.addAll(_stringToBytes('\n'));

    if (data.recipientName != null || data.recipientAccount != null) {
      if (data.recipientName != null) {
        buffer.addAll(_addRow('To', data.recipientName!));
      }
      if (data.recipientAccount != null) {
        buffer.addAll(_addRow('Account', data.recipientAccount!));
      }
      if (data.recipientBank != null) {
        buffer.addAll(_addRow('Bank', data.recipientBank!));
      }
      buffer.addAll(_stringToBytes('\n'));
    }

    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll(_addDoubleRow('Amount', data.formattedAmount));
    if (data.fee != null && data.fee! > 0) {
      buffer.addAll(_addDoubleRow('Fee', data.formattedFee));
    }

    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll([0x1D, 0x21, 0x11]); // GS ! - Double size
    buffer.addAll(_addDoubleRow('TOTAL', data.formattedTotal));
    buffer.addAll([0x1D, 0x21, 0x00]); // GS ! - Normal size

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_addCenteredText('Status: ${data.status.toUpperCase()}'));

    return buffer;
  }

  List<int> _addPpobReceipt(ReceiptData data) {
    final buffer = <int>[];

    // Left alignment
    buffer.addAll([0x1B, 0x61, 0x00]); // ESC a - Left

    buffer.addAll(_addRow('Transaction ID', data.transactionId));
    buffer.addAll(_addRow('Type', 'PPOB'));
    buffer.addAll(_addRow('Date', data.formattedDate));
    buffer.addAll(_addRow('Time', data.formattedTime));

    buffer.addAll(_stringToBytes('\n'));

    if (data.recipientName != null) {
      buffer.addAll(_addRow('Provider', data.recipientName!));
    }
    if (data.recipientAccount != null) {
      buffer.addAll(_addRow('Customer', data.recipientAccount!));
    }

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll(_addDoubleRow('Amount', data.formattedAmount));
    if (data.fee != null && data.fee! > 0) {
      buffer.addAll(_addDoubleRow('Fee', data.formattedFee));
    }

    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll([0x1D, 0x21, 0x11]); // GS ! - Double size
    buffer.addAll(_addDoubleRow('TOTAL', data.formattedTotal));
    buffer.addAll([0x1D, 0x21, 0x00]); // GS ! - Normal size

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_addCenteredText('Status: ${data.status.toUpperCase()}'));

    return buffer;
  }

  List<int> _addSettlementReceipt(ReceiptData data) {
    final buffer = <int>[];

    // Center alignment
    buffer.addAll([0x1B, 0x61, 0x01]); // ESC a - Center

    buffer.addAll([0x1D, 0x21, 0x11]); // GS ! - Double size
    buffer.addAll(_stringToBytes('SETTLEMENT REPORT'));
    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll([0x1D, 0x21, 0x00]); // GS ! - Normal size

    // Left alignment
    buffer.addAll([0x1B, 0x61, 0x00]); // ESC a - Left

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_addRow('Date', data.formattedDate));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    // Settlement info (from data.additionalData if available)
    if (data.additionalData != null) {
      final totalTransactions =
          data.additionalData!['totalTransactions'] ?? 0;
      final successCount = data.additionalData!['successCount'] ?? 0;

      buffer.addAll(_addRow('Total Transactions',
          totalTransactions.toString()));
      buffer.addAll(_addRow('Successful', successCount.toString()));
    }

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll(_addDoubleRow('Total Amount', data.formattedAmount));
    if (data.commission != null && data.commission! > 0) {
      buffer.addAll(_addDoubleRow('Commission', data.formattedCommission));
    }
    if (data.fee != null && data.fee! > 0) {
      buffer.addAll(_addDoubleRow('Fees', data.formattedFee));
    }

    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll([0x1D, 0x21, 0x11]); // GS ! - Double size
    buffer.addAll(_addDoubleRow('NET SETTLEMENT', data.formattedTotal));
    buffer.addAll([0x1D, 0x21, 0x00]); // GS ! - Normal size

    return buffer;
  }

  List<int> _addReportReceipt(ReceiptData data) {
    final buffer = <int>[];

    // Center alignment
    buffer.addAll([0x1B, 0x61, 0x01]); // ESC a - Center

    buffer.addAll([0x1D, 0x21, 0x11]); // GS ! - Double size
    buffer.addAll(_stringToBytes('TRANSACTION REPORT'));
    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll([0x1D, 0x21, 0x00]); // GS ! - Normal size

    // Left alignment
    buffer.addAll([0x1B, 0x61, 0x00]); // ESC a - Left

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_addRow('Generated', data.formattedDate));
    buffer.addAll(_addRow('Time', data.formattedTime));
    buffer.addAll(_stringToBytes('\n'));

    buffer.addAll(_stringToBytes('-' * 32));
    buffer.addAll(_stringToBytes('\n'));

    if (data.additionalData != null) {
      final reportData = data.additionalData!;
      if (reportData['summary'] != null) {
        buffer.addAll(_stringToBytes(reportData['summary']));
      }
    }

    buffer.addAll(_stringToBytes('\n'));

    return buffer;
  }

  List<int> _addFooter() {
    final buffer = <int>[];

    // Center alignment
    buffer.addAll([0x1B, 0x61, 0x01]); // ESC a - Center

    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_stringToBytes(footerText));
    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_stringToBytes('www.modipay.id'));
    buffer.addAll(_stringToBytes('\n'));

    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    buffer.addAll(_stringToBytes(timestamp));
    buffer.addAll(_stringToBytes('\n'));
    buffer.addAll(_stringToBytes('\n'));

    return buffer;
  }

  List<int> _cutPaper() {
    return [
      0x1B, 0x69, // ESC i - Partial cut
    ];
  }

  List<int> _addRow(String label, String value) {
    final buffer = <int>[];
    final maxLen = 32;
    final labelLen = label.length;
    final spaces = maxLen - labelLen - value.length;

    buffer.addAll(_stringToBytes('$label${' ' * spaces}$value\n'));
    return buffer;
  }

  List<int> _addDoubleRow(String label, String value) {
    final buffer = <int>[];
    buffer.addAll([0x1B, 0x61, 0x00]); // ESC a - Left

    final maxLen = 32;
    final labelLen = label.length;
    final spaces = maxLen - labelLen - value.length;

    buffer.addAll(_stringToBytes('$label${' ' * spaces}$value\n'));
    return buffer;
  }

  List<int> _addCenteredText(String text) {
    final buffer = <int>[];
    buffer.addAll([0x1B, 0x61, 0x01]); // ESC a - Center
    buffer.addAll(_stringToBytes('$text\n'));
    buffer.addAll([0x1B, 0x61, 0x00]); // ESC a - Left
    return buffer;
  }

  List<int> _stringToBytes(String text) {
    return text.codeUnits;
  }
}

enum ReceiptTemplateType {
  transaction,
  topup,
  transfer,
  ppob,
  settlement,
  report,
}
