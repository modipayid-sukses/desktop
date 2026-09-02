// Desktop "Transaksi Berhasil" popup: shown right after a PPOB payment
// completes on wide/desktop layouts, replacing the mobile full-page
// TransactionDetail/TransactionReceipt navigation. Matches the desktop
// "Vivid Enterprise" visual language (desktop* tokens), same family as
// TransactionPinAuthDialog.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/color.dart';

class TransactionSuccessDialog extends StatefulWidget {
  /// e.g. "Pulsa berhasil dikirim", "Tagihan BPJS berhasil dibayar".
  final String subtitle;
  final String orderId;
  final DateTime transactionTime;
  /// Baris rincian struk (label, value), urutan sesuai kategori transaksi.
  final List<MapEntry<String, String>> rows;
  final String totalLabel;
  /// Override penutupan dialog (tombol X dan "Tutup"). Default: cukup pop
  /// dialog ini sendiri. Isi custom kalau dialog dipanggil dari halaman PIN
  /// terpisah (bukan popup) yang juga perlu ikut ditutup — lihat
  /// _PlnPostpaidInlinePinScreenState._submitPayment.
  final VoidCallback? onClose;

  const TransactionSuccessDialog({
    super.key,
    required this.subtitle,
    required this.orderId,
    required this.transactionTime,
    required this.rows,
    required this.totalLabel,
    this.onClose,
  });

  static Future<void> show({
    required BuildContext context,
    required String subtitle,
    required String orderId,
    DateTime? transactionTime,
    required List<MapEntry<String, String>> rows,
    required String totalLabel,
    VoidCallback? onClose,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => TransactionSuccessDialog(
        subtitle: subtitle,
        orderId: orderId,
        transactionTime: transactionTime ?? DateTime.now(),
        rows: rows,
        totalLabel: totalLabel,
        onClose: onClose,
      ),
    );
  }

  @override
  State<TransactionSuccessDialog> createState() => _TransactionSuccessDialogState();
}

class _TransactionSuccessDialogState extends State<TransactionSuccessDialog> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareReceipt() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/struk_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Struk transaksi');
    } catch (_) {
      // Silent — berbagi struk bukan bagian kritikal dari alur transaksi.
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.hankenGrotesk(fontSize: 12.5, color: desktopTextSecondary)),
          const SizedBox(width: 12),
          // `Spacer()` + `Flexible()` both default to flex:1, so they'd split
          // the remaining width 50/50 — but `Flexible` is loose-fit and only
          // claims as much of its half as the text needs, leaving values of
          // different lengths landing at different x-positions instead of a
          // shared right edge. `Expanded` + `Align` claims the full
          // remaining width and pins the text to its right edge instead.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: GoogleFonts.hankenGrotesk(fontSize: 12.5, fontWeight: FontWeight.w700, color: desktopTextPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          onTap: widget.onClose ?? () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 20, color: desktopTextSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(String dateLabel) {
    return RepaintBoundary(
      key: _receiptKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: desktopBorder.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Text(
              'modipay',
              style: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: desktopAccentBlue),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: desktopSuccessBg, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 13, color: desktopSuccessFg),
                  const SizedBox(width: 4),
                  Text(
                    'TRANSAKSI BERHASIL',
                    style: GoogleFonts.hankenGrotesk(fontSize: 10.5, fontWeight: FontWeight.w800, color: desktopSuccessFg),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: desktopBorder.withValues(alpha: 0.5)),
            _row('No. Transaksi', widget.orderId),
            _row('Tanggal & Waktu', dateLabel),
            for (final r in widget.rows) _row(r.key, r.value),
            const SizedBox(height: 4),
            Divider(color: desktopBorder.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Total Pembayaran',
                  style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary),
                ),
                const Spacer(),
                Text(
                  widget.totalLabel,
                  style: GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w800, color: desktopAccentBlue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isSharing ? null : _shareReceipt,
              icon: _isSharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(desktopAccentBlue)),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 16, color: desktopAccentBlue),
              label: Text(
                'Bagikan Struk',
                style: GoogleFonts.hankenGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700, color: desktopAccentBlue),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: desktopBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: desktopPrimaryBtn,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Tutup',
                style: GoogleFonts.hankenGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID').format(widget.transactionTime)} WIB';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 440,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: desktopSurfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const SizedBox(height: 4),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: desktopSuccessBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.check_rounded, color: desktopSuccessFg, size: 34),
              ),
              const SizedBox(height: 14),
              Text(
                'Transaksi Berhasil',
                style: GoogleFonts.hankenGrotesk(fontSize: 19, fontWeight: FontWeight.w800, color: desktopTextPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary),
              ),
              const SizedBox(height: 20),
              _buildReceiptCard(dateLabel),
              const SizedBox(height: 20),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }
}
