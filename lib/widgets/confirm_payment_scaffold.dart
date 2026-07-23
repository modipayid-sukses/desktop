import 'package:flutter/material.dart';
import 'pin_dots_field.dart';

class ConfirmPaymentScaffold extends StatefulWidget {
  final String title;
  final Widget transactionDetails;
  final String totalAmount;
  final String? subtotal;
  final String? fee;
  final String? discount;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool requirePin;
  final bool showReceipt;
  final Function(String)? onPinVerified;
  final String? description;

  const ConfirmPaymentScaffold({
    required this.title,
    required this.transactionDetails,
    required this.totalAmount,
    this.subtotal,
    this.fee,
    this.discount,
    required this.onConfirm,
    this.onCancel,
    this.requirePin = true,
    this.showReceipt = true,
    this.onPinVerified,
    this.description,
  });

  @override
  State<ConfirmPaymentScaffold> createState() => _ConfirmPaymentScaffoldState();
}

class _ConfirmPaymentScaffoldState extends State<ConfirmPaymentScaffold> {
  bool _isProcessing = false;
  bool _showPinField = false;
  String _enteredPin = '';
  bool _pinError = false;

  Future<void> _handleConfirm() async {
    if (widget.requirePin && !_showPinField) {
      setState(() => _showPinField = true);
      return;
    }

    if (widget.requirePin && _enteredPin.isEmpty) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Verify PIN
      if (widget.requirePin) {
        bool verified = await _verifyPin(_enteredPin);
        if (!verified) {
          setState(() => _pinError = true);
          await Future.delayed(Duration(seconds: 2));
          setState(() => _pinError = false);
          return;
        }
        widget.onPinVerified?.call(_enteredPin);
      }

      // Process payment
      await Future.delayed(Duration(milliseconds: 500));
      widget.onConfirm();

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _verifyPin(String pin) async {
    // Simulate PIN verification - replace with actual API call
    await Future.delayed(Duration(milliseconds: 300));
    return pin == '123456'; // Mock verification
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing payment...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Description
              if (widget.description != null) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    widget.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],

              // Transaction Details
              Text(
                'Transaction Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: widget.transactionDetails,
                ),
              ),
              SizedBox(height: 24),

              // Amount Breakdown
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.subtotal != null)
                        _buildAmountRow('Subtotal', widget.subtotal!),
                      if (widget.fee != null && widget.fee!.isNotEmpty)
                        _buildAmountRow('Admin Fee', widget.fee!),
                      if (widget.discount != null &&
                          widget.discount!.isNotEmpty)
                        _buildAmountRow(
                          'Discount',
                          widget.discount!,
                          textColor: Colors.green,
                        ),
                      if (widget.subtotal != null ||
                          (widget.fee != null && widget.fee!.isNotEmpty) ||
                          (widget.discount != null &&
                              widget.discount!.isNotEmpty))
                        Divider(thickness: 2),
                      _buildAmountRow(
                        'Total',
                        widget.totalAmount,
                        isHighlight: true,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Information
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info,
                      color: Colors.grey[700],
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This transaction will be processed immediately after confirmation.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // PIN Field (if required)
              if (widget.requirePin && _showPinField) ...[
                Text(
                  'Enter PIN to confirm',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 16),
                PinDotsField(
                  length: 6,
                  onCompleted: (pin) {
                    setState(() => _enteredPin = pin);
                  },
                  isError: _pinError,
                  dotSize: 20,
                  spacing: 20,
                ),
                SizedBox(height: 24),
              ],

              // Buttons
              _buildActionButtons(),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    String amount, {
    bool isHighlight = false,
    Color? textColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: textColor ??
                  (isHighlight ? Theme.of(context).primaryColor : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _handleConfirm,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).primaryColor,
          ),
          child: Text(
            widget.requirePin && _showPinField ? 'Verify & Pay' : 'Confirm Payment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 12),
        OutlinedButton(
          onPressed: widget.onCancel ?? () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(
              color: Theme.of(context).primaryColor,
            ),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Transaction detail row builder
class TransactionDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final IconData? icon;

  const TransactionDetailRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey),
            SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isHighlight ? 16 : 14,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 16 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight
                  ? Theme.of(context).primaryColor
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// Success result dialog
Future<void> showPaymentSuccessDialog(
  BuildContext context, {
  required String transactionId,
  required String amount,
  VoidCallback? onClose,
  VoidCallback? onShare,
  VoidCallback? onPrint,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.check_circle, color: Colors.green, size: 64),
      title: Text('Payment Successful'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction ID',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                transactionId,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Time',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                DateTime.now().toString().split('.')[0],
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (onShare != null)
          TextButton.icon(
            onPressed: onShare,
            icon: Icon(Icons.share),
            label: Text('Share'),
          ),
        if (onPrint != null)
          TextButton.icon(
            onPressed: onPrint,
            icon: Icon(Icons.print),
            label: Text('Print'),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onClose?.call();
          },
          child: Text('Done'),
        ),
      ],
    ),
  );
}

/// Failure result dialog
Future<void> showPaymentFailureDialog(
  BuildContext context, {
  required String errorMessage,
  VoidCallback? onRetry,
  VoidCallback? onClose,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.error, color: Colors.red, size: 64),
      title: Text('Payment Failed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 16),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onClose?.call();
          },
          child: Text('Close'),
        ),
        if (onRetry != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            child: Text('Retry'),
          ),
      ],
    ),
  );
}
