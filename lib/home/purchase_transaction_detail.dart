import 'dart:typed_data';
import 'package:modipay/widgets/desktop_title_wrapper.dart';

import 'dart:ui' as ui;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:modipay/services/receipt_settings_service.dart';
import 'package:modipay/widgets/purchase_receipt.dart';
import 'package:modipay/widgets/pln_prepaid_receipt.dart';
import 'package:modipay/utils/media.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Transaction detail screen for PURCHASE category (PPOB products)
class PurchaseTransactionDetail extends StatefulWidget {
  final Map<String, dynamic> data;

  const PurchaseTransactionDetail({Key? key, required this.data})
      : super(key: key);

  @override
  State<PurchaseTransactionDetail> createState() =>
      _PurchaseTransactionDetailState();
}

class _PurchaseTransactionDetailState extends State<PurchaseTransactionDetail> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _printing = false;
  Map<String, String> _receiptSettings = const {};

  @override
  void initState() {
    super.initState();
    _loadReceiptSettings();
  }

  Future<void> _loadReceiptSettings() async {
    final settings = await ReceiptSettingsService.load();
    if (!mounted) return;
    setState(() => _receiptSettings = settings);
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    String raw = value.toString().trim();
    if (raw.isEmpty) return DateTime.now();
    if (!raw.endsWith('Z') &&
        !raw.contains(RegExp(r'[+-]\d{2}:?\d{2}$')) &&
        !raw.contains(RegExp(r'[+-]\d{4}$'))) {
      if (!raw.contains('T')) {
        raw = raw.replaceAll(' ', 'T');
      }
      raw = '${raw}Z';
    }
    return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
  }

  bool _isPlnTokenData(Map<String, dynamic> data) {
    final category = (data['category'] ?? '').toString().toLowerCase();
    final name = (data['name'] ?? data['product_name'] ?? '').toString().toLowerCase();
    final note = (data['note'] ?? '').toString();
    if (note.contains('"token"')) return true;
    final isToken = category.contains('token') || name.contains('token');
    final isPln = category.contains('pln') || name.contains('pln') || name.contains('listrik');
    return isToken && isPln;
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  String _extractUsername(String sn) {
    if (!sn.contains('Username')) return '';
    final regex = RegExp(r'Username\s+([^/]+)');
    final match = regex.firstMatch(sn);
    return match?.group(1)?.trim() ?? '';
  }

  String _extractRegion(String sn) {
    if (!sn.contains('Region')) return '';
    final regex = RegExp(r'Region\s*=\s*([^\s/]+)');
    final match = regex.firstMatch(sn);
    return match?.group(1)?.trim() ?? '';
  }

  Future<Uint8List?> _captureReceiptBytesWithRetry() async {
    for (var i = 0; i < 3; i++) {
      await WidgetsBinding.instance.endOfFrame;
      final bytes = await _captureReceiptBytes();
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }
    return null;
  }

  Future<Uint8List> _buildFallbackPdfBytes() async {
    final data = widget.data;
    final amount = _parseAmount(data['amount']);
    final customerNo =
        data['customer_no']?.toString() ?? data['phone_number']?.toString() ?? '-';
    final orderId = data['order_id']?.toString() ?? data['id']?.toString() ?? '-';
    final productName =
        data['name']?.toString() ?? data['product_name']?.toString() ?? '-';
    final createdAt = data['created_at'] != null
        ? _parseDateTime(data['created_at'])
        : DateTime.now();

    final currency =
        NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Container(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Detail Transaksi',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Produk: $productName'),
              pw.SizedBox(height: 6),
              pw.Text('No. Pelanggan: $customerNo'),
              pw.SizedBox(height: 6),
              pw.Text('No. Referensi: $orderId'),
              pw.SizedBox(height: 6),
              pw.Text('Waktu: ${dateFmt.format(createdAt)}'),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Text(
                'Total: ${currency.format(amount)}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
    return doc.save();
  }

  Future<Uint8List?> _captureReceiptBytes() async {
    try {
      final boundary =
          _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _printReceipt() async {
    if (_printing) return;

    if (Platform.isIOS) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Print di iOS sementara tidak tersedia')),
      );
      return;
    }

    setState(() => _printing = true);
    try {
      final bytes = await _captureReceiptBytesWithRetry();

      await Printing.layoutPdf(
        onLayout: (format) async {
          if (bytes == null) {
            return _buildFallbackPdfBytes();
          }

          final image = pw.MemoryImage(bytes);
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: format,
              build: (_) => pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          );
          return doc.save();
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka dialog cetak')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final amount = _parseAmount(data['amount']);
    final orderId = data['order_id']?.toString() ?? data['id']?.toString() ?? '';
    final productname =
        data['name']?.toString() ?? data['product_name']?.toString() ?? '';
    final createdAt = data['created_at'] != null
        ? _parseDateTime(data['created_at'])
        : DateTime.now();
    final storeName = (_receiptSettings['storeName'] ?? '').trim();
    final storePhone = (_receiptSettings['phone'] ?? '').trim();
    final address = ReceiptSettingsService.composeAddress(_receiptSettings);
    final thanks = (_receiptSettings['thanksMessage'] ?? '').trim();

    // Extract game/PPOB specific fields from sn
    final sn = data['sn']?.toString() ?? '';
    final username = _extractUsername(sn);
    final region = _extractRegion(sn);
    final nominal = _parseAmount(data['price'] ?? data['nominal'] ?? amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: DesktopLeadingWrapper(child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF212121), size: 20),
        )),
        title: DesktopTitleWrapper(child: Text(
          'Detail Transaksi',
          style: TextStyle(
            color: const Color(0xFF212121),
            fontFamily: 'Gilroy Bold',
            fontSize: height / 45,
          ),
        )),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _printing ? null : _printReceipt,
            icon: _printing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF212121)))
                : const Icon(Icons.print_rounded,
                    color: Color(0xFF212121), size: 20),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: width / 15, vertical: 20),
        child: Column(
          children: [
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: _isPlnTokenData(data)
                    ? PlnPrepaidReceipt(
                        data: data,
                        receiptSettings: _receiptSettings,
                      )
                    : PurchaseReceipt(
                        merchantName: storeName.isEmpty ? productname : storeName,
                        merchantPhone: storePhone.isEmpty ? null : storePhone,
                        merchantAddress: address.isEmpty ? null : address,
                        referenceNo: orderId,
                        transactionTime: createdAt,
                        items: [
                          {
                            'name': productname,
                            'quantity': 1,
                            'price': amount,
                          }
                        ],
                        totalQuantity: 1,
                        totalPrice: amount,
                        amountPaid: amount,
                        change: 0,
                        category: data['category']?.toString() ?? '',
                        paymentMethod: 'Cash',
                        thankYouMessage: thanks.isEmpty ? null : thanks,
                        customerName: username.isEmpty ? null : username,
                        region: region.isEmpty ? null : region,
                        nominal: nominal > 0 ? nominal : null,
                        serialNumber: (data['provider_ref'] ?? '').toString().isEmpty
                            ? null
                            : data['provider_ref'].toString(),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Print button
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _printing ? null : _printReceipt,
                      icon: _printing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
