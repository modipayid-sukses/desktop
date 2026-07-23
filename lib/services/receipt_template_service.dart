import '../models/printer_models.dart';

/// ESC/POS Command Generator untuk Thermal Printer
class ReceiptTemplateGenerator {
  static const int PAPER_58MM = 58;
  static const int PAPER_80MM = 80;
  static const int CHARS_58MM = 32;
  static const int CHARS_80MM = 48;

  final int paperWidth;

  ReceiptTemplateGenerator({this.paperWidth = PAPER_58MM});

  int get maxChars => paperWidth == PAPER_58MM ? CHARS_58MM : CHARS_80MM;

  /// Generate transaction receipt
  String generateTransactionReceipt(ReceiptData data) {
    return _buildReceipt([
      _centerText('TRANSACTION RECEIPT', bold: true),
      _line(),
      _line(),
      _leftRightText('ID:', data.transactionId),
      _leftRightText('Date:', data.formattedDate),
      _leftRightText('Time:', data.formattedTime),
      _line(),
      _line(),
      if (data.recipientName != null)
        _leftText('Recipient: ${data.recipientName}'),
      if (data.recipientAccount != null)
        _leftText('Account: ${data.recipientAccount}'),
      if (data.recipientBank != null)
        _leftText('Bank: ${data.recipientBank}'),
      _line(),
      _leftRightText('Amount', data.formattedAmount, bold: true),
      if (data.fee != null && data.fee! > 0)
        _leftRightText('Fee', data.formattedFee),
      if (data.commission != null && data.commission! > 0)
        _leftRightText('Commission', data.formattedCommission),
      _doubleLine(),
      _leftRightText('Total', data.formattedTotal, bold: true, large: true),
      _doubleLine(),
      _line(),
      _centerText(data.status.toUpperCase(), bold: true),
      _line(),
      _line(),
      _centerText('Thank You!'),
      _centerText('For using our service'),
      _line(),
    ]);
  }

  /// Generate topup receipt
  String generateTopupReceipt(ReceiptData data) {
    return _buildReceipt([
      _centerText('TOP UP RECEIPT', bold: true),
      _line(),
      _line(),
      _leftRightText('ID:', data.transactionId),
      _leftRightText('Date:', data.formattedDate),
      _leftRightText('Time:', data.formattedTime),
      _line(),
      _leftText('Customer: ${data.recipientName ?? data.recipientPhone}'),
      _line(),
      _leftRightText('Amount', data.formattedAmount, bold: true),
      if (data.fee != null && data.fee! > 0)
        _leftRightText('Admin Fee', data.formattedFee),
      _doubleLine(),
      _leftRightText('Total', data.formattedTotal, bold: true, large: true),
      _doubleLine(),
      _line(),
      _centerText(data.status.toUpperCase(), bold: true),
      _line(),
      _line(),
      _centerText('Thank You!'),
      _line(),
    ]);
  }

  /// Generate PPOB payment receipt
  String generatePPOBReceipt(ReceiptData data) {
    final ppobType = data.additionalData?['type'] ?? 'PPOB';
    final customerRef = data.additionalData?['customerRef'] ?? '-';

    return _buildReceipt([
      _centerText('PAYMENT RECEIPT', bold: true),
      _centerText(ppobType),
      _line(),
      _line(),
      _leftRightText('ID:', data.transactionId),
      _leftRightText('Date:', data.formattedDate),
      _leftRightText('Time:', data.formattedTime),
      _line(),
      _leftText('Reference: $customerRef'),
      _line(),
      _leftRightText('Amount', data.formattedAmount, bold: true),
      if (data.fee != null && data.fee! > 0)
        _leftRightText('Fee', data.formattedFee),
      _doubleLine(),
      _leftRightText('Total', data.formattedTotal, bold: true, large: true),
      _doubleLine(),
      _line(),
      _centerText(data.status.toUpperCase(), bold: true),
      _line(),
      _line(),
      _centerText('Thank You!'),
      _line(),
    ]);
  }

  /// Generate settlement/daily report
  String generateSettlementReceipt(Map<String, dynamic> data) {
    final date = data['date'] as String? ?? '-';
    final totalTx = data['totalTransactions'] as int? ?? 0;
    final totalAmount = data['totalAmount'] as double? ?? 0;
    final totalFee = data['totalFees'] as double? ?? 0;
    final totalCommission = data['totalCommission'] as double? ?? 0;
    final agentName = data['agentName'] as String? ?? 'Agent';

    return _buildReceipt([
      _centerText('DAILY SETTLEMENT', bold: true),
      _line(),
      _line(),
      _leftText('Agent: $agentName'),
      _leftText('Date: $date'),
      _line(),
      _line(),
      _centerText('TRANSACTION SUMMARY', bold: true),
      _line(),
      _leftRightText('Total Transactions', totalTx.toString()),
      _line(),
      _leftRightText('Total Amount', 'Rp ${totalAmount.toStringAsFixed(0)}',
          bold: true),
      _leftRightText('Fees', 'Rp ${totalFee.toStringAsFixed(0)}'),
      _leftRightText('Commission', 'Rp ${totalCommission.toStringAsFixed(0)}',
          bold: true),
      _doubleLine(),
      _leftRightText(
          'Net Settlement',
          'Rp ${(totalAmount - totalFee).toStringAsFixed(0)}',
          bold: true,
          large: true),
      _doubleLine(),
      _line(),
      _centerText('End of Day Report'),
      _line(),
    ]);
  }

  /// Helper methods for formatting
  String _centerText(String text, {bool bold = false, bool large = false}) {
    final processedText = text.length > maxChars
        ? text.substring(0, maxChars - 3) + '...'
        : text;
    final padding = ((maxChars - processedText.length) / 2).ceil();
    return ' ' * padding + processedText;
  }

  String _leftText(String text) {
    return text.length > maxChars
        ? text.substring(0, maxChars)
        : text.padRight(maxChars);
  }

  String _leftRightText(String left, String right,
      {bool bold = false, bool large = false}) {
    final maxLeftLen = maxChars - 12;
    final leftText = left.length > maxLeftLen
        ? left.substring(0, maxLeftLen - 2) + '..'
        : left;
    final rightText = right.length > 10
        ? right.substring(0, 10)
        : right;

    final spacing = maxChars - leftText.length - rightText.length;
    return leftText + ' ' * spacing.clamp(1, 100) + rightText;
  }

  String _line() {
    return '-' * maxChars;
  }

  String _doubleLine() {
    return '=' * maxChars;
  }

  String _buildReceipt(List<String> lines) {
    return lines.join('\n') + '\n' + _line() + '\n';
  }
}

/// Receipt style presets
class ReceiptStyles {
  static const Map<String, String> headerFooter = {
    'header': 'MODIPAY',
    'subheader': 'Digital Payment Platform',
    'footer': 'Thank you for using Modipay!',
  };

  static String formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0)}';
  }

  static String formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
