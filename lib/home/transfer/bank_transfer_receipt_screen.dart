import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../bottombar/bottombar.dart';

class BankTransferReceiptScreen extends StatefulWidget {
  final double amount;
  final double admin;
  final double total;
  final String receiverName;
  final String accountNumber;
  final String bankName;
  final DateTime transactionTime;
  final String referenceNumber;
  final String status;

  const BankTransferReceiptScreen({
    Key? key,
    required this.amount,
    this.admin = 0,
    double? total,
    required this.receiverName,
    required this.accountNumber,
    required this.bankName,
    required this.transactionTime,
    required this.referenceNumber,
    required this.status,
  })  : total = total ?? (amount + admin),
        super(key: key);

  @override
  State<BankTransferReceiptScreen> createState() =>
      _BankTransferReceiptScreenState();
}

class _BankTransferReceiptScreenState extends State<BankTransferReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSaving = false;

  bool get _isSuccess =>
      widget.status.toLowerCase().contains('success') ||
      widget.status.toLowerCase().contains('berhasil') ||
      widget.status.toLowerCase().contains('completed');

  String get _statusLabel => _isSuccess ? 'Sukses' : 'Gagal';

  Color get _statusColor =>
      _isSuccess ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);

  Color get _statusBgColor =>
      _isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    if (Platform.isAndroid) {
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isGranted || photoStatus.isLimited) return true;
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  Future<Uint8List?> _captureReceiptBytes() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadReceipt() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final granted = await _requestGalleryPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin penyimpanan ditolak')),
        );
        return;
      }

      final bytes = await _captureReceiptBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan struk')),
        );
        return;
      }

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        name:
            'STRUK_${widget.referenceNumber}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil disimpan ke galeri')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan struk')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan struk')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureReceiptBytes();
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membagikan struk')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Struk Transfer Bank',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membagikan struk')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'id_ID');
    final headerDateFormat = DateFormat('d MMM yyyy • HH:mm', 'id_ID');
    final detailDateFormat = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID');
    final now = widget.transactionTime;

    const pageBg = Color(0xFFF5F5F7);
    final amountText = 'Rp ${currencyFormat.format(widget.amount.toInt())}';
    final adminText = widget.admin > 0
        ? 'Rp ${currencyFormat.format(widget.admin.toInt())}'
        : 'Gratis!';
    final totalText = 'Rp ${currencyFormat.format(widget.total.toInt())}';

    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: pageBg),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 14, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const Bottombar()),
                          (route) => false,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF1A1A1A),
                          size: 26,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Detail Transaksi',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Gilroy Bold',
                            fontSize: 17,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                    ],
                  ),
                ),

                // ── Content ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    child: Column(
                      children: [
                        // ── Receipt card ──
                        RepaintBoundary(
                          key: _receiptKey,
                          child: Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Date & ID row ──
                                Row(
                                  children: [
                                    Flexible(
                                      flex: 7,
                                      child: Text(
                                        headerDateFormat.format(now),
                                        style: const TextStyle(
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 13,
                                          color: Color(0xFF3A3A3A),
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      flex: 9,
                                      child: Text(
                                        'Id transaksi : ${widget.referenceNumber}',
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 12,
                                          color: Color(0xFF3A3A3A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Divider(
                                    color: Color(0xFFE6E9EE), height: 1),
                                const SizedBox(height: 10),

                                // ── Status row ──
                                Row(
                                  children: [
                                    Icon(
                                      _isSuccess
                                          ? Icons
                                              .check_circle_outline_rounded
                                          : Icons.error_outline_rounded,
                                      size: 16,
                                      color: _statusColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isSuccess
                                          ? 'Transaksi Berhasil'
                                          : 'Transaksi Gagal',
                                      style: TextStyle(
                                        fontFamily: 'Gilroy Medium',
                                        fontSize: 13,
                                        color: _statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // ── Title ──
                                Text(
                                  'Transfer ke ${widget.bankName}',
                                  style: const TextStyle(
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 20,
                                    color: Color(0xFF161616),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // ── Tags ──
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F3F3),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'BANK_TRANSFER',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 12,
                                          color: Color(0xFF515151),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusBgColor,
                                        borderRadius:
                                            BorderRadius.circular(30),
                                        border: Border.all(
                                          color: _statusColor
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                      child: Text(
                                        _statusLabel,
                                        style: TextStyle(
                                          fontFamily: 'Gilroy Medium',
                                          fontSize: 12,
                                          color: _statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // ── Detail Transaksi ──
                                const Text(
                                  'Detail Transaksi',
                                  style: TextStyle(
                                    fontFamily: 'Gilroy Bold',
                                    fontSize: 17,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                _buildDetailRow(
                                  'Id transaksi',
                                  widget.referenceNumber,
                                  canCopy: true,
                                  onCopy: () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                          text: widget.referenceNumber),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('ID transaksi disalin'),
                                      ),
                                    );
                                  },
                                ),
                                _buildDetailRow(
                                  'Nama Penerima',
                                  widget.receiverName,
                                ),
                                _buildDetailRow(
                                  'Nomor Rekening',
                                  widget.accountNumber,
                                ),
                                _buildDetailRow(
                                  'Bank Tujuan',
                                  widget.bankName,
                                ),
                                _buildDetailRow(
                                  'Tipe Transfer',
                                  'BI FAST',
                                ),
                                _buildDetailRow('Harga', amountText),
                                _buildDetailRow('Biaya Admin', adminText),
                                const Divider(
                                  height: 12,
                                  thickness: 1,
                                  color: Color(0xFFE5E9EE),
                                ),
                                _buildDetailRow('Total', totalText,
                                    large: true),
                                _buildDetailRow(
                                  'Waktu',
                                  detailDateFormat.format(now),
                                ),
                                _buildDetailRow(
                                  'No. Referensi',
                                  widget.referenceNumber,
                                ),
                                _buildDetailRow(
                                  'Status',
                                  _statusLabel,
                                  valueColor: _statusColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Action buttons ──
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 54,
                                child: OutlinedButton(
                                  onPressed:
                                      _isSaving ? null : _shareReceipt,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF3C74BB),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'PRINT',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: 16,
                                      color: Color(0xFF3C74BB),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 54,
                                child: OutlinedButton(
                                  onPressed:
                                      _isSaving ? null : _downloadReceipt,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFF3C74BB),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'DOWNLOAD',
                                    style: TextStyle(
                                      fontFamily: 'Gilroy Bold',
                                      fontSize: 16,
                                      color: Color(0xFF3C74BB),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── Back to home ──
                        GestureDetector(
                          onTap: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const Bottombar()),
                            (route) => false,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              'Kembali ke Beranda',
                              style: TextStyle(
                                fontFamily: 'Gilroy Bold',
                                fontSize: 16,
                                color: Color(0xFF3C86D6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool large = false,
    bool canCopy = false,
    VoidCallback? onCopy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Gilroy Medium',
                fontSize: large ? 16 : 13,
                color: const Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Gilroy Bold',
                      fontSize: large ? 17 : 13,
                      color: valueColor ?? const Color(0xFF333333),
                    ),
                  ),
                ),
                if (canCopy) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onCopy,
                    child: const Icon(
                      Icons.copy_rounded,
                      size: 15,
                      color: Color(0xFF3C86D6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
