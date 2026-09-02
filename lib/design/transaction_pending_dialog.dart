// Desktop "Transaksi Sedang Diproses" popup: ditampilkan sesaat setelah
// `POST /ppob/purchase` atau `/loketbayar/purchase` membalas dengan
// transaction.status == 'pending' (backend baru async — lihat
// ppob_pending_timeout_frontend_prompt.md di repo modiback). Widget ini
// hanya MEMBACA state dari `PendingPpobService` (yang benar-benar melakukan
// polling di background, lepas dari dialog ini terbuka atau tidak) supaya
// menutup dialog TIDAK menghentikan polling — sesuai kontrak di prompt.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/pending_ppob_service.dart';
import '../utils/color.dart';
import '../utils/toast.dart';

class TransactionPendingDialog extends StatefulWidget {
  final String orderId;
  final String description;
  final ValueChanged<Map<String, dynamic>> onCompleted;
  final ValueChanged<Map<String, dynamic>> onFailed;

  const TransactionPendingDialog({
    super.key,
    required this.orderId,
    required this.description,
    required this.onCompleted,
    required this.onFailed,
  });

  /// [orderId] HARUS sudah didaftarkan ke `PendingPpobService.track(...)`
  /// oleh caller SEBELUM dialog ini ditampilkan.
  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required String description,
    required ValueChanged<Map<String, dynamic>> onCompleted,
    required ValueChanged<Map<String, dynamic>> onFailed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => TransactionPendingDialog(
        orderId: orderId,
        description: description,
        onCompleted: onCompleted,
        onFailed: onFailed,
      ),
    );
  }

  @override
  State<TransactionPendingDialog> createState() => _TransactionPendingDialogState();
}

class _TransactionPendingDialogState extends State<TransactionPendingDialog> {
  bool _handledFinal = false;

  void _handleFinal(BuildContext context, PendingPpobEntry entry) {
    if (_handledFinal) return;
    _handledFinal = true;
    final tx = entry.transaction;
    final isCompleted = entry.status == PendingPpobStatus.completed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (isCompleted) {
        widget.onCompleted(tx);
      } else {
        widget.onFailed(tx);
      }
    });
  }

  Future<void> _copyOrderId(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.orderId));
    if (context.mounted) showToast(msg: 'ID transaksi disalin');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PendingPpobService>(
      builder: (context, service, _) {
        final entry = service.entryFor(widget.orderId);
        final status = entry?.status ?? PendingPpobStatus.pending;

        if (entry != null &&
            (status == PendingPpobStatus.completed || status == PendingPpobStatus.failed)) {
          _handleFinal(context, entry);
        }

        final isContactCs = status == PendingPpobStatus.contactCs;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
            decoration: BoxDecoration(
              color: desktopSurfaceCard,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 20, color: desktopTextSecondary),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isContactCs
                        ? desktopWarningAmber.withValues(alpha: 0.12)
                        : desktopPrimaryBtn.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isContactCs
                      ? const Icon(Icons.access_time_rounded, color: desktopWarningAmber, size: 32)
                      : const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(desktopPrimaryBtn),
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  isContactCs ? 'Diproses Lebih Lama dari Biasanya' : 'Transaksi Sedang Diproses',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: desktopTextPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  isContactCs
                      ? 'Saldo Anda TIDAK hilang. Jika belum selesai dalam beberapa saat, silakan hubungi CS dengan menyebutkan ID transaksi di bawah.'
                      : '${widget.description}\nBiasanya selesai dalam beberapa detik.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(fontSize: 13, color: desktopTextSecondary, height: 1.4),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: desktopPrimaryBtn.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: desktopBorder.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ID Transaksi',
                              style: GoogleFonts.hankenGrotesk(fontSize: 11, color: desktopTextSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.orderId,
                              style: GoogleFonts.hankenGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: desktopTextPrimary),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _copyOrderId(context),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.copy_rounded, size: 18, color: desktopAccentBlue),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Transaksi tetap diproses walau jendela ini ditutup — hasil akhirnya bisa dicek di Riwayat Transaksi.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(fontSize: 11.5, color: desktopTextSecondary, height: 1.4),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: desktopBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Tutup, Lanjutkan di Latar Belakang',
                      style: GoogleFonts.hankenGrotesk(fontSize: 13.5, fontWeight: FontWeight.w700, color: desktopTextPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
